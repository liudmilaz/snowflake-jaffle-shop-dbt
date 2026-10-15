{#
  The Lightdash side of the order-economics reconciliation, expressed as SQL.

  This mirrors what Lightdash generates for the `dim_customers` explore with a
  date dimension (models/marts/_marts__models.yml): customers LEFT JOIN orders
  LEFT JOIN adjustments, ratio metrics recomputed from their components, and
  fan-out protection (adjustments pre-aggregated to one row per order, which
  is what Lightdash's primary_key dedup achieves). If you change a metric
  formula in the YAML, change it here too -- the reconciliation test then
  proves the semantic view still agrees.

  Rows with a NULL period (customers who never ordered) are dropped: the
  semantic view has no such row either.
#}
{% macro lightdash_order_economics(grain) %}

with adjustments_per_order as (

    select order_id, sum(amount_delta) as adjustment_amount
    from {{ ref('fct_order_adjustments') }}
    group by order_id

),

components as (

    select
        date_trunc('{{ grain }}', orders.order_date)::date as period,
        count(distinct orders.order_id) as total_orders,
        count(distinct customers.customer_id) as total_customers,
        sum(orders.amount) as total_revenue,
        sum(coalesce(adjustments.adjustment_amount, 0)) as total_adjustments
    from {{ ref('dim_customers') }} as customers
    left join {{ ref('fct_orders') }} as orders
        on customers.customer_id = orders.customer_id
    left join adjustments_per_order as adjustments
        on orders.order_id = adjustments.order_id
    group by 1

)

select
    period,
    total_orders,
    total_revenue / nullif(total_orders, 0) as avg_order_value,
    (total_revenue + total_adjustments) / nullif(total_orders, 0) as true_avg_order_value,
    total_orders / nullif(total_customers, 0) as orders_per_customer
from components
where period is not null

{% endmacro %}
