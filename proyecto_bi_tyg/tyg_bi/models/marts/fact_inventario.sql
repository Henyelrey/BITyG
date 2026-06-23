/*
    fact_inventario — P2: Inventario y Riesgo
    Granularidad: una fila por recepcion individual
    KPI P2-1 Kits en Riesgo 90d | P2-2 Días Inactivo | P2-3 Rotación de Lote
*/
{{ config(materialized='table') }}

with recepciones as (
    select * from {{ ref('stg_recepciones') }}
),

ventas as (
    select * from {{ ref('stg_ventas') }}
),

productos as (
    select * from {{ ref('stg_productos') }}
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

-- Cruzar recepcion con venta (si existe) para calcular rotacion
recepciones_con_venta as (
    select
        r.recepcion_id,
        r.oficina_id,
        r.producto_id,
        r.fecha_recepcion,
        r.estado_recepcion,
        r.dias_inactivo,
        r.flag_riesgo_90d,
        p.serie,
        v.fecha_venta,
        -- KPI P2-3: días entre recepcion y venta (NULL si aún no vendido)
        case
            when v.fecha_venta is not null
            then v.fecha_venta - r.fecha_recepcion
        end                             as dias_rotacion_lote
    from recepciones r
    left join productos p on r.producto_id  = p.producto_id
    left join ventas    v on v.recepcion_id = r.recepcion_id
),

final as (
    select
        -- Claves surrogate de dimensiones
        t.dtiem_id,
        o.dofic_id,
        e.dest_id,

        -- Atributo degenerado trazabilidad
        rc.serie,

        -- Medidas P2
        rc.dias_inactivo,
        rc.flag_riesgo_90d::integer                     as kits_riesgo_90d,
        rc.dias_rotacion_lote                           as rotation_lote

    from recepciones_con_venta rc
    -- Join con dimensiones
    left join dim_tiempo  t on cast(to_char(rc.fecha_recepcion, 'YYYYMMDD') as integer) = t.dtiem_id
    left join dim_oficina o on rc.oficina_id = o.oficina_id
    left join dim_estado  e on e.lote_serie  = rc.serie
)

select * from final
