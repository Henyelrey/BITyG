-- =============================================================
-- DATA MART TyG — Modelo Constelación
-- Ejecutar en: tyg-bi-container  →  mysql -u root tyg_datamart
-- =============================================================
CREATE DATABASE IF NOT EXISTS `tyg_datamart` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `tyg_datamart`;

SET FOREIGN_KEY_CHECKS = 0;

-- =============================================================
-- DIMENSIONES (crear primero)
-- =============================================================

DROP TABLE IF EXISTS hecho_desempeno;
DROP TABLE IF EXISTS hecho_canal;
DROP TABLE IF EXISTS hecho_inventario;
DROP TABLE IF EXISTS hecho_ventas;
DROP TABLE IF EXISTS dim_asesor_pdv;
DROP TABLE IF EXISTS dim_estado;
DROP TABLE IF EXISTS dim_oficina;
DROP TABLE IF EXISTS dim_tiempo;

-- -------------------------------------------------------------
-- DTIEMPO — Jerarquía: Anio → Trimestre → Mes → Semana → Fecha
-- -------------------------------------------------------------
CREATE TABLE dim_tiempo (
    DTiem_id        INT          NOT NULL,   -- YYYYMMDD
    fecha           DATE         NOT NULL,
    dia             TINYINT,
    semana          TINYINT,
    mes             TINYINT,
    nombre_mes      VARCHAR(20),
    trimestre       TINYINT,
    anio            SMALLINT,
    fecha_recepcion DATE,
    fecha_venta     DATE,
    PRIMARY KEY (DTiem_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -------------------------------------------------------------
-- DOFICINA — Jerarquía: Region → Departamento → Zona → Oficina
-- -------------------------------------------------------------
CREATE TABLE dim_oficina (
    DOfic_id      INT          NOT NULL AUTO_INCREMENT,
    oficina_id    INT          NOT NULL,
    nom_oficina   VARCHAR(100),
    departamento  VARCHAR(100),
    region        VARCHAR(100),
    zona          VARCHAR(100),
    PRIMARY KEY (DOfic_id),
    UNIQUE KEY uq_oficina (oficina_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -------------------------------------------------------------
-- DESTADO — Jerarquía: Flag_riesgo_90d → Estado
-- -------------------------------------------------------------
CREATE TABLE dim_estado (
    DEst_id              INT         NOT NULL AUTO_INCREMENT,
    estado               VARCHAR(30) NOT NULL,
    dias_desde_recepcion INT,
    flag_riesgo_90d      TINYINT(1)  DEFAULT 0,
    lote_serie           VARCHAR(50),
    PRIMARY KEY (DEst_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -------------------------------------------------------------
-- DASESOR_PDV — Jerarquía: Tipo_canal → Asesor
-- Unifica vendedores DIRECTO (S/220) y asesores PDV (S/160)
-- -------------------------------------------------------------
CREATE TABLE dim_asesor_pdv (
    DAses_id        INT          NOT NULL AUTO_INCREMENT,
    origen_id       INT          NOT NULL,
    nom_cliente_pdv VARCHAR(150),
    tipo_canal      VARCHAR(20),
    monto_asociado  DECIMAL(10,2),
    PRIMARY KEY (DAses_id),
    UNIQUE KEY uq_asesor (origen_id, tipo_canal)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =============================================================
-- TABLAS DE HECHOS (sin FK para evitar errores de orden/NULL)
-- Los joins se hacen en Power BI con las claves surrogate
-- =============================================================

-- -------------------------------------------------------------
-- HVENTAS — P1: Ventas y Activación
-- KPI P1-1 Tasa Activación | P1-2 Ingresos | P1-3 Contribución
-- -------------------------------------------------------------
CREATE TABLE hecho_ventas (
    hventas_key         BIGINT       NOT NULL AUTO_INCREMENT,
    DTiem_id            INT,
    DOfic_id            INT,
    DEst_id             INT,
    kits_vendidos       INT          DEFAULT 1,
    kits_activos        INT          DEFAULT 0,
    tasa_activacion_pct DECIMAL(5,2) DEFAULT 0.00,
    ingresos_s          DECIMAL(12,2) DEFAULT 0.00,
    contribucion_pct    DECIMAL(5,2) DEFAULT 0.00,
    venta_id            INT,
    serie               VARCHAR(50),
    canal_venta         VARCHAR(30),
    PRIMARY KEY (hventas_key),
    KEY idx_hv_tiempo  (DTiem_id),
    KEY idx_hv_oficina (DOfic_id),
    KEY idx_hv_estado  (DEst_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -------------------------------------------------------------
-- HINVENTARIO — P2: Inventario y Riesgo
-- KPI P2-1 Kits Riesgo 90d | P2-2 Días Inactivo | P2-3 Rotación
-- -------------------------------------------------------------
CREATE TABLE hecho_inventario (
    hinventario_key BIGINT        NOT NULL AUTO_INCREMENT,
    DTiem_id        INT,
    DOfic_id        INT,
    DEst_id         INT,
    dias_inactivo   INT           DEFAULT 0,
    kits_riesgo_90d TINYINT(1)    DEFAULT 0,
    rotation_lote   DECIMAL(8,2)  DEFAULT NULL,
    serie           VARCHAR(50),
    PRIMARY KEY (hinventario_key),
    KEY idx_hi_tiempo  (DTiem_id),
    KEY idx_hi_oficina (DOfic_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -------------------------------------------------------------
-- HCANAL — P3a: Mix de Canal
-- KPI P3-1 Mix Canal % Directo vs PDV
-- Granularidad: mes × oficina (una fila por combinación)
-- -------------------------------------------------------------
CREATE TABLE hecho_canal (
    hcanal_key         BIGINT        NOT NULL AUTO_INCREMENT,
    DTiem_id           INT,
    DOfic_id           INT,
    kits_canal_directo INT           DEFAULT 0,
    kits_canal_pdv     INT           DEFAULT 0,
    ingresos_directo   DECIMAL(12,2) DEFAULT 0.00,
    ingresos_pdv       DECIMAL(12,2) DEFAULT 0.00,
    mix_canal_pct      DECIMAL(5,2)  DEFAULT 0.00,
    PRIMARY KEY (hcanal_key),
    KEY idx_hc_tiempo  (DTiem_id),
    KEY idx_hc_oficina (DOfic_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -------------------------------------------------------------
-- HDESEMPENO — P3b: Desempeño de Asesores y PDV
-- KPI P3-2 Cumplimiento Meta | P3-3 Kits x Asesor / % Inactivos
-- Granularidad: mes × oficina × asesor individual
-- -------------------------------------------------------------
CREATE TABLE hecho_desempeno (
    hdesempeno_key        BIGINT        NOT NULL AUTO_INCREMENT,
    DTiem_id              INT,
    DOfic_id              INT,
    DAses_id              INT,
    kits_por_asesor       INT           DEFAULT 0,
    kits_activos_asesor   INT           DEFAULT 0,
    kits_inactivos_asesor INT           DEFAULT 0,
    meta_kits_mes         INT           DEFAULT 0,
    cumplimiento_meta_pct DECIMAL(5,2)  DEFAULT 0.00,
    kits_inactivos_pct    DECIMAL(5,2)  DEFAULT 0.00,
    PRIMARY KEY (hdesempeno_key),
    KEY idx_hd_tiempo  (DTiem_id),
    KEY idx_hd_oficina (DOfic_id),
    KEY idx_hd_asesor  (DAses_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET FOREIGN_KEY_CHECKS = 1;
