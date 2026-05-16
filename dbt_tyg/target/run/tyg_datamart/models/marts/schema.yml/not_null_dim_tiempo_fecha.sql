select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select fecha
from "tyg_datamart"."marts_marts"."dim_tiempo"
where fecha is null



      
    ) dbt_internal_test