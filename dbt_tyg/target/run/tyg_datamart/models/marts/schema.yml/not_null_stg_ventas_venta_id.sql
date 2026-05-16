select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select venta_id
from "tyg_datamart"."marts_staging"."stg_ventas"
where venta_id is null



      
    ) dbt_internal_test