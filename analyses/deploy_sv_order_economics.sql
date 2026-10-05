-- Standalone DDL for sv_order_economics, bypassing dbt's semantic_view
-- materialization (see PR #2 / dbt Cloud Fusion debugging thread).
-- Prerequisite: dim_customers, fct_orders, fct_order_adjustments must
-- already exist in PC_DBT_DB.dbt_LZolotukhina -- run
--   dbt build --select +sv_order_economics --exclude sv_order_economics
-- (or the full `dbt build`) via dbt Core first if they don't.

create or replace semantic view PC_DBT_DB.dbt_LZolotukhina.sv_order_economics

TABLES(
  customers AS PC_DBT_DB.dbt_LZolotukhina.dim_customers PRIMARY KEY (customer_id),
  orders AS PC_DBT_DB.dbt_LZolotukhina.fct_orders PRIMARY KEY (order_id),
  adjustments AS PC_DBT_DB.dbt_LZolotukhina.fct_order_adjustments PRIMARY KEY (adjustment_id)
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
  adjustments.total_adjustments AS COALESCE(SUM(adjustments.adjustment_amount), 0),
  customers.total_customers AS COUNT(DISTINCT customers.customer_id),
  avg_order_value AS orders.total_revenue / orders.total_orders,
  true_avg_order_value AS (orders.total_revenue + COALESCE(adjustments.total_adjustments, 0)) / orders.total_orders,
  orders_per_customer AS orders.total_orders / customers.total_customers
)

COMMENT = 'Order economics: non-additive ratio metrics over dim_customers, fct_orders, fct_order_adjustments';
