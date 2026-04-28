USE bd_transaccional;

-- Vista G: El motor de transformación para los 9 KPIs
CREATE OR REPLACE VIEW vw_g_ventas_tyg AS
SELECT 
    v.venta_id,
    v.oficina_id,
    v.fecha_venta,
    r.fecha_recepcion,
    -- KPI P3-1: Monto diferenciado por canal (Asesor S/ 220, PDV S/ 160)
    CASE 
        WHEN v.canal_venta = 'DIRECTO' THEN 220.00 
        WHEN v.canal_venta = 'PDV' THEN 160.00 
        ELSE v.monto_venta 
    END AS monto_calculado,
    -- KPI P2-3: Rotación de Lote (Días desde que se recibe hasta que se vende)
    DATEDIFF(v.fecha_venta, r.fecha_recepcion) AS dias_rotacion,
    -- KPI P2-1: Flag de riesgo (Más de 90 días sin vender)
    IF(DATEDIFF(v.fecha_venta, r.fecha_recepcion) > 90, 1, 0) AS es_riesgo,
    -- KPI P1-1: Estado de activación real
    COALESCE(a.flag_activo, 0) AS es_activacion,
    v.vendedor_id,    -- ID para canal Asesor (Directo)
    v.asesor_pdv_id,  -- ID para canal PDV (Indirecto)
    v.canal_venta
FROM ventas v
INNER JOIN recepciones r ON v.recepcion_id = r.recepcion_id
LEFT JOIN activaciones a ON v.venta_id = a.venta_id;