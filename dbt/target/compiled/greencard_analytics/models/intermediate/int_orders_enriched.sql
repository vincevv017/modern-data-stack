-- Federation query: Join PostgreSQL orders with MySQL products/suppliers


WITH orders AS (
    SELECT * FROM "postgres"."analytics_staging"."stg_orders"
),

products AS (
    SELECT * FROM "postgres"."analytics_staging"."stg_products"
),

suppliers AS (
    SELECT * FROM "postgres"."analytics_staging"."stg_suppliers"
)

SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    o.amount,
    
    p.product_name,
    p.category,
    p.price,
    
    s.supplier_name,
    s.country,
    s.region,
    s.sustainability_score,
    
    CASE 
        WHEN o.amount >= 500 THEN CAST('High Value' AS VARCHAR)
        WHEN o.amount >= 100 THEN CAST('Medium Value' AS VARCHAR)
        ELSE CAST('Low Value' AS VARCHAR)
    END AS order_value_tier,
    
    CASE
        WHEN s.sustainability_score >= 80 THEN CAST('Excellent' AS VARCHAR)
        WHEN s.sustainability_score >= 60 THEN CAST('Good' AS VARCHAR)
        ELSE CAST('Fair' AS VARCHAR)
    END AS sustainability_tier

FROM orders o
LEFT JOIN products p ON o.product_id = p.product_id
LEFT JOIN suppliers s ON p.supplier_id = s.supplier_id