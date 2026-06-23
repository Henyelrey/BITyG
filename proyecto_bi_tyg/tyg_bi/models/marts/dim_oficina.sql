/*
    dim_oficina — Jerarquía: Region → Departamento → Zona → Oficina
    Clave surrogate: dofic_id (generada con row_number)
*/
{{ config(materialized='table') }}

with oficinas as (
    select * from {{ ref('stg_oficinas') }}
),

final as (
    select
        row_number() over (order by oficina_id) as dofic_id,
        oficina_id,
        nom_oficina,
        departamento,
        region,
        zona
    from oficinas
)

select * from final
