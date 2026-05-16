
    
    

select
    venta_id as unique_field,
    count(*) as n_records

from "tyg_datamart"."raw"."ventas"
where venta_id is not null
group by venta_id
having count(*) > 1


