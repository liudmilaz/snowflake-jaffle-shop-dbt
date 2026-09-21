-- Materialization (incremental/append) is set at the folder level in
-- dbt_project.yml (models.jaffle_shop.staging.events). Plain incremental,
-- not microbatch -- see that config's comment for why.

select
    id as payment_id,
    orderid as order_id,
    paymentmethod as payment_method,
    status,
    amount,
    created
from {{ source('stripe', 'payment') }}

{% if is_incremental() %}
where created > (select coalesce(max(created), '1900-01-01'::timestamp) from {{ this }})
{% endif %}
