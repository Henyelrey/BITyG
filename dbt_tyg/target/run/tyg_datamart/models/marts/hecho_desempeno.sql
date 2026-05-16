
      
        
            delete from "tyg_datamart"."marts_marts"."hecho_desempeno"
            using "hecho_desempeno__dbt_tmp054739580160"
            where (
                
                    "hecho_desempeno__dbt_tmp054739580160".dtiem_id = "tyg_datamart"."marts_marts"."hecho_desempeno".dtiem_id
                    and 
                
                    "hecho_desempeno__dbt_tmp054739580160".dofic_id = "tyg_datamart"."marts_marts"."hecho_desempeno".dofic_id
                    and 
                
                    "hecho_desempeno__dbt_tmp054739580160".dases_id = "tyg_datamart"."marts_marts"."hecho_desempeno".dases_id
                    
                
                
            );
        
    

    insert into "tyg_datamart"."marts_marts"."hecho_desempeno" ("dtiem_id", "dofic_id", "dases_id", "kits_por_asesor", "kits_activos_asesor", "kits_inactivos_asesor", "meta_kits_mes", "cumplimiento_meta_pct", "kits_inactivos_pct", "_dbt_updated_at")
    (
        select "dtiem_id", "dofic_id", "dases_id", "kits_por_asesor", "kits_activos_asesor", "kits_inactivos_asesor", "meta_kits_mes", "cumplimiento_meta_pct", "kits_inactivos_pct", "_dbt_updated_at"
        from "hecho_desempeno__dbt_tmp054739580160"
    )
  