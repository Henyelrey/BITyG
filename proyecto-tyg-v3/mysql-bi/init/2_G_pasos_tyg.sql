-- IMPORTANTE: Ejecutar sobre bd_transaccional (base OLTP)
USE bd_transaccional;

CREATE OR REPLACE VIEW vw_g_ventas_tyg AS
SELECT
    v.venta_id,
    v.oficina_id,
    v.producto_id,
    v.vendedor_id,
    v.asesor_pdv_id,
    v.canal_venta,
    v.fecha_venta,
    r.recepcion_id,
    r.fecha_recepcion,
    r.estado_recepcion,
    r.dias_inactivo,

    -- KPI P1-2 / P3-1: Monto segun canal
    CASE
        WHEN v.canal_venta = 'DIRECTO' THEN 220.00
        WHEN v.canal_venta = 'PDV'     THEN 160.00
        ELSE v.monto_venta
    END AS monto_calculado,

    -- KPI P2-3: Dias entre recepcion y venta
    DATEDIFF(v.fecha_venta, r.fecha_recepcion) AS dias_lead_time,

    -- KPI P2-1: Flag riesgo inventario > 90 dias
    CASE
        WHEN r.dias_inactivo > 90
         AND r.estado_recepcion <> 'VENDIDO' THEN 1
        ELSE 0
    END AS flag_riesgo_90d,

    -- KPI P1-1 / P3-2 / P3-3: Activacion real
    COALESCE(a.flag_activo, 0) AS es_activacion,

    -- Trazabilidad de lote
    p.serie AS serie_producto

FROM ventas v
LEFT JOIN recepciones r  ON v.recepcion_id = r.recepcion_id
LEFT JOIN activaciones a ON v.venta_id     = a.venta_id
LEFT JOIN productos    p ON v.producto_id  = p.producto_id;
