/*
    fact_ventas — P1: Ventas y Activación
    Granularidad: una fila por venta individual
    KPI P1-1 Tasa de Activación | P1-2 Ingresos | P1-3 Contribución por oficina
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

dim_estado as (
    select * from {{ ref('dim_estado') }}
),

productos as (
    select * from {{ ref('stg_productos') }}
),

-- JOIN principal: venta + activacion + serie del producto
ventas_enriquecidas as (
    select
        v.venta_id,
        v.oficina_id,
        v.producto_id,
        v.vendedor_id,
        v.asesor_pdv_id,
        v.canal_venta,
        v.fecha_venta,
        v.monto_original,
        v.monto_calculado,
        coalesce(a.flag_activo, 0)  as es_activacion,
        p.serie                      as serie_producto
    from ventas v
    left join activaciones a on v.venta_id    = a.venta_id
    left join productos    p on v.producto_id = p.producto_id
),

-- Precalcular ingresos totales por oficina (para KPI P1-3 contribucion)
ingresos_por_oficina as (
    select
        oficina_id,
        sum(monto_calculado) as ingresos_oficina
    from ventas_enriquecidas
    group by oficina_id
),

ingresos_total as (
    select sum(monto_calculado) as ingresos_total
    from ventas_enriquecidas
),

final as (
    select
        -- Claves surrogate de dimensiones
        t.dtiem_id,
        o.dofic_id,
        e.dest_id,

        -- Atributos degenerados
        ve.venta_id,
        ve.canal_venta,
        ve.serie_producto                                               as serie,

        -- Medidas P1
        1                                                               as kits_vendidos,
        ve.es_activacion                                                as kits_activos,
        ve.es_activacion * 100.00                                       as tasa_activacion_pct,
        ve.monto_calculado                                              as ingresos_s,

        -- KPI P1-3: Contribucion de la oficina al total de ingresos
        round(
            iof.ingresos_oficina / nullif(it.ingresos_total, 0) * 100,
            2
        )                                                               as contribucion_pct

    from ventas_enriquecidas ve
    -- Join con dimensiones
    left join dim_tiempo  t on cast(to_char(ve.fecha_venta, 'YYYYMMDD') as integer) = t.dtiem_id
    left join dim_oficina o on ve.oficina_id = o.oficina_id
    left join dim_estado  e on e.lote_serie  = ve.serie_producto
    -- Ingresos para contribucion
    left join ingresos_por_oficina iof on ve.oficina_id = iof.oficina_id
    cross join ingresos_total it
)

select * from final
