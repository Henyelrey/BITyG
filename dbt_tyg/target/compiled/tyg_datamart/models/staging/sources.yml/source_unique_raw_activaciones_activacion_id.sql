
    
    

select
    activacion_id as unique_field,
    count(*) as n_records

from "tyg_datamart"."raw"."activaciones"
where activacion_id is not null
group by activacion_id
having count(*) > 1


