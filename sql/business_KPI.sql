-------------------------------------------
-- Declaration of param
-------------------------------------------
DECLARE as_of_date DATE DEFAULT (
  SELECT LEAST(
    (SELECT MAX(DATE(created_at)) FROM `bigquery-public-data.thelook_ecommerce.order_items` WHERE created_at <= CURRENT_TIMESTAMP()),
    (SELECT MAX(DATE(created_at)) FROM `bigquery-public-data.thelook_ecommerce.events`      WHERE created_at <= CURRENT_TIMESTAMP()),
    CURRENT_DATE())
);

------------------------------------------
-- Task A2 : 
-- Creation of reusable base model : completed_order_item
------------------------------------------

CREATE TEMP TABLE completed_order_items AS
-- Define date range 
WITH params AS (
  SELECT
    DATE '2000-01-01' AS start_date,
    DATE '2099-01-01' AS end_date
),

-- Keeping only complete month
months AS (
  SELECT month_start
  FROM params, 
  UNNEST(
    GENERATE_DATE_ARRAY(
      DATE_TRUNC(start_date, MONTH),
      DATE_TRUNC(end_date, MONTH),
      INTERVAL 1 MONTH
    )
  ) AS month_start
  WHERE month_start >= start_date
    AND LAST_DAY(month_start) <= end_date
    AND month_start < DATE_TRUNC(CURRENT_DATE(), MONTH)
)

-- Creation of Completed order items
SELECT
  order_item.id AS order_item_id, 
  order_item.order_id, 
  order_item.user_id, 
  order_item.product_id, 
  order_item.created_at AS ordered_at, 
  DATE(order_item.created_at) AS order_date, 
  DATE_TRUNC(DATE(order_item.created_at), MONTH) AS order_month,
  order_item.sale_price AS revenue,
  products.cost AS cost,
  order_item.sale_price - products.cost AS gross_profit,
  orders.num_of_item,
  products.brand, 
  users.traffic_source
FROM `bigquery-public-data.thelook_ecommerce.order_items` order_item
JOIN `bigquery-public-data.thelook_ecommerce.orders` orders ON orders.order_id = order_item.order_id
JOIN `bigquery-public-data.thelook_ecommerce.products` products ON products.id = order_item.product_id
JOIN `bigquery-public-data.thelook_ecommerce.users` users ON users.id = order_item.user_id
JOIN months ON DATE_TRUNC(DATE(order_item.created_at), MONTH) = months.month_start
WHERE order_item.status = 'Complete'
;

-----------
-- Task A3 
-----------
CREATE TEMP TABLE business_health AS

-- Events filtered to keep 'purchase' and department per month
WITH session_filtered AS(
  SELECT DATE_TRUNC(DATE(events.created_at), MONTH) as month,
  ROUND(COUNTIF(event_type = 'purchase')/COUNTIF(event_type = 'department'),3) * 100 as session_conversion_rate
  FROM `bigquery-public-data.thelook_ecommerce.events` events
  GROUP BY month
),

-- Calcul of basic KPI with completed order item
basic_business_metrics AS (
  SELECT
  order_month AS month,
  ROUND(SUM(revenue)) AS revenue,
  SUM(gross_profit) AS gross_profit,
  COUNT(DISTINCT order_id) AS orders,
  COUNT(DISTINCT order_item_id) AS units,
FROM `cool-subset-493209-p4.thelook.completed_order_items`
GROUP BY order_month
ORDER BY order_month ASC
)

-- Join all data to create KPI table
SELECT b.month, revenue, gross_profit, orders, units, 
  ROUND(gross_profit/revenue,3)*100 as gross_margin_pct, 
  ROUND(revenue/orders,1) as aov, 
  ROUND((revenue - LAG(revenue) OVER (ORDER BY b.month))/ LAG(revenue) OVER (ORDER BY b.month),3) * 100 as mom,
  session_conversion_rate
FROM basic_business_metrics b
JOIN session_filtered s ON s.month = b.month ;

--------------
--Task B
--------------

CREATE TEMP TABLE user_months AS
WITH first_order AS (
  SELECT user_id, MIN(DATE_TRUNC(DATE(created_at), MONTH)) AS first_month
  FROM `bigquery-public-data.thelook_ecommerce.order_items`
  GROUP BY user_id
)
SELECT
  c.user_id,
  c.order_month   AS month,
  f.first_month,
  SUM(c.revenue)  AS revenue,
  COUNT(c.order_id) as num_orders
FROM `cool-subset-493209-p4.thelook.completed_order_items` c
JOIN first_order f ON c.user_id = f.user_id
GROUP BY c.user_id, c.order_month, f.first_month
;

CREATE TEMP TABLE new_vs_returning AS
SELECT
  month,
  COUNT(*) AS active_customers,
  COUNTIF(month = first_month) AS new_customers,
  COUNTIF(month > first_month) AS returning_customers,
  ROUND(SUM(IF(month = first_month, revenue, 0)), 2) AS revenue_new,
  ROUND(SUM(IF(month > first_month, revenue, 0)), 2) AS revenue_returning,
  ROUND(SAFE_DIVIDE(SUM(IF(month > first_month, revenue, 0)), SUM(revenue)) * 100, 2) AS pct_revenue_from_returning
FROM user_months
GROUP BY month
ORDER BY month;

---------
--B2 
---------
CREATE TEMP TABLE new_vs_returning AS

WITH order_days AS (
  SELECT DISTINCT user_id, order_date 
  FROM `cool-subset-493209-p4.thelook.completed_order_items`
),

flags AS (
  SELECT
    user_months.user_id,
    user_months.month,
    COUNTIF(order_days.order_date IS NOT NULL) > 0 AS came_back_90d
  FROM user_months 
  LEFT JOIN order_days 
    ON  order_days.user_id = user_months.user_id
    AND order_days.order_date >  LAST_DAY(user_months.month, MONTH)
    AND order_days.order_date <= DATE_ADD(LAST_DAY(user_months.month, MONTH), INTERVAL 90 DAY)
  GROUP BY user_months.user_id, user_months.month
),
monthly AS (
  SELECT
    month,
    COUNT(*) AS active_customers,
    COUNTIF(NOT came_back_90d) AS churned_raw,
    DATE_ADD(LAST_DAY(month, MONTH), INTERVAL 90 DAY) AS window_closes_on
  FROM flags
  GROUP BY month
)
SELECT
  m.month,
  m.active_customers,
  m.window_closes_on,
  (m.window_closes_on <= as_of_date) AS is_mature,
  IF(m.window_closes_on <= as_of_date, m.churned_raw, NULL) AS churned_customers_90d,
  IF(m.window_closes_on <= as_of_date, ROUND(m.churned_raw/m.active_customers * 100, 2), NULL) AS churn_rate_90d_pct,
  nr.revenue_new,
  nr.revenue_returning
FROM monthly m
JOIN new_vs_returning nr ON nr.month = m.month
ORDER BY m.month;
