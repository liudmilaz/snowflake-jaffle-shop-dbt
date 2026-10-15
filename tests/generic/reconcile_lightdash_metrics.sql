{#
  Reconciles the Snowflake semantic view against the Lightdash metric
  definitions at one date grain. Returns one row per period and metric that
  disagrees (or exists on only one side); the test passes when no rows return.

  model:      the semantic view (sv_order_economics)
  dimension:  the semantic view's date dimension for this grain
              (order_month | order_quarter | order_year)
  grain:      month | quarter | year (passed to the Lightdash-side macro)
  tolerance:  max absolute difference per metric (default 1e-6)

  Note: at a period grain, orders_per_customer divides by customers who ordered
  in that period, not by all customers. Only the all-time total uses all
  customers. Both systems follow this, so it reconciles.
#}
{% test reconcile_lightdash_metrics(model, dimension, grain, tolerance=0.000001) %}

with semantic_view as (

    select
        {{ dimension }}::date as period,
        avg_order_value,
        true_avg_order_value,
        orders_per_customer
    from semantic_view(
        {{ model }}
        metrics avg_order_value, true_avg_order_value, orders_per_customer
        dimensions {{ dimension }}
    )
    -- the view also returns a NULL-period row: customers who never ordered
    where {{ dimension }} is not null

),

lightdash as (

    {{ lightdash_order_economics(grain) }}

),

compared as (

    select
        coalesce(sv.period, ld.period) as period,
        sv.period is null as missing_in_semantic_view,
        ld.period is null as missing_in_lightdash,
        sv.avg_order_value as sv_avg_order_value,
        ld.avg_order_value as ld_avg_order_value,
        sv.true_avg_order_value as sv_true_avg_order_value,
        ld.true_avg_order_value as ld_true_avg_order_value,
        sv.orders_per_customer as sv_orders_per_customer,
        ld.orders_per_customer as ld_orders_per_customer
    from semantic_view as sv
    full outer join lightdash as ld
        on sv.period = ld.period

)

select *
from compared
where missing_in_semantic_view
    or missing_in_lightdash
    or abs(coalesce(sv_avg_order_value, 0) - coalesce(ld_avg_order_value, 0)) > {{ tolerance }}
    or abs(coalesce(sv_true_avg_order_value, 0) - coalesce(ld_true_avg_order_value, 0)) > {{ tolerance }}
    or abs(coalesce(sv_orders_per_customer, 0) - coalesce(ld_orders_per_customer, 0)) > {{ tolerance }}

{% endtest %}
