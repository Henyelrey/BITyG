
      
        
            delete from "tyg_datamart"."marts_marts"."hecho_canal"
            using "hecho_canal__dbt_tmp054739558377"
            where (
                
                    "hecho_canal__dbt_tmp054739558377".dtiem_id = "tyg_datamart"."marts_marts"."hecho_canal".dtiem_id
                    and 
                
                    "hecho_canal__dbt_tmp054739558377".dofic_id = "tyg_datamart"."marts_marts"."hecho_canal".dofic_id
                    
                
                
            );
        
    

    insert into "tyg_datamart"."marts_marts"."hecho_canal" ("dtiem_id", "dofic_id", "kits_canal_directo", "kits_canal_pdv", "ingresos_directo", "ingresos_pdv", "mix_canal_pct", "_dbt_updated_at")
    (
        select "dtiem_id", "dofic_id", "kits_canal_directo", "kits_canal_pdv", "ingresos_directo", "ingresos_pdv", "mix_canal_pct", "_dbt_updated_at"
        from "hecho_canal__dbt_tmp054739558377"
    )
  