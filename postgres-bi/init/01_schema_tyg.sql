-- =============================================================
-- PostgreSQL 16 — tyg_datamart
-- Archivo: 01_schema_tyg.sql
-- Ejecutado automáticamente al crear el contenedor
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- SCHEMAS
--   raw      → datos crudos recibidos del CDC (capa staging)
--   marts    → tablas de hechos y dimensiones finales (DBT)
--   meta     → metadatos del pipeline ETL
-- ─────────────────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS marts;
CREATE SCHEMA IF NOT EXISTS meta;

-- ─────────────────────────────────────────────────────────────
-- META: Registro de sincronizaciones CDC
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS meta.etl_sync_log (
    sync_id         SERIAL PRIMARY KEY,
    tabla_origen    VARCHAR(100)  NOT NULL,
    last_sync_at    TIMESTAMPTZ   NOT NULL DEFAULT '2000-01-01 00:00:00+00',
    rows_extracted  INT           DEFAULT 0,
    rows_loaded     INT           DEFAULT 0,
    status          VARCHAR(20)   DEFAULT 'PENDING',  -- PENDING | SUCCESS | ERROR
    error_msg       TEXT,
    executed_at     TIMESTAMPTZ   DEFAULT NOW()
);

-- Registro inicial para cada tabla que se sincroniza
INSERT INTO meta.etl_sync_log (tabla_origen, last_sync_at, status)
VALUES
    ('ventas',       '2000-01-01 00:00:00+00', 'PENDING'),
    ('recepciones',  '2000-01-01 00:00:00+00', 'PENDING'),
    ('activaciones', '2000-01-01 00:00:00+00', 'PENDING'),
    ('oficinas',     '2000-01-01 00:00:00+00', 'PENDING'),
    ('vendedores',   '2000-01-01 00:00:00+00', 'PENDING'),
    ('asesores',     '2000-01-01 00:00:00+00', 'PENDING'),
    ('metas',        '2000-01-01 00:00:00+00', 'PENDING')
ON CONFLICT DO NOTHING;

