select
    orders.order_id,
    orders.customer_id,
    orders.order_date,
    orders.status,
    coalesce(order_payments.total_amount_paid, 0) as amount
from {{ ref('stg_orders') }} as orders
left join {{ ref('int_order_payments') }} as order_payments
    on orders.order_id = order_payments.order_id
