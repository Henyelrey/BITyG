with raw_oficinas as (
    select * from {{ source('airbyte_raw', 'oficinas') }}
),

final as (
    select
        oficina_id,
        nom_oficina,
        departamento,
        region,
        zona
    from raw_oficinas
)

select * from final
