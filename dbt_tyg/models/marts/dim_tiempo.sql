-- =============================================================
-- dim_tiempo.sql — Dimensión Tiempo
-- Genera la jerarquía: Año → Trimestre → Mes → Semana → Día
-- Incluye fechas de venta Y fechas de recepción (KPI P2)
-- Materialización incremental: agrega solo fechas nuevas.
-- =============================================================
{{ config(
    materialized='incremental',
    unique_key='dtiem_id',
    schema='marts'
) }}

WITH fechas_ventas AS (
    SELECT DISTINCT fecha_venta AS fecha
    FROM {{ source('raw', 'ventas') }}
    WHERE fecha_venta IS NOT NULL
    {% if is_incremental() %}
      AND fecha_venta > (SELECT COALESCE(MAX(fecha), '2000-01-01') FROM {{ this }})
    {% endif %}
),

fechas_recepciones AS (
    SELECT DISTINCT fecha_recepcion AS fecha
    FROM {{ source('raw', 'recepciones') }}
    WHERE fecha_recepcion IS NOT NULL
    {% if is_incremental() %}
      AND fecha_recepcion > (SELECT COALESCE(MAX(fecha), '2000-01-01') FROM {{ this }})
    {% endif %}
),

todas_fechas AS (
    SELECT fecha FROM fechas_ventas
    UNION
    SELECT fecha FROM fechas_recepciones
)

SELECT
    TO_CHAR(fecha, 'YYYYMMDD')::INT            AS dtiem_id,
    fecha,
    EXTRACT(DAY   FROM fecha)::SMALLINT        AS dia,
    EXTRACT(WEEK  FROM fecha)::SMALLINT        AS semana,
    EXTRACT(MONTH FROM fecha)::SMALLINT        AS mes,
    TO_CHAR(fecha, 'TMMonth')                  AS nombre_mes,
    EXTRACT(QUARTER FROM fecha)::SMALLINT      AS trimestre,
    EXTRACT(YEAR  FROM fecha)::SMALLINT        AS anio,
    NULL::DATE                                 AS fecha_recepcion,
    fecha                                      AS fecha_venta
FROM todas_fechas
