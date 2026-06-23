/*
    dim_asesor_pdv — Jerarquía: Tipo_canal → Asesor
    Unifica vendedores DIRECTO (S/220) y asesores PDV (S/160).
    Clave surrogate: dases_id (generada con row_number)
*/
{{ config(materialized='table') }}

-- Canal DIRECTO: vendedores internos
with vendedores as (
    select
        vendedor_id     as origen_id,
        nom_vendedor    as nom_cliente_pdv,
        tipo_canal,
        monto_asociado
    from {{ ref('stg_vendedores') }}
),

-- Canal PDV: asesores externos
asesores as (
    select
        asesor_pdv_id   as origen_id,
        nom_asesor_pdv  as nom_cliente_pdv,
        tipo_canal,
        monto_asociado
    from {{ ref('stg_asesores') }}
),

-- Union de ambos canales
todos as (
    select * from vendedores
    union all
    select * from asesores
),

final as (
    select
        row_number() over (
            order by tipo_canal, origen_id
        )               as dases_id,
        origen_id,
        nom_cliente_pdv,
        tipo_canal,
        monto_asociado
    from todos
)

select * from final
