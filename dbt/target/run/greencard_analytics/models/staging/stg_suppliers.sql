
  
    

    create table "postgres"."analytics_staging"."stg_suppliers__dbt_tmp"
      
      
    as (
      SELECT
    id as supplier_id,
    supplier_name,
    country,
    region,
    sustainability_score
FROM mysql.catalog_db.suppliers
    );

  