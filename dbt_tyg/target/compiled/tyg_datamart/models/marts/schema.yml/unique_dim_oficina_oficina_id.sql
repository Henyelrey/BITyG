
    
    

select
    oficina_id as unique_field,
    count(*) as n_records

from "tyg_datamart"."marts_marts"."dim_oficina"
where oficina_id is not null
group by oficina_id
having count(*) > 1


