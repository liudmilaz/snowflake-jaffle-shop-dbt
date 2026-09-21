-- Append-only ledger of corrections to orders whose order_date falls in
-- an already-closed accounting period (period_close). fct_orders' own
-- merge is guarded to never touch those orders, so its stored `amount`
-- stays exactly as reported/taxed. When a late payment changes what an
-- order is really worth, the *residual* delta -- true amount minus
-- whatever has already been recognized (the frozen fct_orders.amount
-- plus any adjustments already booked here) -- gets booked as a new
-- row here, recognized in the CURRENT open period. Never updated or
-- deleted once written: incremental/append, self-referencing via
-- {{ this }} to stay idempotent across runs.

with true_amounts as (

    select
        order_id,
        sum(case when status <> 'fail' then amount else 0 end) / 100.0 as true_amount
    from {{ ref('stg_payments') }}
    group by order_id

),

closed_orders as (

    select
        orders.order_id,
        period_close.period_start as original_period_start,
        period_close.period_end as original_period_end
    from {{ ref('stg_orders') }} as orders
    inner join {{ ref('period_close') }} as period_close
        on orders.order_date between period_close.period_start and period_close.period_end

),

already_recognized as (

    select
        fct_orders.order_id,
        fct_orders.amount
        {% if is_incremental() %}
        + coalesce((
            select sum(prior_adjustments.amount_delta)
            from {{ this }} as prior_adjustments
            where prior_adjustments.order_id = fct_orders.order_id
        ), 0)
        {% endif %}
        as recognized_amount
    from {{ ref('fct_orders') }} as fct_orders

),

final as (

    select
        md5(
            closed_orders.order_id::varchar || '-' || to_varchar(current_timestamp())
        ) as adjustment_id,
        closed_orders.order_id,
        closed_orders.original_period_start,
        closed_orders.original_period_end,
        date_trunc('month', current_date())::date as recognized_period_start,
        true_amounts.true_amount - already_recognized.recognized_amount as amount_delta,
        'late_arriving_payment' as reason,
        current_timestamp() as created_at
    from closed_orders
    inner join true_amounts
        on closed_orders.order_id = true_amounts.order_id
    inner join already_recognized
        on closed_orders.order_id = already_recognized.order_id
    where true_amounts.true_amount <> already_recognized.recognized_amount

)

select * from final
