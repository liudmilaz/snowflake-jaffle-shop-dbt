-- depends_on: {{ ref('stg_payments') }}
-- depends_on: {{ ref('period_close') }}
-- Incremental (merge/unique_key) -- materialization set at folder level
-- in dbt_project.yml (models.jaffle_shop.marts.events).
--
-- A plain order_date filter would miss late-arriving payments: a payment
-- can land days after its order was placed, and int_order_payments'
-- aggregation loses the per-payment timestamp needed to detect that. So
-- the incremental scope below re-checks stg_payments directly, bounded
-- by a lookback window -- same idea as microbatch's `lookback`, hand-
-- rolled here since `merge` has no built-in equivalent. A payment
-- landing later than this window still needs a manual reprocess or a
-- --full-refresh to be picked up.
--
-- Guard: never merge into an order whose order_date falls in a closed
-- accounting period (period_close) -- that number has already been
-- reported and taxed, and must stay frozen. Late corrections for those
-- orders are booked into fct_order_adjustments instead, recognized in
-- the current open period rather than restating the closed one.

select
    orders.order_id,
    orders.customer_id,
    orders.order_date,
    orders.status,
    coalesce(order_payments.total_amount_paid, 0) as amount
from {{ ref('stg_orders') }} as orders
left join {{ ref('int_order_payments') }} as order_payments
    on orders.order_id = order_payments.order_id

{% if is_incremental() %}
where orders.order_id in (
    -- newly placed orders since last run
    select order_id
    from {{ ref('stg_orders') }}
    where order_date > (select coalesce(max(order_date), '1900-01-01'::date) from {{ this }})

    union

    -- orders whose payments changed recently
    select order_id
    from {{ ref('stg_payments') }}
    where created > dateadd('day', -7, current_date())
)
and not exists (
    select 1
    from {{ ref('period_close') }} as period_close
    where orders.order_date between period_close.period_start and period_close.period_end
)
{% endif %}
