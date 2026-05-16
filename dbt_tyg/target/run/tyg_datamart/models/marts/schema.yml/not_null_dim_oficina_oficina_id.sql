select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select oficina_id
from "tyg_datamart"."marts_marts"."dim_oficina"
where oficina_id is null



      
    ) dbt_internal_test