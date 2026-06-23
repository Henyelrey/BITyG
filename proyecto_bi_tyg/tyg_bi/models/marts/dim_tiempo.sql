/*
    dim_tiempo — Jerarquía: Anio → Trimestre → Mes → Semana → Fecha
    Clave surrogate: dtiem_id (formato YYYYMMDD como integer)
*/
{{ config(materialized='table') }}

-- Fechas de venta
with fechas_ventas as (
    select fecha_venta as fecha
    from {{ ref('stg_ventas') }}
    where fecha_venta is not null
),

-- Fechas de recepcion
fechas_recepciones as (
    select fecha_recepcion as fecha
    from {{ ref('stg_recepciones') }}
    where fecha_recepcion is not null
),

-- Primer dia de cada mes de metas
fechas_metas as (
    select fecha_mes as fecha
    from {{ ref('stg_metas') }}
    where fecha_mes is not null
),

-- Union de todas las fechas unicas
todas_fechas as (
    select fecha from fechas_ventas
    union
    select fecha from fechas_recepciones
    union
    select fecha from fechas_metas
),

final as (
    select
        cast(to_char(fecha, 'YYYYMMDD') as integer)   as dtiem_id,
        fecha,
        extract(day     from fecha)::smallint          as dia,
        extract(week    from fecha)::smallint          as semana,
        extract(month   from fecha)::smallint          as mes,
        to_char(fecha, 'TMMonth')                      as nombre_mes,
        extract(quarter from fecha)::smallint          as trimestre,
        extract(year    from fecha)::smallint          as anio
    from todas_fechas
)

select * from final
