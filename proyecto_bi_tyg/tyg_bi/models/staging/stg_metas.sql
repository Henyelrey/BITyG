with raw_metas as (
    select * from {{ source('airbyte_raw', 'metas') }}
),

final as (
    select
        oficina_id,
        anio,
        mes_num,
        meta_kits,
        -- Construir fecha del primer día del mes para join con dim_tiempo
        (anio::text || '-' || lpad(mes_num::text, 2, '0') || '-01')::date as fecha_mes
    from raw_metas
)

select * from final
