select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select recepcion_id
from "tyg_datamart"."raw"."recepciones"
where recepcion_id is null



      
    ) dbt_internal_test