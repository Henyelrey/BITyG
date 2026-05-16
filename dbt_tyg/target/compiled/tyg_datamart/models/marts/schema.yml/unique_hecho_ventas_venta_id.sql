
    
    

select
    venta_id as unique_field,
    count(*) as n_records

from "tyg_datamart"."marts_marts"."hecho_ventas"
where venta_id is not null
group by venta_id
having count(*) > 1


