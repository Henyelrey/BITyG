with raw_recepciones as (
    select * from {{ source('airbyte_raw', 'recepciones') }}
),

final as (
    select
        recepcion_id,
        oficina_id,
        producto_id,
        fecha_recepcion,
        estado_recepcion,
        coalesce(dias_inactivo, 0) as dias_inactivo,

        -- KPI P2-1: Flag de riesgo inventario (> 90 días sin vender)
        case
            when dias_inactivo > 90
             and estado_recepcion <> 'VENDIDO' then true
            else false
        end as flag_riesgo_90d

    from raw_recepciones
)

select * from final
