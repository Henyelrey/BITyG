/*
    fact_desempeno — P3b: Desempeño de Asesores y PDV
    Granularidad: una fila por mes × oficina × asesor individual
    KPI P3-2: Cumplimiento de Meta | P3-3: Kits x Asesor / % Inactivos
*/
{{ config(materialized='table') }}

with ventas as (
    select * from {{ ref('stg_ventas') }}
),

activaciones as (
    select * from {{ ref('stg_activaciones') }}
),

metas as (
    select * from {{ ref('stg_metas') }}
),

dim_tiempo as (
    select * from {{ ref('dim_tiempo') }}
),

dim_oficina as (
    select * from {{ ref('dim_oficina') }}
),

dim_asesor_pdv as (
    select * from {{ ref('dim_asesor_pdv') }}
),

-- Ventas con activacion y agrupacion mensual
ventas_con_activacion as (
    select
        v.oficina_id,
        v.vendedor_id,
        v.asesor_pdv_id,
        v.canal_venta,
        date_trunc('month', v.fecha_venta)::date    as fecha_mes,
        extract(year  from v.fecha_venta)::int      as anio,
        extract(month from v.fecha_venta)::int      as mes_num,
        coalesce(a.flag_activo, 0)                  as es_activacion
    from ventas v
    left join activaciones a on v.venta_id = a.venta_id
),

-- Agregar por mes × oficina × asesor
agregado as (
    select
        fecha_mes,
        anio,
        mes_num,
        oficina_id,
        vendedor_id,
        asesor_pdv_id,

        count(*)                                    as kits_por_asesor,
        sum(es_activacion)                          as kits_activos_asesor,
        sum(1 - es_activacion)                      as kits_inactivos_asesor

    from ventas_con_activacion
    group by fecha_mes, anio, mes_num, oficina_id, vendedor_id, asesor_pdv_id
),

-- Unir con metas del mes por oficina
con_metas as (
    select
        a.*,
        coalesce(m.meta_kits, 0)                   as meta_kits_mes
    from agregado a
    left join metas m
        on  a.oficina_id = m.oficina_id
        and a.anio       = m.anio
        and a.mes_num    = m.mes_num
),

final as (
    select
        -- Claves surrogate de dimensiones
        t.dtiem_id,
        o.dofic_id,

        -- Resolución de DAses_id: DIRECTO usa vendedor_id, PDV usa asesor_pdv_id
        coalesce(
            da_dir.dases_id,
            da_pdv.dases_id
        )                                           as dases_id,

        -- Medidas P3b
        cm.kits_por_asesor,
        cm.kits_activos_asesor,
        cm.kits_inactivos_asesor,
        cm.meta_kits_mes,

        -- KPI P3-2: Cumplimiento de meta (%)
        round(
            cm.kits_activos_asesor::numeric
            / nullif(cm.meta_kits_mes, 0) * 100,
            2
        )                                           as cumplimiento_meta_pct,

        -- KPI P3-3: % kits inactivos por asesor
        round(
            cm.kits_inactivos_asesor::numeric
            / nullif(cm.kits_por_asesor, 0) * 100,
            2
        )                                           as kits_inactivos_pct

    from con_metas cm
    -- Join con dimensiones
    left join dim_tiempo  t
        on cast(to_char(cm.fecha_mes, 'YYYYMMDD') as integer) = t.dtiem_id
    left join dim_oficina o
        on cm.oficina_id = o.oficina_id
    -- Resolver DAses_id según canal
    left join dim_asesor_pdv da_dir
        on da_dir.origen_id  = cm.vendedor_id
       and da_dir.tipo_canal = 'DIRECTO'
    left join dim_asesor_pdv da_pdv
        on da_pdv.origen_id  = cm.asesor_pdv_id
       and da_pdv.tipo_canal = 'PDV'
)

select * from final
