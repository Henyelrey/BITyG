-- =============================================================
-- ETL: Poblar el Data Mart tyg_datamart
-- Ejecutar en: tyg-bi-container  →  mysql -u root < 3_poblar_tyg.sql
-- Requiere: bd_transaccional (staging) y tyg_datamart creados
-- Requiere: vw_g_ventas_tyg creada en bd_transaccional
-- =============================================================
USE tyg_datamart;
-- Desactivar el modo estricto de agrupación para permitir el ETL
SET sql_mode=(SELECT REPLACE(@@sql_mode,'ONLY_FULL_GROUP_BY',''));

-- =============================================================
-- 1. DTIEMPO — fechas de venta
-- =============================================================
INSERT IGNORE INTO dim_tiempo
    (DTiem_id, fecha, dia, semana, mes, nombre_mes, trimestre, anio, fecha_venta)
SELECT DISTINCT
    CAST(DATE_FORMAT(v.fecha_venta, '%Y%m%d') AS UNSIGNED),
    v.fecha_venta,
    DAY(v.fecha_venta),
    WEEK(v.fecha_venta, 3),
    MONTH(v.fecha_venta),
    MONTHNAME(v.fecha_venta),
    QUARTER(v.fecha_venta),
    YEAR(v.fecha_venta),
    v.fecha_venta
FROM bd_transaccional.ventas v;

-- Fechas de recepción (KPI P2 navega por fecha_recepcion)
INSERT IGNORE INTO dim_tiempo
    (DTiem_id, fecha, dia, semana, mes, nombre_mes, trimestre, anio, fecha_recepcion)
SELECT DISTINCT
    CAST(DATE_FORMAT(r.fecha_recepcion, '%Y%m%d') AS UNSIGNED),
    r.fecha_recepcion,
    DAY(r.fecha_recepcion),
    WEEK(r.fecha_recepcion, 3),
    MONTH(r.fecha_recepcion),
    MONTHNAME(r.fecha_recepcion),
    QUARTER(r.fecha_recepcion),
    YEAR(r.fecha_recepcion),
    r.fecha_recepcion
FROM bd_transaccional.recepciones r;

-- Primer día de cada mes de metas (KPI P3-2)
INSERT IGNORE INTO dim_tiempo
    (DTiem_id, fecha, dia, semana, mes, nombre_mes, trimestre, anio)
SELECT DISTINCT
    CAST(DATE_FORMAT(
        STR_TO_DATE(CONCAT(m.anio,'-',LPAD(m.mes_num,2,'0'),'-01'),'%Y-%m-%d'),
        '%Y%m%d') AS UNSIGNED),
    STR_TO_DATE(CONCAT(m.anio,'-',LPAD(m.mes_num,2,'0'),'-01'),'%Y-%m-%d'),
    1,
    WEEK(STR_TO_DATE(CONCAT(m.anio,'-',LPAD(m.mes_num,2,'0'),'-01'),'%Y-%m-%d'),3),
    m.mes_num,
    MONTHNAME(STR_TO_DATE(CONCAT(m.anio,'-',LPAD(m.mes_num,2,'0'),'-01'),'%Y-%m-%d')),
    QUARTER(STR_TO_DATE(CONCAT(m.anio,'-',LPAD(m.mes_num,2,'0'),'-01'),'%Y-%m-%d')),
    m.anio
FROM bd_transaccional.metas m;

-- =============================================================
-- 2. DOFICINA — columnas reales: oficina_id, nom_oficina, region
-- =============================================================
INSERT INTO dim_oficina (oficina_id, nom_oficina, departamento, region, zona)
SELECT oficina_id, nom_oficina, departamento, region, zona
FROM bd_transaccional.oficinas
ON DUPLICATE KEY UPDATE
    nom_oficina  = VALUES(nom_oficina),
    departamento = VALUES(departamento),
    region       = VALUES(region),
    zona         = VALUES(zona);

-- =============================================================
-- 3. DESTADO — un registro por recepción con su estado actual
-- =============================================================
INSERT INTO dim_estado (estado, dias_desde_recepcion, flag_riesgo_90d, lote_serie)
SELECT DISTINCT
    r.estado_recepcion,
    r.dias_inactivo,
    CASE WHEN r.dias_inactivo > 90
          AND r.estado_recepcion <> 'VENDIDO' THEN 1 ELSE 0 END,
    p.serie
