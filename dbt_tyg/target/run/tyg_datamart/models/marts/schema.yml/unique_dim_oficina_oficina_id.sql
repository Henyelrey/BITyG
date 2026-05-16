select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    oficina_id as unique_field,
    count(*) as n_records

from "tyg_datamart"."marts_marts"."dim_oficina"
where oficina_id is not null
group by oficina_id
having count(*) > 1



      
    ) dbt_internal_test