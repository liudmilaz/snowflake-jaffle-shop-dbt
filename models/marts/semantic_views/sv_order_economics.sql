-- Semantic view for testing non-additive ratio metrics across three tables:
-- dim_customers -> fct_orders -> fct_order_adjustments.
--
-- true_avg_order_value is the one to watch: it folds fct_order_adjustments'
-- late-arriving-payment corrections (see that model's header) into the
-- ratio, so it only comes out correct if the semantic view recomputes the
-- division at query time rather than pre-aggregating and summing/averaging
-- the metric column across grains.

{{ config(materialized='semantic_view') }}

TABLES(
  customers AS {{ ref('dim_customers') }} PRIMARY KEY (customer_id),
  orders AS {{ ref('fct_orders') }} PRIMARY KEY (order_id),
  adjustments AS {{ ref('fct_order_adjustments') }} PRIMARY KEY (adjustment_id)
)

RELATIONSHIPS(
  orders_to_customer AS orders (customer_id) REFERENCES customers (customer_id),
  adjustments_to_order AS adjustments (order_id) REFERENCES orders (order_id)
)

FACTS(
  orders.order_amount AS orders.amount,
  adjustments.adjustment_amount AS adjustments.amount_delta
)

DIMENSIONS(
  customers.customer_name AS customers.first_name || ' ' || customers.last_name,
  orders.order_status AS orders.status,
  orders.order_month AS date_trunc('month', orders.order_date),
  adjustments.reason AS adjustments.reason
)

METRICS(
  orders.total_orders AS COUNT(DISTINCT orders.order_id),
  orders.total_revenue AS SUM(orders.order_amount),
  adjustments.total_adjustments AS SUM(adjustments.adjustment_amount),
  customers.total_customers AS COUNT(DISTINCT customers.customer_id),
  avg_order_value AS orders.total_revenue / orders.total_orders,
  true_avg_order_value AS (orders.total_revenue + adjustments.total_adjustments) / orders.total_orders,
  orders_per_customer AS orders.total_orders / customers.total_customers
)

COMMENT = 'Order economics: non-additive ratio metrics over dim_customers, fct_orders, fct_order_adjustments'
