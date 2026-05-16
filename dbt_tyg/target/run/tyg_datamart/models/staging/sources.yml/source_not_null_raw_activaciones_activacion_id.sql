select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select activacion_id
from "tyg_datamart"."raw"."activaciones"
where activacion_id is null



      
    ) dbt_internal_test