-- One row per customer: order-history aggregates used to build the
-- customer dimension. Grain change (orders -> customers) is exactly the
-- kind of reshaping that belongs in intermediate, not staging.

select
    customer_id,
    min(order_date) as first_order_date,
    max(order_date) as most_recent_order_date,
    count(order_id) as number_of_orders
from {{ ref('stg_orders') }}
group by customer_id
