# 🏗️ Proyecto TyG — Arquitectura BI v4
## MySQL (OLTP) → CDC Manual → PostgreSQL (DW) → DBT → Power BI

---

## Arquitectura

```
┌─────────────────┐    CDC Incremental    ┌──────────────────────┐
│  MySQL 8.4      │   (Python + updated_at)│  PostgreSQL 16       │
│  bd_transaccional│ ─────────────────────►│  tyg_datamart        │
│  Puerto: 23306  │                        │  Puerto: 5432        │
│                 │                        │                      │
│  Tablas OLTP:   │   Cada 5 minutos       │  Schemas:            │
│  • ventas       │   solo los cambios     │  raw.*   (staging)   │
│  • recepciones  │   (filas con           │  marts.* (DW final)  │
│  • activaciones │    updated_at nuevo)   │  meta.*  (control)   │
│  • oficinas     │                        │                      │
│  • vendedores   │                        │  DBT transforma:     │
│  • asesores     │                        │  raw → marts         │
│  • metas        │                        └──────────────────────┘
└─────────────────┘                                  │
                                                     ▼
                                           ┌──────────────────┐
                                           │   Power BI       │
                                           │  Modelo semántico│
                                           │  9 KPIs TyG      │
                                           └──────────────────┘
```

---

## Inicio rápido

### 1. Levantar toda la infraestructura

```bash
docker compose up -d --build
```

Esto arranca:
- **tyg-oltp-container** — MySQL con los datos transaccionales
- **tyg-bi-container** — PostgreSQL con schema automático
- **tyg-etl-container** — Orquestador (CDC + DBT cada 5 min)

### 2. Verificar que todo corre

```bash
docker compose logs -f tyg-etl-container
```

Deberías ver:
```
[INFO] TyG CDC — Iniciando ciclo de ingesta incremental
[INFO] [SYNC] Procesando tabla: ventas
[INFO]   → 150 filas extraídas de ventas
[INFO] PASO 2/3 — DBT Run (raw → marts)
[INFO] ✓ DBT Run — OK
```

### 3. Conectar Power BI

En Power BI Desktop → Obtener datos → PostgreSQL:
- **Servidor:** `localhost:5432`
- **Base de datos:** `tyg_datamart`
- **Usuario:** `postgres` / **Contraseña:** `root`
- **Schema a usar:** `marts`

Tablas disponibles:
| Tabla | Descripción |
|-------|-------------|
| `marts.hecho_ventas` | KPI P1: Tasa activación, ingresos, contribución |
| `marts.hecho_inventario` | KPI P2: Riesgo 90d, días inactivo, rotación |
| `marts.hecho_canal` | KPI P3a: Mix canal Directo vs PDV |
| `marts.hecho_desempeno` | KPI P3b: Cumplimiento meta, kits x asesor |
| `marts.dim_tiempo` | Dimensión tiempo |
| `marts.dim_oficina` | Dimensión oficina |

---

## Estructura del proyecto

```
proyecto-tyg-v4/
├── docker-compose.yml          # Orquestación de 3 contenedores
│
├── mysql-oltp/
│   └── init/
│       └── bd_transaccional.sql  # Schema + datos OLTP (sin cambios)
│
├── postgres-bi/
│   └── init/
│       └── 01_schema_tyg.sql     # Schema PG: raw + marts + meta
│
├── etl/
│   ├── Dockerfile               # Imagen Python + dbt-postgres
│   ├── requirements.txt         # pandas, sqlalchemy, dbt-postgres
│   ├── ingest.py                # Motor CDC incremental
│   └── main.py                  # Orquestador del pipeline
│
└── dbt_tyg/
    ├── dbt_project.yml          # Configuración DBT
    ├── profiles.yml             # Conexión a PostgreSQL
    └── models/
        ├── staging/
        │   ├── sources.yml      # Declara raw.* como fuentes
        │   └── stg_ventas.sql   # Vista G de TyG en PostgreSQL
        └── marts/
            ├── schema.yml       # Documentación + tests
            ├── dim_tiempo.sql
            ├── dim_oficina.sql
            ├── hecho_ventas.sql
            ├── hecho_inventario.sql
            ├── hecho_canal.sql
            └── hecho_desempeno.sql
```

---

## Cómo funciona el CDC Manual

### Columnas de auditoría en MySQL

Todas las tablas OLTP ya tienen:
```sql
updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
```

### Flujo incremental por tabla

```
PostgreSQL (meta.etl_sync_log)
  last_sync_at = "2025-12-01 10:00:00"
         │
         ▼
MySQL: SELECT * FROM ventas WHERE updated_at > '2025-12-01 10:00:00'
         │
         ▼
  50 filas nuevas/modificadas
         │
         ▼
PostgreSQL (raw.ventas): INSERT ... ON CONFLICT (venta_id) DO UPDATE
         │
         ▼
meta.etl_sync_log: last_sync_at = "2025-12-01 10:05:00"
```

### Inspeccionar el log de sincronizaciones

```sql
-- Conectado a tyg_datamart en PostgreSQL:
SELECT tabla_origen, last_sync_at, rows_extracted, rows_loaded, status
FROM meta.etl_sync_log
ORDER BY executed_at DESC
LIMIT 20;
```

---

## Comandos útiles

### Ejecutar pipeline manualmente
```bash
docker exec tyg-etl-container python /app/etl/main.py
```

### Solo CDC (sin DBT)
```bash
docker exec tyg-etl-container python /app/etl/ingest.py
```

### Solo DBT
```bash
docker exec tyg-etl-container dbt run --project-dir /app/dbt_tyg --profiles-dir /app/dbt_tyg
```

### Tests de calidad de datos DBT
```bash
docker exec tyg-etl-container dbt test --project-dir /app/dbt_tyg --profiles-dir /app/dbt_tyg
```

### Documentación DBT
```bash
docker exec tyg-etl-container dbt docs generate --project-dir /app/dbt_tyg --profiles-dir /app/dbt_tyg
docker exec tyg-etl-container dbt docs serve --port 8080 --project-dir /app/dbt_tyg --profiles-dir /app/dbt_tyg
# Acceder en: http://localhost:8080
```

---

## Mejoras implementadas vs versión anterior

| Aspecto | v3 (anterior) | v4 (nueva) |
|---------|--------------|------------|
| BD destino | MySQL 8.4 | **PostgreSQL 16** |
| Modo carga | Inserción masiva manual | **CDC incremental** (solo cambios) |
| Transformación | Scripts SQL manuales | **DBT** (versionado, testeado, documentado) |
| Automatización | Comandos manuales | **Pipeline orquestado** (5 min) |
| Calidad de datos | Sin validación | **dbt test** automático |
| Observabilidad | Sin trazabilidad | **meta.etl_sync_log** completo |
| Separación de capas | Ninguna | **raw / marts / meta** |
