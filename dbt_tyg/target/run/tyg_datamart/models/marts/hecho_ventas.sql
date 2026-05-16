
      
        
            delete from "tyg_datamart"."marts_marts"."hecho_ventas"
            where (
                venta_id) in (
                select (venta_id)
                from "hecho_ventas__dbt_tmp054739810310"
            );

        
    

    insert into "tyg_datamart"."marts_marts"."hecho_ventas" ("venta_id", "dtiem_id", "dofic_id", "dest_id", "kits_vendidos", "kits_activos", "ingresos_s", "tasa_activacion_pct", "contribucion_pct", "serie", "canal_venta", "_dbt_updated_at")
    (
        select "venta_id", "dtiem_id", "dofic_id", "dest_id", "kits_vendidos", "kits_activos", "ingresos_s", "tasa_activacion_pct", "contribucion_pct", "serie", "canal_venta", "_dbt_updated_at"
        from "hecho_ventas__dbt_tmp054739810310"
    )
  