FROM bd_transaccional.recepciones r
LEFT JOIN bd_transaccional.productos p ON r.producto_id = p.producto_id;

-- =============================================================
-- 4. DASESOR_PDV — canal DIRECTO (vendedores) y PDV (asesores)
-- Columnas reales: vendedor_id, nom_vendedor | asesor_pdv_id, nom_asesor_pdv
-- =============================================================
INSERT INTO dim_asesor_pdv (origen_id, nom_cliente_pdv, tipo_canal, monto_asociado)
SELECT vendedor_id, nom_vendedor, 'DIRECTO', 220.00
FROM bd_transaccional.vendedores
ON DUPLICATE KEY UPDATE nom_cliente_pdv = VALUES(nom_cliente_pdv);

INSERT INTO dim_asesor_pdv (origen_id, nom_cliente_pdv, tipo_canal, monto_asociado)
SELECT asesor_pdv_id, nom_asesor_pdv, 'PDV', 160.00
FROM bd_transaccional.asesores
ON DUPLICATE KEY UPDATE nom_cliente_pdv = VALUES(nom_cliente_pdv);

-- =============================================================
-- 5. HECHO_VENTAS — P1: Ventas y Activación
-- Una fila por venta individual
-- =============================================================
INSERT INTO hecho_ventas
    (DTiem_id, DOfic_id, DEst_id,
     kits_vendidos, kits_activos, tasa_activacion_pct,
     ingresos_s, venta_id, serie, canal_venta)
SELECT
    CAST(DATE_FORMAT(g.fecha_venta,'%Y%m%d') AS UNSIGNED),
    o.DOfic_id,
    COALESCE(e.DEst_id, NULL),
    1,
    g.es_activacion,
    g.es_activacion * 100.00,
    g.monto_calculado,
    g.venta_id,
    g.serie_producto,
    g.canal_venta
FROM bd_transaccional.vw_g_ventas_tyg g
JOIN  dim_oficina o ON g.oficina_id  = o.oficina_id
LEFT JOIN dim_estado e ON e.lote_serie = g.serie_producto;

-- Contribución porcentual por oficina (post-carga)
UPDATE hecho_ventas hv
JOIN (
    SELECT DOfic_id, SUM(ingresos_s) AS ing_of
    FROM hecho_ventas GROUP BY DOfic_id
) sub_of ON hv.DOfic_id = sub_of.DOfic_id
JOIN (SELECT SUM(ingresos_s) AS ing_tot FROM hecho_ventas) sub_tot ON 1=1
SET hv.contribucion_pct = ROUND((sub_of.ing_of / NULLIF(sub_tot.ing_tot,0)) * 100, 2);

-- =============================================================
-- 6. HECHO_INVENTARIO — P2: Inventario y Riesgo
-- Una fila por recepción individual
-- =============================================================
INSERT INTO hecho_inventario
    (DTiem_id, DOfic_id, DEst_id,
     dias_inactivo, kits_riesgo_90d, rotation_lote, serie)
SELECT
    CAST(DATE_FORMAT(r.fecha_recepcion,'%Y%m%d') AS UNSIGNED),
    o.DOfic_id,
    e.DEst_id,
    COALESCE(r.dias_inactivo, 0),
    CASE WHEN r.dias_inactivo > 90
          AND r.estado_recepcion <> 'VENDIDO' THEN 1 ELSE 0 END,
    DATEDIFF(v.fecha_venta, r.fecha_recepcion),   -- NULL si aún no vendido
    p.serie
FROM bd_transaccional.recepciones r
JOIN  bd_transaccional.productos   p   ON r.producto_id  = p.producto_id
JOIN  bd_transaccional.oficinas    ofi ON r.oficina_id   = ofi.oficina_id
JOIN  dim_oficina                  o   ON ofi.oficina_id = o.oficina_id
LEFT JOIN bd_transaccional.ventas  v   ON v.recepcion_id = r.recepcion_id
LEFT JOIN dim_estado               e   ON e.lote_serie   = p.serie;

-- =============================================================
-- 7. HECHO_CANAL — P3a: Mix de Canal
-- Granularidad: mes × oficina (pivot de canal en una sola fila)
-- =============================================================
INSERT INTO hecho_canal
    (DTiem_id, DOfic_id,
     kits_canal_directo, kits_canal_pdv,
     ingresos_directo, ingresos_pdv, mix_canal_pct)
