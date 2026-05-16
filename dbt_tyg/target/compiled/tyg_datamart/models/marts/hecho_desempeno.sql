-- =============================================================
-- hecho_desempeno.sql — Desempeño de Asesores / PDV
-- KPI P3-2 Cumplimiento Meta | P3-3 Kits x Asesor % Inactivos
-- Grano: mes × oficina × asesor_o_pdv
-- =============================================================


WITH ventas_asesor AS (
    SELECT
        DATE_TRUNC('month', v.fecha_venta)         AS mes_venta,
        v.oficina_id,
        COALESCE(v.vendedor_id, v.asesor_pdv_id)   AS persona_id,
        v.canal_venta,
        COUNT(*)                                    AS kits_totales,
        SUM(COALESCE(a.flag_activo::INT, 0))        AS kits_activos
    FROM "tyg_datamart"."raw"."ventas" v
    LEFT JOIN "tyg_datamart"."raw"."activaciones" a ON v.venta_id = a.venta_id

    
    WHERE v.fecha_venta >= (
        SELECT DATE_TRUNC('month', COALESCE(MAX(_dbt_updated_at), '2000-01-01'))
        FROM "tyg_datamart"."marts_marts"."hecho_desempeno"
    )
    

    GROUP BY 1, 2, 3, 4
),

metas_mes AS (
    SELECT
        MAKE_DATE(anio, mes_num, 1)  AS mes_meta,
        oficina_id,
        vendedor_id,
        meta_kits
    FROM "tyg_datamart"."raw"."metas"
)

SELECT
    TO_CHAR(va.mes_venta, 'YYYYMMDD')::INT                          AS dtiem_id,
    va.oficina_id                                                    AS dofic_id,
    va.persona_id                                                    AS dases_id,

    va.kits_totales                                                  AS kits_por_asesor,
    va.kits_activos                                                  AS kits_activos_asesor,
    (va.kits_totales - va.kits_activos)                              AS kits_inactivos_asesor,

    COALESCE(m.meta_kits, 0)                                        AS meta_kits_mes,

    -- KPI P3-2: Cumplimiento de meta
    ROUND(
        va.kits_totales::NUMERIC / NULLIF(m.meta_kits, 0) * 100
    , 2)                                                             AS cumplimiento_meta_pct,

    -- KPI P3-3: % kits inactivos del asesor
    ROUND(
        (va.kits_totales - va.kits_activos)::NUMERIC
        / NULLIF(va.kits_totales, 0) * 100
    , 2)                                                             AS kits_inactivos_pct,

    NOW()                                                            AS _dbt_updated_at

FROM ventas_asesor va
LEFT JOIN metas_mes m
    ON va.mes_venta   = m.mes_meta
   AND va.oficina_id  = m.oficina_id
   AND va.persona_id  = m.vendedor_id