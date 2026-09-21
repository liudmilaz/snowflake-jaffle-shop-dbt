-- Materialization (incremental/microbatch/batch_size/begin) is set at the
-- folder level in dbt_project.yml (models.jaffle_shop.staging.events).
-- event_time can't live there -- it's this model's own column name -- so
-- it's the one config that has to stay here.
{{ config(event_time='created') }}

select
    id as payment_id,
    orderid as order_id,
    paymentmethod as payment_method,
    status,
    amount,
    created
from {{ source('stripe', 'payment') }}
