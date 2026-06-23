with raw_productos as (
    select * from {{ source('airbyte_raw', 'productos') }}
),

final as (
    select
        producto_id,
        serie,
        descripcion,   -- la columna real es descripcion, no nombre_producto
        precio_base,
        activo
    from raw_productos
)

select * from final
