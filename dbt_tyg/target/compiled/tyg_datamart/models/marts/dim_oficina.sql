

WITH source_data AS (
    SELECT
        oficina_id,
        nom_oficina,
        departamento,
        region,
        zona,
        updated_at
    FROM "tyg_datamart"."raw"."oficinas"
    
    
    WHERE updated_at > (
        SELECT COALESCE(MAX(updated_at), '2000-01-01'::TIMESTAMP)
        FROM "tyg_datamart"."marts_marts"."dim_oficina"
    )
    
)

SELECT
    ROW_NUMBER() OVER (ORDER BY oficina_id) AS dofic_id,
    oficina_id,
    nom_oficina,
    departamento,
    region,
    zona,
    updated_at
FROM source_data