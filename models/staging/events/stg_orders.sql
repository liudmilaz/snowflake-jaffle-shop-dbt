-- Materialization (incremental/microbatch/batch_size/begin) is set at the
-- folder level in dbt_project.yml (models.jaffle_shop.staging.events).
-- event_time can't live there -- it's this model's own column name -- so
-- it's the one config that has to stay here.
{{ config(event_time='order_date') }}

select
    id as order_id,
    user_id as customer_id,
    order_date,
    status
from {{ source('jaffle_shop', 'orders') }}
