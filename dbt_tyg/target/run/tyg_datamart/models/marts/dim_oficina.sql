
      
        
            delete from "tyg_datamart"."marts_marts"."dim_oficina"
            where (
                dofic_id) in (
                select (dofic_id)
                from "dim_oficina__dbt_tmp060259906938"
            );

        
    

    insert into "tyg_datamart"."marts_marts"."dim_oficina" ("dofic_id", "oficina_id", "nom_oficina", "departamento", "region", "zona", "updated_at")
    (
        select "dofic_id", "oficina_id", "nom_oficina", "departamento", "region", "zona", "updated_at"
        from "dim_oficina__dbt_tmp060259906938"
    )
  