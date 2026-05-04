with raw_activaciones as (
    select * from {{ source('airbyte_raw', 'activaciones') }}
),

final as (
    select
        activacion_id,
        venta_id,
        fecha_activacion,
        -- flag_activo es boolean en Postgres, lo casteamos a integer (1/0)
        case when flag_activo = true then 1 else 0 end as flag_activo
    from raw_activaciones
)

select * from final
