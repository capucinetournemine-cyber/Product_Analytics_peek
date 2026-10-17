------------
-- Task A1
-----------

WITH
order_item AS (SELECT * FROM `bigquery-public-data.thelook_ecommerce.order_items`),
orders  AS (SELECT * FROM `bigquery-public-data.thelook_ecommerce.orders`),
products  AS (SELECT * FROM `bigquery-public-data.thelook_ecommerce.products`),
users  AS (SELECT * FROM `bigquery-public-data.thelook_ecommerce.users`),
events AS (SELECT * FROM `bigquery-public-data.thelook_ecommerce.events`),

raw_checks AS (
  SELECT 'delivered_before_shipped' AS check_name, COUNTIF(delivered_at < shipped_at) AS failed_rows,  COUNT(*) AS total_rows
  FROM order_item
  WHERE delivered_at IS NOT NULL AND shipped_at IS NOT NULL

  UNION ALL
  SELECT 'shipped_before_created' AS check_name, COUNTIF(shipped_at < created_at) AS failed_row, COUNT(*) AS total_rows
  FROM order_item
  WHERE shipped_at IS NOT NULL AND created_at IS NOT NULL

  UNION ALL
  SELECT 'returned_before_delivered' AS check_name, COUNTIF(returned_at < delivered_at) AS failed_row, COUNT(*) AS total_rows
  FROM order_item
  WHERE returned_at IS NOT NULL AND delivered_at IS NOT NULL

  UNION ALL
  SELECT 'future_dated_orders' AS check_name, COUNTIF(created_at > CURRENT_TIMESTAMP()) as failed_row, COUNT(*) as total_rows
  FROM order_item

  UNION ALL
  SELECT 'complete_without_delivered_date' AS check_name, COUNTIF(delivered_at IS NULL) AS failed_row, COUNT(*) AS total_rows
  FROM order_item
  WHERE status = 'Complete'

  UNION ALL
  SELECT 'returned_without_returned_date' AS check_name, COUNTIF(returned_at IS NULL) AS failed_row, COUNT(*) AS total_rows
  FROM order_item
  WHERE status = 'Returned'

  UNION ALL 
  SELECT 'different_status' AS check_name, COUNTIF(orders.status != order_item.status) AS failed_row, COUNT(*) AS total_rows
  FROM order_item JOIN orders ON (orders.order_id = order_item.order_id)

  UNION ALL
  SELECT 'events_before_user_signup', COUNTIF(events.created_at < users.created_at)AS failed_row, COUNT(*) AS total_rows
  FROM events JOIN users ON users.id = events.user_id 
  WHERE events.user_id IS NOT NULL

  UNION ALL
  SELECT 'item_without_order' AS check_name, COUNTIF(order_id IS NULL) AS failed_row, COUNT(*) AS total_rows
  FROM order_item

  UNION ALL
  SELECT 'item_without_product' AS check_name, COUNTIF(product_id IS NULL) AS failed_row, COUNT(*) AS total_rows
  FROM order_item

  UNION ALL
  SELECT 'item_without_user' AS check_name, COUNTIF(user_id IS NULL) AS failed_row, COUNT(*) AS total_rows
  FROM order_item

  UNION ALL
  SELECT 'cost_neg_null' AS check_name, COUNTIF (cost IS NULL OR cost <= 0) AS failed_row, COUNT(*) AS total_rows
  FROM products

  UNION ALL
  SELECT 'price_neg_null' AS check_name, COUNTIF (sale_price IS NULL OR sale_price <= 0) AS failed_row, COUNT(*) AS total_rows
  FROM order_item

  UNION ALL
  SELECT 'item_sold_below_cost', COUNTIF(order_item.sale_price < products.cost), COUNT(*)
  FROM order_item JOIN products ON products.id = order_item.product_id

  UNION ALL 
  SELECT 'duplicate_orders' AS check_name, (COUNT(*) - COUNT(distinct order_id)) as failed_row, COUNT(*) AS total_rows
  FROM orders

  UNION ALL 
  SELECT 'duplicate_item_orders' AS check_name, (COUNT(*) - COUNT(distinct id)) as failed_row, COUNT(*) AS total_rows
  FROM order_item

  UNION ALL 
  SELECT 'duplicate_events' AS check_name, (COUNT(*) - COUNT(distinct id)) as failed_row, COUNT(*) AS total_rows
  FROM events

  UNION ALL
  SELECT 'order_num_of_item_mismatch', COUNTIF(orders.num_of_item != count.n_items) as failed_rows, COUNT(*) as total_rows
  FROM orders JOIN (
    SELECT order_id, COUNT(*) AS n_items 
    FROM order_item 
    GROUP BY order_id) 
    count USING (order_id)
  )
  SELECT check_name, failed_rows, total_rows, ROUND(SAFE_DIVIDE(failed_rows, total_rows) * 100, 3) AS pct_failed
  FROM raw_checks
  ORDER BY pct_failed DESC;
