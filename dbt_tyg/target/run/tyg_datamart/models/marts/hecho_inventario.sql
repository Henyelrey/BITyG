
      -- back compat for old kwarg name
  
  
        
            
            
        
    

    

    merge into "tyg_datamart"."marts_marts"."hecho_inventario" as DBT_INTERNAL_DEST
        using "hecho_inventario__dbt_tmp054739726299" as DBT_INTERNAL_SOURCE
        on (
                DBT_INTERNAL_SOURCE.recepcion_id = DBT_INTERNAL_DEST.recepcion_id
            )

    
    when matched then update set
        "recepcion_id" = DBT_INTERNAL_SOURCE."recepcion_id","dtiem_id" = DBT_INTERNAL_SOURCE."dtiem_id","dofic_id" = DBT_INTERNAL_SOURCE."dofic_id","dest_id" = DBT_INTERNAL_SOURCE."dest_id","dias_inactivo" = DBT_INTERNAL_SOURCE."dias_inactivo","kits_riesgo_90d" = DBT_INTERNAL_SOURCE."kits_riesgo_90d","rotation_lote" = DBT_INTERNAL_SOURCE."rotation_lote","serie" = DBT_INTERNAL_SOURCE."serie","_dbt_updated_at" = DBT_INTERNAL_SOURCE."_dbt_updated_at"
    

    when not matched then insert
        ("recepcion_id", "dtiem_id", "dofic_id", "dest_id", "dias_inactivo", "kits_riesgo_90d", "rotation_lote", "serie", "_dbt_updated_at")
    values
        ("recepcion_id", "dtiem_id", "dofic_id", "dest_id", "dias_inactivo", "kits_riesgo_90d", "rotation_lote", "serie", "_dbt_updated_at")


  