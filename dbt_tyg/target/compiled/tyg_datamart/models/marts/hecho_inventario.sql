

WITH ventas_agg AS (
    -- ✅ 1 fila por recepción: última fecha de venta
    SELECT recepcion_id, MAX(fecha_venta) AS fecha_venta
    FROM "tyg_datamart"."raw"."ventas"
    GROUP BY recepcion_id
),

source_data AS (
    SELECT
        r.recepcion_id,
        r.oficina_id,
        r.producto_id,
        r.fecha_recepcion,
        r.lote,
        r.estado_recepcion,
        r.dias_inactivo,
        r.ingresado_sin_venta,
        v.fecha_venta,
        r.updated_at,
        NOW() AS _dbt_updated_at
    FROM "tyg_datamart"."raw"."recepciones" r
    LEFT JOIN ventas_agg v ON r.recepcion_id = v.recepcion_id

    
    WHERE r.updated_at > (
        SELECT COALESCE(MAX(t._dbt_updated_at), '2000-01-01'::TIMESTAMP) 
        FROM "tyg_datamart"."marts_marts"."hecho_inventario" t
    )
    
),

-- ✅ Garantiza unicidad estricta incluso si el JOIN o CDC generan duplicados
deduplicated AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY recepcion_id ORDER BY _dbt_updated_at DESC) AS rn
    FROM source_data
)

SELECT
    recepcion_id,
    TO_CHAR(fecha_recepcion, 'YYYYMMDD')::INT AS dtiem_id,
    oficina_id AS dofic_id,
    recepcion_id AS dest_id,
    dias_inactivo,
    CASE WHEN dias_inactivo > 90 AND estado_recepcion <> 'VENDIDO' THEN TRUE ELSE FALSE END AS kits_riesgo_90d,
    CASE WHEN fecha_venta IS NOT NULL THEN (fecha_venta::DATE - fecha_recepcion::DATE)::NUMERIC(8,2) ELSE NULL::NUMERIC(8,2) END AS rotation_lote,
    lote AS serie,
    _dbt_updated_at
FROM deduplicated
WHERE rn = 1  -- ✅ Solo conserva la versión más reciente por recepcion_id