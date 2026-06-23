with raw_asesores as (
    select * from {{ source('airbyte_raw', 'asesores') }}
),

final as (
    select
        asesor_pdv_id,
        nom_asesor_pdv,
        'PDV'   as tipo_canal,
        160.00  as monto_asociado
    from raw_asesores
)

select * from final
