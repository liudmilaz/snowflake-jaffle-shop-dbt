-- Accumulating-snapshot fact: one row per customer (same population as
-- dim_customers, via the left join below), holding lifetime order metrics
-- as of the last dbt build.
--
-- These are NOT filterable/re-sliceable by date -- they're a frozen
-- lifetime total. For date-scoped order metrics (e.g. "orders in the
-- last 90 days"), aggregate fct_orders directly instead of relying on
-- this table. Join to dim_customers via customer_id for descriptive
-- attributes (name) -- this fact intentionally carries no attributes
-- of its own.

select
    customers.customer_id,
    customer_orders.first_order_date,
    customer_orders.most_recent_order_date,
    coalesce(customer_orders.number_of_orders, 0) as number_of_orders
from {{ ref('dim_customers') }} as customers
left join {{ ref('int_customer_orders') }} as customer_orders
    on customers.customer_id = customer_orders.customer_id
