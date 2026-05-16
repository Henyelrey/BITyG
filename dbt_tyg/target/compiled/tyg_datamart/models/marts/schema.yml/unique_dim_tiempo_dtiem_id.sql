
    
    

select
    dtiem_id as unique_field,
    count(*) as n_records

from "tyg_datamart"."marts_marts"."dim_tiempo"
where dtiem_id is not null
group by dtiem_id
having count(*) > 1


