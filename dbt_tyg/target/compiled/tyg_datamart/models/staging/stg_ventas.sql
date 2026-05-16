-- =============================================================
-- stg_ventas.sql — Staging de Ventas
-- Limpieza, estandarización y enriquecimiento
-- =============================================================


WITH source AS (
    SELECT * FROM "tyg_datamart"."raw"."ventas"
),

staging AS (
    SELECT
        v.venta_id,
        v.oficina_id,
        v.vendedor_id,
        v.asesor_pdv_id,
        v.cliente_id,
        v.producto_id,
        v.recepcion_id,
        v.fecha_venta,
        v.mes,
        v.monto_venta,
        v.canal_venta,
        v.estado_venta,
        v.created_at,
        v.updated_at,

        -- Monto calculado según canal de venta (regla de negocio TyG)
        CASE
            WHEN v.canal_venta = 'DIRECTO' THEN 220.00
            WHEN v.canal_venta = 'PDV'     THEN 160.00
            ELSE v.monto_venta
        END AS monto_calculado,
        
        -- Enriquecimiento con datos de recepción
        r.fecha_recepcion,
        r.lote              AS serie_lote,
        r.estado_recepcion,
        r.dias_inactivo,
        
        -- Activación
        COALESCE(a.flag_activo, FALSE) AS es_activacion
        
    FROM source v
    LEFT JOIN "tyg_datamart"."raw"."recepciones"  r ON v.recepcion_id = r.recepcion_id
    LEFT JOIN "tyg_datamart"."raw"."activaciones" a ON v.venta_id     = a.venta_id
)

SELECT * FROM staging