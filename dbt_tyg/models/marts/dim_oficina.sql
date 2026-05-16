{{
    config(
        materialized='incremental',
        unique_key='dofic_id',
        schema='marts'
    )
}}

WITH source_data AS (
    SELECT
        oficina_id,
        nom_oficina,
        departamento,
        region,
        zona,
        updated_at
    FROM {{ source('raw', 'oficinas') }}
    
    {% if is_incremental() %}
    WHERE updated_at > (
        SELECT COALESCE(MAX(updated_at), '2000-01-01'::TIMESTAMP)
        FROM {{ this }}
    )
    {% endif %}
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