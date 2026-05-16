-- =============================================================
-- hecho_canal.sql — Mix de Canal (Directo vs PDV)
-- KPI P3-1: % participación de cada canal por mes y oficina
-- Grano: mes × oficina
-- =============================================================
{{ config(
    materialized='incremental',
    unique_key=['dtiem_id', 'dofic_id'],
    schema='marts'
) }}

SELECT
    TO_CHAR(DATE_TRUNC('month', v.fecha_venta), 'YYYYMMDD')::INT  AS dtiem_id,
    v.oficina_id                                                    AS dofic_id,

    COUNT(*) FILTER (WHERE v.canal_venta = 'DIRECTO')              AS kits_canal_directo,
    COUNT(*) FILTER (WHERE v.canal_venta = 'PDV')                  AS kits_canal_pdv,

    SUM(CASE WHEN v.canal_venta = 'DIRECTO' THEN 220.00 ELSE 0 END)::NUMERIC(12,2)
                                                                   AS ingresos_directo,
    SUM(CASE WHEN v.canal_venta = 'PDV'     THEN 160.00 ELSE 0 END)::NUMERIC(12,2)
                                                                   AS ingresos_pdv,

    -- KPI P3-1: % kits canal DIRECTO sobre total del mes/oficina
    ROUND(
        COUNT(*) FILTER (WHERE v.canal_venta = 'DIRECTO')::NUMERIC
        / NULLIF(COUNT(*), 0) * 100
    , 2)                                                           AS mix_canal_pct,

    NOW()                                                          AS _dbt_updated_at

FROM {{ source('raw', 'ventas') }} v

{% if is_incremental() %}
WHERE v.fecha_venta >= (
    SELECT DATE_TRUNC('month', COALESCE(MAX(_dbt_updated_at), '2000-01-01'))
    FROM {{ this }}
)
{% endif %}

GROUP BY 1, 2
