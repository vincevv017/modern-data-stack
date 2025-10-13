
  
    

    create table "postgres"."analytics_staging"."stg_products__dbt_tmp"
      
      
    as (
      SELECT
    id as product_id,
    product_name,
    category,
    price,
    supplier_id
FROM mysql.catalog_db.products
    );

  