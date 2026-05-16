"""
ingest.py — Motor CDC Manual (Change Data Capture por Timestamps)
Arquitectura: MySQL (OLTP) → PostgreSQL (DW / Raw Layer)

Flujo por tabla:
1. Crear esquemas y tablas automáticamente en PostgreSQL (basándose en MySQL)
2. Leer last_sync_at desde meta.etl_sync_log en PostgreSQL
3. Extraer filas de MySQL donde updated_at > last_sync_at
4. Hacer UPSERT en raw.<tabla> de PostgreSQL (INSERT ON CONFLICT DO UPDATE)
5. Actualizar meta.etl_sync_log con la nueva fecha y conteo de filas
"""
import os
import sys
import logging
from datetime import datetime, timezone
from typing import Optional

import pandas as pd
from sqlalchemy import create_engine, text, inspect

# ─────────────────────────────────────────────────────────────
# Logging
# ─────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
log = logging.getLogger("tyg.ingest")

# ─────────────────────────────────────────────────────────────
# Configuración desde variables de entorno (Docker Compose)
# ─────────────────────────────────────────────────────────────
MYSQL_URL = (
    f"mysql+pymysql://{os.getenv('MYSQL_USER','root')}:"
    f"{os.getenv('MYSQL_PASSWORD','root')}@"
    f"{os.getenv('MYSQL_HOST','localhost')}:"
    f"{os.getenv('MYSQL_PORT','23306')}/"
    f"{os.getenv('MYSQL_DB','bd_transaccional')}"
)

PG_URL = (
    f"postgresql+psycopg2://{os.getenv('PG_USER','postgres')}:"
    f"{os.getenv('PG_PASSWORD','root')}@"
    f"{os.getenv('PG_HOST','localhost')}:"
    f"{os.getenv('PG_PORT','5432')}/"
    f"{os.getenv('PG_DB','tyg_datamart')}"
)

# ─────────────────────────────────────────────────────────────
# Mapa de tablas: { mysql_table: (pg_raw_table, pk_column) }
# ─────────────────────────────────────────────────────────────
TABLES_CDC = {
    "ventas":       ("raw.ventas",        "venta_id"),
    "recepciones":  ("raw.recepciones",   "recepcion_id"),
    "activaciones": ("raw.activaciones",  "activacion_id"),
    "oficinas":     ("raw.oficinas",      "oficina_id"),
    "vendedores":   ("raw.vendedores",    "vendedor_id"),
    "asesores":     ("raw.asesores",      "asesor_pdv_id"),
    "metas":        ("raw.metas",         "meta_id"),
}

# Mapeo de columnas booleanas (MySQL TINYINT(1) → PostgreSQL BOOLEAN)
BOOLEAN_COLUMNS = {
    "recepciones":  ["ingresado_sin_venta"],
    "activaciones": ["flag_activo"],
    "oficinas":     ["activo"],
    "vendedores":   ["activo"],
    "asesores":     ["activo"],
}


def get_engines():
    """Crea y retorna los engines de SQLAlchemy para MySQL y PostgreSQL."""
    src = create_engine(MYSQL_URL, pool_pre_ping=True)
    dst = create_engine(PG_URL, pool_pre_ping=True)
    return src, dst


def mysql_to_postgres_type(mysql_type: str) -> str:
    """
    Convierte tipos de MySQL a PostgreSQL, eliminando collations y ajustando tipos.
    """
    mysql_type_upper = mysql_type.upper()
    
    # Eliminar collations (ej: VARCHAR(255) COLLATE utf8mb4_unicode_ci → VARCHAR(255))
    if 'COLLATE' in mysql_type_upper:
        mysql_type = mysql_type.split(' COLLATE')[0].split(' collate')[0]
    
    # Mapeo de tipos
    if 'TINYINT(1)' in mysql_type_upper:
        return "BOOLEAN"
    elif 'BIGINT' in mysql_type_upper:
        return "BIGINT"
    elif 'INT' in mysql_type_upper or 'INTEGER' in mysql_type_upper:
        return "INTEGER"
    elif 'DECIMAL' in mysql_type_upper or 'NUMERIC' in mysql_type_upper:
        return mysql_type.replace('DECIMAL', 'NUMERIC')
    elif 'VARCHAR' in mysql_type_upper or 'CHAR' in mysql_type_upper:
        return mysql_type
    elif 'DATETIME' in mysql_type_upper or 'TIMESTAMP' in mysql_type_upper:
        return "TIMESTAMP"
    elif 'DATE' in mysql_type_upper:
        return "DATE"
    elif 'TEXT' in mysql_type_upper or 'LONGTEXT' in mysql_type_upper:
        return "TEXT"
    else:
        return "TEXT"


