/*
    fact_canal — P3a: Mix de Canal
    Granularidad: una fila por mes × oficina
    KPI P3-1: Mix Canal % Directo vs PDV
*/
{{ config(materialized='table') }}

with ventas as (
    select * from {{ ref('stg_ventas') }}
),

activaciones as (
    select * from {{ ref('stg_activaciones') }}
),

dim_tiempo as (
    select * from {{ ref('dim_tiempo') }}
),

dim_oficina as (
    select * from {{ ref('dim_oficina') }}
),

-- Enriquecer ventas con activacion
ventas_con_activacion as (
    select
        v.venta_id,
        v.oficina_id,
        v.canal_venta,
        v.fecha_venta,
        v.monto_calculado,
        -- Para el pivot mensual usamos el primer día del mes
        date_trunc('month', v.fecha_venta)::date    as fecha_mes
    from ventas v
    left join activaciones a on v.venta_id = a.venta_id
),

-- Agregar por mes × oficina haciendo pivot de canal
agregado as (
    select
        fecha_mes,
        oficina_id,

        -- KPI P3-1: Kits por canal
        sum(case when canal_venta = 'DIRECTO' then 1 else 0 end) as kits_canal_directo,
        sum(case when canal_venta = 'PDV'     then 1 else 0 end) as kits_canal_pdv,

        -- Ingresos por canal
        sum(case when canal_venta = 'DIRECTO' then monto_calculado else 0 end) as ingresos_directo,
        sum(case when canal_venta = 'PDV'     then monto_calculado else 0 end) as ingresos_pdv,

        -- Total para calcular porcentaje
        count(*) as total_kits

    from ventas_con_activacion
    group by fecha_mes, oficina_id
),

final as (
    select
        -- Claves surrogate de dimensiones (Si falta en dim_tiempo, forzamos el id generado para evitar NULLs)
        coalesce(t.dtiem_id, cast(to_char(a.fecha_mes, 'YYYYMMDD') as integer)) as dtiem_id,
        o.dofic_id,

        -- Medidas P3a
        a.kits_canal_directo,
        a.kits_canal_pdv,
        a.ingresos_directo,
        a.ingresos_pdv,

        -- KPI P3-1: % PDV sobre total
        round(
            a.kits_canal_pdv::numeric / nullif(a.total_kits, 0) * 100,
            2
        )                                           as mix_canal_pct

    from agregado a
    left join dim_tiempo  t on cast(to_char(a.fecha_mes, 'YYYYMMDD') as integer) = t.dtiem_id
    left join dim_oficina o on a.oficina_id = o.oficina_id
)

select * from final