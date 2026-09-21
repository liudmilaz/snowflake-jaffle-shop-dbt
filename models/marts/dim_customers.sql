-- Pure customer dimension: descriptive attributes only, no aggregates.
-- Lifetime order metrics live in fct_customer_order_summary instead --
-- see that model's docstring for why they don't belong here.

select
    customer_id,
    first_name,
    last_name
from {{ ref('stg_customers') }}