def create_schemas_and_tables(src_engine, dst_engine):
    """
    Crea esquemas y tablas automáticamente en PostgreSQL basándose en MySQL.
    """
    log.info("=" * 60)
    log.info("Creando esquemas y tablas en PostgreSQL...")
    log.info("=" * 60)
    
    # Crear esquemas
    with dst_engine.begin() as conn:
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS raw"))
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS meta"))
        log.info("  ✓ Esquemas 'raw' y 'meta' creados/verificados")
    
    # Crear tabla de logs de sincronización
    with dst_engine.begin() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS meta.etl_sync_log (
                sync_id SERIAL PRIMARY KEY,
                tabla_origen VARCHAR(100) NOT NULL,
                last_sync_at TIMESTAMPTZ NOT NULL DEFAULT '2000-01-01 00:00:00+00',
                rows_extracted INT DEFAULT 0,
                rows_loaded INT DEFAULT 0,
                status VARCHAR(20) DEFAULT 'PENDING',
                error_msg TEXT,
                executed_at TIMESTAMPTZ DEFAULT NOW()
            )
        """))
        log.info("  ✓ Tabla meta.etl_sync_log creada/verificada")
    
    # Inspeccionar MySQL
    inspector = inspect(src_engine)
    
    # Crear cada tabla en PostgreSQL
    for mysql_table in TABLES_CDC.keys():
        log.info(f"  Procesando tabla: {mysql_table}")
        
        columns = inspector.get_columns(mysql_table)
        pk = inspector.get_pk_constraint(mysql_table)
        
        col_defs = []
        for col in columns:
            col_name = col['name']
            mysql_type = str(col['type'])
            pg_type = mysql_to_postgres_type(mysql_type)
            col_defs.append(f'"{col_name}" {pg_type}')
        
        # Agregar columna de control CDC
        col_defs.append('"_cdc_loaded_at" TIMESTAMPTZ DEFAULT NOW()')
        
        # Definir clave primaria
        if pk and 'constrained_columns' in pk and pk['constrained_columns']:
            pk_cols = ', '.join([f'"{c}"' for c in pk['constrained_columns']])
            pk_def = f"PRIMARY KEY ({pk_cols})"
            col_defs.append(pk_def)
        
        # Crear tabla en PostgreSQL
        create_sql = f"""
            CREATE TABLE IF NOT EXISTS raw.{mysql_table} (
                {', '.join(col_defs)}
            )
        """
        
        with dst_engine.begin() as conn:
            conn.execute(text(create_sql))
            log.info(f"  ✓ Tabla raw.{mysql_table} creada/verificada")
    
    log.info("=" * 60)
    log.info("Todas las estructuras de PostgreSQL están listas")
    log.info("=" * 60)


def get_last_sync(dst_engine, tabla: str) -> datetime:
    """Lee la última fecha de sincronización exitosa desde meta.etl_sync_log."""
    query = text("""
        SELECT last_sync_at FROM meta.etl_sync_log 
        WHERE tabla_origen = :tabla 
          AND status = 'SUCCESS'
          AND last_sync_at IS NOT NULL
        ORDER BY sync_id DESC LIMIT 1
    """)
    
    with dst_engine.connect() as conn:
        result = conn.execute(query, {"tabla": tabla}).fetchone()
        if result:
            ts = result[0]
            if ts.tzinfo is None:
                ts = ts.replace(tzinfo=timezone.utc)
            return ts
    
    # Primera vez: cargar todo desde 2000
    return datetime(2000, 1, 1, tzinfo=timezone.utc)


def update_sync_log(
    dst_engine,
    tabla: str,
    rows_extracted: int,
    rows_loaded: int,
    new_sync_at: datetime,
    status: str = "SUCCESS",
    error_msg: Optional[str] = None,
):
    """Actualiza el registro de sincronización en meta.etl_sync_log."""
    upsert = text("""
        INSERT INTO meta.etl_sync_log
        (tabla_origen, last_sync_at, rows_extracted, rows_loaded, status, error_msg, executed_at)
        VALUES
        (:tabla, :last_sync_at, :rows_extracted, :rows_loaded, :status, :error_msg, NOW())
    """)
    
    with dst_engine.begin() as conn:
        conn.execute(upsert, {
            "tabla": tabla,
            "last_sync_at": new_sync_at,
            "rows_extracted": rows_extracted,
            "rows_loaded": rows_loaded,
            "status": status,
            "error_msg": error_msg,
        })


def extract_incremental(src_engine, tabla: str, last_sync: datetime) -> pd.DataFrame:
    """Extrae filas de MySQL donde updated_at > last_sync."""
    ts_str = last_sync.strftime("%Y-%m-%d %H:%M:%S")
    query = f"SELECT * FROM `{tabla}` WHERE updated_at > '{ts_str}'"
    log.info(f"  → Extrayendo {tabla} con updated_at > {ts_str}")
    df = pd.read_sql(query, src_engine)
    log.info(f"  → {len(df)} filas extraídas de {tabla}")
    return df


def upsert_to_postgres(dst_engine, df: pd.DataFrame, pg_table: str, pk_col: str):
    """
    Carga datos en PostgreSQL usando UPSERT (INSERT ON CONFLICT DO UPDATE).
    """
    if df.empty:
        log.info(f"  → Sin cambios para {pg_table}, omitiendo carga.")
        return 0
    
    schema, table_name = pg_table.split(".")
    tmp_table = f"_tmp_{table_name}"
    
    # Agregar columna de control CDC
    df["_cdc_loaded_at"] = datetime.now(tz=timezone.utc)
    
    # Convertir columnas booleanas si es necesario
    if table_name in BOOLEAN_COLUMNS:
        for col in BOOLEAN_COLUMNS[table_name]:
            if col in df.columns:
                df[col] = df[col].apply(lambda x: bool(x) if pd.notna(x) else None)
    
    # Cargar en tabla temporal
    df.to_sql(
        tmp_table,
        dst_engine,
        schema=schema,
        if_exists="replace",
        index=False,
        method="multi",
        chunksize=500,
    )
    
    # Construir UPSERT
    cols = [c for c in df.columns if c != pk_col]
    update_set = ", ".join([f'"{c}" = EXCLUDED."{c}"' for c in cols])
    all_cols = ", ".join([f'"{c}"' for c in df.columns])
    
    upsert_sql = text(f"""
        INSERT INTO {pg_table} ({all_cols})
        SELECT {all_cols} FROM {schema}."{tmp_table}"
        ON CONFLICT ({pk_col}) DO UPDATE SET {update_set}
    """)
    
    with dst_engine.begin() as conn:
        conn.execute(upsert_sql)
        conn.execute(text(f'DROP TABLE IF EXISTS {schema}."{tmp_table}"'))
    
    log.info(f"  → {len(df)} filas cargadas/actualizadas en {pg_table}")
    return len(df)


def sync_table(src_engine, dst_engine, mysql_table: str, pg_table: str, pk_col: str):
    """Sincroniza una tabla completa: extrae de MySQL y carga en PostgreSQL."""
    log.info(f"[SYNC] Procesando tabla: {mysql_table}")
    
    try:
        last_sync = get_last_sync(dst_engine, mysql_table)
        df = extract_incremental(src_engine, mysql_table, last_sync)
        rows_loaded = upsert_to_postgres(dst_engine, df, pg_table, pk_col)
        
        # Actualizar log de sincronización
        if not df.empty and "updated_at" in df.columns:
            new_sync_at = pd.to_datetime(df["updated_at"]).max().to_pydatetime()
            if new_sync_at.tzinfo is None:
                new_sync_at = new_sync_at.replace(tzinfo=timezone.utc)
        else:
            new_sync_at = datetime.now(tz=timezone.utc)
        
        update_sync_log(
            dst_engine,
            mysql_table,
            rows_extracted=len(df),
            rows_loaded=rows_loaded,
            new_sync_at=new_sync_at,
            status="SUCCESS",
        )
        
        log.info(f"[OK] {mysql_table} sincronizada exitosamente")
        
    except Exception as e:
        log.error(f"[ERROR] Falló sincronización de {mysql_table}: {e}")
        update_sync_log(
            dst_engine,
            mysql_table,
            rows_extracted=0,
            rows_loaded=0,
            new_sync_at=datetime.now(tz=timezone.utc),
            status="ERROR",
            error_msg=str(e),
        )
        raise


def run_cdc():
    """Ejecuta el ciclo completo de CDC para todas las tablas."""
    log.info("=" * 60)
    log.info("Iniciando CDC: MySQL → PostgreSQL")
    log.info("=" * 60)
    
    src_engine, dst_engine = get_engines()
    
    # Crear esquemas y tablas si no existen
    create_schemas_and_tables(src_engine, dst_engine)
    
    # Sincronizar cada tabla
    for mysql_table, (pg_table, pk_col) in TABLES_CDC.items():
        try:
            sync_table(src_engine, dst_engine, mysql_table, pg_table, pk_col)
        except Exception as e:
            log.error(f"Error crítico en {mysql_table}, continuando con siguiente tabla...")
            continue
    
    log.info("=" * 60)
    log.info("CDC completado")
    log.info("=" * 60)


if __name__ == "__main__":
    run_cdc()