-- ─────────────────────────────────────────────────────────────
-- RAW: Tablas de staging (espejo de MySQL, columnas idénticas)
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS raw.ventas (
    venta_id        INT PRIMARY KEY,
    oficina_id      INT,
    vendedor_id     INT,
    asesor_pdv_id   INT,
    cliente_id      INT,
    producto_id     INT,
    recepcion_id    INT,
    fecha_venta     DATE,
    mes             VARCHAR(20),
    monto_venta     NUMERIC(10,2),
    canal_venta     VARCHAR(30),
    estado_venta    VARCHAR(30),
    created_at      TIMESTAMP,
    updated_at      TIMESTAMP,
    _cdc_loaded_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS raw.recepciones (
    recepcion_id         INT PRIMARY KEY,
    oficina_id           INT,
    producto_id          INT,
    fecha_recepcion      DATE,
    lote                 VARCHAR(50),
    estado_recepcion     VARCHAR(30),
    dias_inactivo        INT,
    ingresado_sin_venta  BOOLEAN,
    created_at           TIMESTAMP,
    updated_at           TIMESTAMP,
    _cdc_loaded_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS raw.activaciones (
    activacion_id    INT PRIMARY KEY,
    venta_id         INT,
    fecha_activacion DATE,
    flag_activo      BOOLEAN,
    created_at       TIMESTAMP,
    updated_at       TIMESTAMP,
    _cdc_loaded_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS raw.oficinas (
    oficina_id   INT PRIMARY KEY,
    nom_oficina  VARCHAR(100),
    departamento VARCHAR(100),
    region       VARCHAR(100),
    zona         VARCHAR(100),
    activo       BOOLEAN,
    created_at   TIMESTAMP,
    updated_at   TIMESTAMP,
    _cdc_loaded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS raw.vendedores (
    vendedor_id   INT PRIMARY KEY,
    nom_vendedor  VARCHAR(150),
    oficina_id    INT,
    activo        BOOLEAN,
    created_at    TIMESTAMP,
    updated_at    TIMESTAMP,
    _cdc_loaded_at TIMESTAMPTZ DEFAULT NOW()
);

-- CORREGIDO: raw.asesores ahora coincide con MySQL (asesor_pdv_id en lugar de asesor_id)
CREATE TABLE IF NOT EXISTS raw.asesores (
    asesor_pdv_id    INT PRIMARY KEY,
    nom_asesor_pdv   VARCHAR(150),
    tipo_canal       VARCHAR(30),
    monto_asociado   NUMERIC(10,2),
    activo           BOOLEAN,
    created_at       TIMESTAMP,
    updated_at       TIMESTAMP,
    _cdc_loaded_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS raw.metas (
    meta_id       INT PRIMARY KEY,
    oficina_id    INT,
    vendedor_id   INT,
    mes_num       INT,
    anio          INT,
    meta_kits     INT,
    created_at    TIMESTAMP,
    updated_at    TIMESTAMP,
    _cdc_loaded_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────
-- MARTS: Dimensiones y Hechos (pobladas por DBT)
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS marts.dim_tiempo (
    dtiem_id      INT         NOT NULL,
    fecha         DATE        NOT NULL,
    dia           SMALLINT,
    semana        SMALLINT,
    mes           SMALLINT,
    nombre_mes    VARCHAR(20),
    trimestre     SMALLINT,
    anio          SMALLINT,
    fecha_recepcion DATE,
    fecha_venta   DATE,
    PRIMARY KEY (dtiem_id)
);

CREATE TABLE IF NOT EXISTS marts.dim_oficina (
    dofic_id      SERIAL      PRIMARY KEY,
    oficina_id    INT         NOT NULL UNIQUE,
    nom_oficina   VARCHAR(100),
    departamento  VARCHAR(100),
    region        VARCHAR(100),
    zona          VARCHAR(100),
    updated_at    TIMESTAMP
);

CREATE TABLE IF NOT EXISTS marts.dim_estado (
    dest_id               SERIAL  PRIMARY KEY,
    estado                VARCHAR(30) NOT NULL,
    dias_desde_recepcion  INT,
    flag_riesgo_90d       BOOLEAN DEFAULT FALSE,
    lote_serie            VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS marts.dim_asesor_pdv (
    dases_id        SERIAL      PRIMARY KEY,
    origen_id       INT         NOT NULL,
    nom_cliente_pdv VARCHAR(150),
    tipo_canal      VARCHAR(20),
    monto_asociado  NUMERIC(10,2),
    UNIQUE (origen_id, tipo_canal)
);

CREATE TABLE IF NOT EXISTS marts.hecho_ventas (
    hventas_key         BIGSERIAL   PRIMARY KEY,
    dtiem_id            INT,
    dofic_id            INT,
    dest_id             INT,
    kits_vendidos       INT         DEFAULT 1,
    kits_activos        INT         DEFAULT 0,
    tasa_activacion_pct NUMERIC(5,2) DEFAULT 0.00,
    ingresos_s          NUMERIC(12,2) DEFAULT 0.00,
    contribucion_pct    NUMERIC(5,2) DEFAULT 0.00,
    venta_id            INT,
    serie               VARCHAR(50),
    canal_venta         VARCHAR(30),
    _dbt_updated_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS marts.hecho_inventario (
    hinventario_key BIGSERIAL   PRIMARY KEY,
    dtiem_id        INT,
    dofic_id        INT,
    dest_id         INT,
    dias_inactivo   INT         DEFAULT 0,
    kits_riesgo_90d BOOLEAN     DEFAULT FALSE,
    rotation_lote   NUMERIC(8,2),
    serie           VARCHAR(50),
    _dbt_updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS marts.hecho_canal (
    hcanal_key         BIGSERIAL   PRIMARY KEY,
    dtiem_id           INT,
    dofic_id           INT,
    kits_canal_directo INT         DEFAULT 0,
    kits_canal_pdv     INT         DEFAULT 0,
    ingresos_directo   NUMERIC(12,2) DEFAULT 0.00,
    ingresos_pdv       NUMERIC(12,2) DEFAULT 0.00,
    mix_canal_pct      NUMERIC(5,2) DEFAULT 0.00,
    _dbt_updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS marts.hecho_desempeno (
    hdesempeno_key        BIGSERIAL   PRIMARY KEY,
    dtiem_id              INT,
    dofic_id              INT,
    dases_id              INT,
    kits_por_asesor       INT         DEFAULT 0,
    kits_activos_asesor   INT         DEFAULT 0,
    kits_inactivos_asesor INT         DEFAULT 0,
    meta_kits_mes         INT         DEFAULT 0,
    cumplimiento_meta_pct NUMERIC(5,2) DEFAULT 0.00,
    kits_inactivos_pct    NUMERIC(5,2) DEFAULT 0.00,
    _dbt_updated_at       TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para mejorar performance en Power BI
CREATE INDEX IF NOT EXISTS idx_hv_tiempo   ON marts.hecho_ventas (dtiem_id);
CREATE INDEX IF NOT EXISTS idx_hv_oficina  ON marts.hecho_ventas (dofic_id);
CREATE INDEX IF NOT EXISTS idx_hi_tiempo   ON marts.hecho_inventario (dtiem_id);
CREATE INDEX IF NOT EXISTS idx_hc_tiempo   ON marts.hecho_canal (dtiem_id);
CREATE INDEX IF NOT EXISTS idx_hd_tiempo   ON marts.hecho_desempeno (dtiem_id);
CREATE INDEX IF NOT EXISTS idx_hd_asesor   ON marts.hecho_desempeno (dases_id);