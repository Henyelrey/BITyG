select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select dofic_id
from "tyg_datamart"."marts_marts"."hecho_canal"
where dofic_id is null



      
    ) dbt_internal_test