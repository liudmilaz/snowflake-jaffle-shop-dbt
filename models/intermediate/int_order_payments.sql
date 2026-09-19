-- One row per order: total successfully-paid amount, in dollars.
-- `stg_payments.amount` is in cents (source system convention) and failed
-- payments must not count toward what the customer actually paid — both
-- are business rules, which is why this lives in intermediate, not staging.

select
    order_id,
    sum(case when status <> 'fail' then amount else 0 end) / 100.0 as total_amount_paid
from {{ ref('stg_payments') }}
group by order_id
