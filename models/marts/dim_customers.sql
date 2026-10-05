-- Current-state view over dim_customers_snapshot (SCD Type 2). Exposes
-- the same columns as before so every existing ref() keeps working
-- unchanged -- only each customer's current row (dbt_valid_to is null)
-- surfaces here. For historical states, query dim_customers_snapshot
-- directly.

select
    customer_id,
    first_name,
    last_name
from {{ ref('dim_customers_snapshot') }}
where dbt_valid_to is null
