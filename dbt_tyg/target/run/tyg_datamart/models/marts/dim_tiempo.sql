
      
        
            delete from "tyg_datamart"."marts_marts"."dim_tiempo"
            where (
                dtiem_id) in (
                select (dtiem_id)
                from "dim_tiempo__dbt_tmp055753269283"
            );

        
    

    insert into "tyg_datamart"."marts_marts"."dim_tiempo" ("dtiem_id", "fecha", "dia", "semana", "mes", "nombre_mes", "trimestre", "anio", "fecha_recepcion", "fecha_venta")
    (
        select "dtiem_id", "fecha", "dia", "semana", "mes", "nombre_mes", "trimestre", "anio", "fecha_recepcion", "fecha_venta"
        from "dim_tiempo__dbt_tmp055753269283"
    )
  