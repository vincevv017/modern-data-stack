SELECT
    order_id,
    customer_id,
    product_id,
    order_date,
    amount,
    status
FROM postgres.public.orders
WHERE amount > 0
    AND status = 'completed'