/*
    dim_estado — Jerarquía: Flag_riesgo_90d → Estado
    Clave surrogate: dest_id
*/
{{ config(materialized='table') }}

with recepciones as (
    select * from {{ ref('stg_recepciones') }}
),

productos as (
    select * from {{ ref('stg_productos') }}
),

estados_base as (
    select distinct
        r.estado_recepcion          as estado,
        r.dias_inactivo             as dias_desde_recepcion,
        r.flag_riesgo_90d,
        p.serie                     as lote_serie
    from recepciones r
    left join productos p on r.producto_id = p.producto_id
),

final as (
    select
        row_number() over (
            order by estado, coalesce(lote_serie, '')
        )                           as dest_id,
        estado,
        dias_desde_recepcion,
        flag_riesgo_90d,
        lote_serie
    from estados_base
)

select * from final
