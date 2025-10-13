{{ config(materialized='table') }}

WITH orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
),

products AS (
    SELECT * FROM {{ ref('stg_products') }}
),

suppliers AS (
    SELECT * FROM {{ ref('stg_suppliers') }}
)

SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    o.amount,
    p.product_name,
    p.category,
    s.supplier_name,
    s.country,
    s.sustainability_score

FROM orders o
LEFT JOIN products p ON o.product_id = p.product_id
LEFT JOIN suppliers s ON p.supplier_id = s.supplier_id
