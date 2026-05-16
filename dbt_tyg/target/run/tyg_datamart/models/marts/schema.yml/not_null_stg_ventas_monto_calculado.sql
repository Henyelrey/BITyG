select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select monto_calculado
from "tyg_datamart"."marts_staging"."stg_ventas"
where monto_calculado is null



      
    ) dbt_internal_test