select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select dtiem_id
from "tyg_datamart"."marts_marts"."dim_tiempo"
where dtiem_id is null



      
    ) dbt_internal_test