select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select fecha_venta
from "tyg_datamart"."raw"."ventas"
where fecha_venta is null



      
    ) dbt_internal_test