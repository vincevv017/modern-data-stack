{{ config(materialized='table') }}

WITH enriched_orders AS (
    SELECT * FROM {{ ref('int_orders_enriched') }}
),

behavior_orders AS (
    SELECT * FROM {{ ref('int_orders_with_behavior') }}
)

SELECT
    COALESCE(e.order_id, b.order_id) as order_id,
    COALESCE(e.customer_id, b.customer_id) as customer_id,
    COALESCE(e.order_date, b.order_date) as order_date,
    COALESCE(e.amount, b.amount) as revenue,
    COALESCE(e.product_name, b.product_name) as product_name,
    COALESCE(e.category, b.category) as product_category,
    COALESCE(e.supplier_name, b.supplier_name) as supplier_name,
    COALESCE(e.country, b.country) as supplier_country,
    COALESCE(e.sustainability_score, b.sustainability_score) as sustainability_score,
    EXTRACT(YEAR FROM COALESCE(e.order_date, b.order_date)) as order_year,
    EXTRACT(MONTH FROM COALESCE(e.order_date, b.order_date)) as order_month,
    EXTRACT(QUARTER FROM COALESCE(e.order_date, b.order_date)) as order_quarter,
    -- Since we removed user events, set these to 0 for now
    0 as customer_page_views,
    0 as customer_cart_adds,
    0 as customer_purchases

FROM enriched_orders e
FULL OUTER JOIN behavior_orders b ON e.order_id = b.order_id
