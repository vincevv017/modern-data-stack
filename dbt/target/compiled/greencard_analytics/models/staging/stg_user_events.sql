SELECT
    event_id,
    user_id as customer_id,
    event_type,
    product_id,
    session_id
FROM lakehouse.raw_data.user_events