SELECT
    CAST(DATE_FORMAT(
        STR_TO_DATE(CONCAT(YEAR(g.fecha_venta),'-',LPAD(MONTH(g.fecha_venta),2,'0'),'-01'),
        '%Y-%m-%d'),'%Y%m%d') AS UNSIGNED)                          AS DTiem_id,
    o.DOfic_id,
    SUM(CASE WHEN g.canal_venta='DIRECTO' THEN 1 ELSE 0 END)        AS kits_directo,
    SUM(CASE WHEN g.canal_venta='PDV'     THEN 1 ELSE 0 END)        AS kits_pdv,
    SUM(CASE WHEN g.canal_venta='DIRECTO' THEN g.monto_calculado ELSE 0 END) AS ing_directo,
    SUM(CASE WHEN g.canal_venta='PDV'     THEN g.monto_calculado ELSE 0 END) AS ing_pdv,
    ROUND(SUM(CASE WHEN g.canal_venta='PDV' THEN 1 ELSE 0 END)/COUNT(*)*100,2)
FROM bd_transaccional.vw_g_ventas_tyg g
JOIN dim_oficina o ON g.oficina_id = o.oficina_id
GROUP BY YEAR(g.fecha_venta), MONTH(g.fecha_venta), o.DOfic_id;

-- =============================================================
-- 8. HECHO_DESEMPENO — P3b: Desempeño de Asesores y PDV
-- Granularidad: mes × oficina × asesor individual
-- =============================================================
INSERT INTO hecho_desempeno
    (DTiem_id, DOfic_id, DAses_id,
     kits_por_asesor, kits_activos_asesor, kits_inactivos_asesor,
     meta_kits_mes, cumplimiento_meta_pct, kits_inactivos_pct)
SELECT
    CAST(DATE_FORMAT(
        STR_TO_DATE(CONCAT(YEAR(g.fecha_venta),'-',LPAD(MONTH(g.fecha_venta),2,'0'),'-01'),
        '%Y-%m-%d'),'%Y%m%d') AS UNSIGNED)                          AS DTiem_id,
    o.DOfic_id,
    -- Resolve DAses_id: DIRECTO por vendedor_id, PDV por asesor_pdv_id
    COALESCE(
        da_dir.DAses_id,
        da_pdv.DAses_id
    )                                                                AS DAses_id,
    COUNT(*)                                                         AS kits_por_asesor,
    SUM(g.es_activacion)                                             AS kits_activos,
    SUM(1 - g.es_activacion)                                         AS kits_inactivos,
    -- Meta del mes desde tabla metas
    COALESCE((
        SELECT SUM(mt.meta_kits)
        FROM bd_transaccional.metas mt
        WHERE mt.oficina_id = g.oficina_id
          AND mt.anio       = YEAR(g.fecha_venta)
          AND mt.mes_num    = MONTH(g.fecha_venta)
        LIMIT 1
    ), 0)                                                            AS meta_kits_mes,
    -- KPI P3-2: Cumplimiento Meta (%)
    ROUND(
        SUM(g.es_activacion) / NULLIF(COALESCE((
            SELECT SUM(mt.meta_kits)
            FROM bd_transaccional.metas mt
            WHERE mt.oficina_id = g.oficina_id
              AND mt.anio       = YEAR(g.fecha_venta)
              AND mt.mes_num    = MONTH(g.fecha_venta)
            LIMIT 1
        ), 0), 0) * 100, 2
    )                                                                AS cumplimiento_meta_pct,
    -- KPI P3-3: % kits inactivos por asesor
    ROUND(SUM(1 - g.es_activacion) / COUNT(*) * 100, 2)             AS kits_inactivos_pct
FROM bd_transaccional.vw_g_ventas_tyg g
JOIN  dim_oficina    o      ON g.oficina_id   = o.oficina_id
LEFT JOIN dim_asesor_pdv da_dir ON da_dir.origen_id = g.vendedor_id  AND da_dir.tipo_canal = 'DIRECTO'
LEFT JOIN dim_asesor_pdv da_pdv ON da_pdv.origen_id = g.asesor_pdv_id AND da_pdv.tipo_canal = 'PDV'
GROUP BY
    YEAR(g.fecha_venta),
    MONTH(g.fecha_venta),
    g.oficina_id,
    g.vendedor_id,
    g.asesor_pdv_id;
