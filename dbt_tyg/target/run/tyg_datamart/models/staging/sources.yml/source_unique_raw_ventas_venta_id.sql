select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    venta_id as unique_field,
    count(*) as n_records

from "tyg_datamart"."raw"."ventas"
where venta_id is not null
group by venta_id
having count(*) > 1



      
    ) dbt_internal_test