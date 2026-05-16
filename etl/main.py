"""
main.py — Orquestador del Pipeline BI de TyG
=============================================
Flujo:
  1. Ejecuta ingest.py  → CDC incremental MySQL → PostgreSQL (raw)
  2. Ejecuta dbt run    → Transforma raw en marts (dimensiones + hechos)
  3. Ejecuta dbt test   → Valida integridad del DataMart
  4. Espera N segundos y repite el ciclo

Configuración:
  ETL_INTERVAL_SECONDS  → intervalo entre ciclos (default 300 = 5 min)
"""

import os
import sys
import time
import logging
import subprocess
from datetime import datetime

# ─────────────────────────────────────────────────────────────
# Logging
# ─────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
log = logging.getLogger("tyg.main")

INTERVAL = int(os.getenv("ETL_INTERVAL_SECONDS", "300"))
DBT_PROJECT_DIR = "/app/dbt_tyg"


def run_step(label: str, cmd: list, cwd: str = None) -> bool:
    log.info(f"▶ {label}")
    result = subprocess.run(cmd, capture_output=True, text=True, cwd=cwd)
    
    # Mostrar TODA la salida, no solo las últimas 10 líneas
    if result.stdout.strip():
        for line in result.stdout.strip().splitlines():
            log.info(f"   {line}")
    
    if result.returncode == 0:
        log.info(f"✓ {label} — OK")
    else:
        log.error(f"✗ {label} — FALLÓ (código {result.returncode})")
        if result.stderr.strip():
            for line in result.stderr.strip().splitlines()[-30:]:
                log.error(f"   {line}")
    
    return result.returncode == 0


def run_pipeline():
    """Ejecuta un ciclo completo del pipeline: Ingest → DBT Run → DBT Test."""
    start = datetime.now()
    log.info("=" * 60)
    log.info(f"PIPELINE INICIO: {start.strftime('%Y-%m-%d %H:%M:%S')}")
    log.info("=" * 60)

    # Paso 1: CDC — extracción incremental MySQL → PostgreSQL raw
    ok_ingest = run_step(
        "PASO 1/3 — CDC Incremental (MySQL → PG raw)",
        ["python", "/app/etl/ingest.py"]
    )

    if not ok_ingest:
        log.error("Pipeline abortado: falló la ingesta CDC.")
        return False

    # Paso 2: DBT run — transforma raw en dimensiones y hechos
    ok_dbt = run_step(
        "PASO 2/3 — DBT Run (raw → marts)",
        ["dbt", "run", "--profiles-dir", "/app/dbt_tyg", "--project-dir", DBT_PROJECT_DIR],
        cwd=DBT_PROJECT_DIR
    )

    if not ok_dbt:
        log.error("Pipeline abortado: falló dbt run.")
        return False

    # Paso 3: DBT test — valida integridad de datos
    run_step(
        "PASO 3/3 — DBT Test (validación de calidad)",
        ["dbt", "test", "--profiles-dir", "/app/dbt_tyg", "--project-dir", DBT_PROJECT_DIR],
        cwd=DBT_PROJECT_DIR
    )
    # Los tests no abortan el pipeline (son informativos en este contexto)

    elapsed = (datetime.now() - start).total_seconds()
    log.info(f"PIPELINE COMPLETADO en {elapsed:.1f}s")
    return True


def wait_for_databases():
    """Espera hasta que ambas BD estén accesibles antes de iniciar el ciclo."""
    import sqlalchemy
    from etl.ingest import MYSQL_URL, PG_URL

    log.info("Esperando disponibilidad de bases de datos...")
    for url, name in [(MYSQL_URL, "MySQL"), (PG_URL, "PostgreSQL")]:
        while True:
            try:
                engine = sqlalchemy.create_engine(url, pool_pre_ping=True)
                with engine.connect():
                    pass
                log.info(f"✓ {name} disponible")
                break
            except Exception as e:
                log.warning(f"⏳ {name} no disponible aún: {e}. Reintentando en 5s...")
                time.sleep(5)


if __name__ == "__main__":
    # Esperar a que las BDs estén listas (healthchecks de Docker pueden no ser suficientes)
    time.sleep(15)  # Buffer inicial para que MySQL inicialice datos

    cycle = 1
    while True:
        log.info(f"\n{'='*60}\n  CICLO #{cycle}\n{'='*60}")
        try:
            run_pipeline()
        except Exception as e:
            log.error(f"Error inesperado en ciclo #{cycle}: {e}")

        log.info(f"⏱  Próximo ciclo en {INTERVAL}s...")
        time.sleep(INTERVAL)
        cycle += 1
