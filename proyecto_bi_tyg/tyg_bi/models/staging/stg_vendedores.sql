with raw_vendedores as (
    select * from {{ source('airbyte_raw', 'vendedores') }}
),

final as (
    select
        vendedor_id,
        nom_vendedor,
        'DIRECTO'  as tipo_canal,
        220.00     as monto_asociado
    from raw_vendedores
)

select * from final
