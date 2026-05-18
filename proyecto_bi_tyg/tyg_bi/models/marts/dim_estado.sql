/*
    dim_estado — Jerarquía: Flag_riesgo_90d → Estado
    Clave surrogate: dest_id (Garantizando un lote_serie único y desinfectado)
*/
{{ config(materialized='table') }}

with recepciones as (
    select * from {{ ref('stg_recepciones') }}
),

productos as (
    select * from {{ ref('stg_productos') }}
),

-- 1. Desinfección radical: '\s+' detecta y elimina espacios, tabuladores, \r y \n en toda la cadena
estados_limpios as (
    select
        r.estado_recepcion          as estado,
        r.dias_inactivo             as dias_desde_recepcion,
        r.flag_riesgo_90d,
        regexp_replace(upper(p.serie), '\s+', '', 'g') as lote_serie
    from recepciones r
    left join productos p on r.producto_id = p.producto_id
    where p.serie is not null and regexp_replace(p.serie, '\s+', '', 'g') != ''
),

-- 2. Partición estricta sobre la cadena completamente limpia y homogeneizada
estados_ordenados as (
    select
        estado,
        dias_desde_recepcion,
        flag_riesgo_90d,
        lote_serie,
        row_number() over (
            partition by lote_serie 
            order by dias_desde_recepcion asc, estado desc
        )                           as rn
    from estados_limpios
),

-- 3. Nos quedamos únicamente con el registro maestro definitivo por cada serie única
estados_base as (
    select
        estado,
        dias_desde_recepcion,
        flag_riesgo_90d,
        lote_serie
    from estados_ordenados
    where rn = 1
),

final as (
    select
        row_number() over (
            order by estado, coalesce(lote_serie, '')
        )                           as dest_id,
        estado,
        dias_desde_recepcion,
        flag_riesgo_90d,
        lote_serie,
        'SI, SOY LA TABLA LIMPIA'  as tabla_viva_dbt
    from estados_base
)

select * from final