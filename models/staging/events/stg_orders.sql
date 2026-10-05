-- Materialization (incremental/append) is set at the folder level in
-- dbt_project.yml (models.jaffle_shop.staging.events). Plain incremental,
-- not microbatch -- see that config's comment for why.

select
    id as order_id,
    user_id as customer_id,
    order_date,
    status
from {{ source('jaffle_shop', 'orders') }}

{% if is_incremental() %}
where order_date > (select coalesce(max(order_date), '1900-01-01'::date) from {{ this }})
{% endif %}
