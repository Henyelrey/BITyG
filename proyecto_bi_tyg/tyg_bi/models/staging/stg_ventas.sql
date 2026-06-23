with raw_ventas as (
    select * from {{ source('airbyte_raw', 'ventas') }}
),

final as (
    select
        venta_id,
        oficina_id,
        producto_id,
        vendedor_id,
        asesor_pdv_id,
        canal_venta,
        fecha_venta,
        recepcion_id,
        monto_venta as monto_original,

        -- KPI P1-2 / P3-1: Monto según canal de venta
        case
            when canal_venta = 'DIRECTO' then 220.00
            when canal_venta = 'PDV'     then 160.00
            else monto_venta
        end as monto_calculado

    from raw_ventas
)

select * from final
