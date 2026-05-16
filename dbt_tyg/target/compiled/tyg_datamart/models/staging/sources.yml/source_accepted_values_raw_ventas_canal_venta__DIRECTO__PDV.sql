
    
    

with all_values as (

    select
        canal_venta as value_field,
        count(*) as n_records

    from "tyg_datamart"."raw"."ventas"
    group by canal_venta

)

select *
from all_values
where value_field not in (
    'DIRECTO','PDV'
)


