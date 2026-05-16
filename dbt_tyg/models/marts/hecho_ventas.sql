-- =============================================================
-- hecho_ventas.sql — Tabla de Hechos Principal
-- KPIs: P1-1 Tasa Activación | P1-2 Ingresos | P1-3 Contribución
-- Grano: una fila por venta individual
-- =============================================================
{{
    config(
        materialized='incremental',
        unique_key='venta_id',
        schema='marts'
    )
}}

WITH base AS (
    SELECT * FROM {{ ref('stg_ventas') }}
    {% if is_incremental() %}
    WHERE updated_at > (
        SELECT COALESCE(MAX(_dbt_updated_at), '2000-01-01'::TIMESTAMP) 
        FROM {{ this }}
    )
    {% endif %}
),

totales_por_oficina_mes AS (
    SELECT
        oficina_id,
        DATE_TRUNC('month', fecha_venta) AS mes_venta,
        SUM(monto_calculado) AS total_ingresos_mes
    FROM {{ ref('stg_ventas') }}
    GROUP BY 1, 2
)

SELECT
    b.venta_id,
    TO_CHAR(b.fecha_venta, 'YYYYMMDD')::INT            AS dtiem_id,
    o.oficina_id                                        AS dofic_id,
    r_dim.recepcion_id                                  AS dest_id,

    -- Métricas de hechos
    1                                                   AS kits_vendidos,
    CASE WHEN b.es_activacion THEN 1 ELSE 0 END        AS kits_activos,
    b.monto_calculado                                   AS ingresos_s,

    -- KPI P1-1: Tasa de activación
    CASE WHEN b.es_activacion THEN 100.00 ELSE 0.00 END AS tasa_activacion_pct,

    -- KPI P1-3: Contribución % sobre el total del mes/oficina
    ROUND(
        b.monto_calculado / NULLIF(t.total_ingresos_mes, 0) * 100
    , 2)                                                AS contribucion_pct,

    b.serie_lote                                        AS serie,
    b.canal_venta,
    NOW()                                               AS _dbt_updated_at   -- ✅ CORREGIDO (era doble alias)

FROM base b
LEFT JOIN {{ source('raw', 'oficinas') }}    o     ON b.oficina_id    = o.oficina_id
LEFT JOIN {{ source('raw', 'recepciones') }} r_dim ON b.recepcion_id  = r_dim.recepcion_id
LEFT JOIN totales_por_oficina_mes t
    ON  b.oficina_id = t.oficina_id
   AND DATE_TRUNC('month', b.fecha_venta) = t.mes_venta