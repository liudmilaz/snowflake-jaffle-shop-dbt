-- Real SCD Type 2 history for the customer dimension. No updated_at
-- column exists on the source, so `check` strategy (compare tracked
-- columns row by row) is used instead of `timestamp` strategy.

{% snapshot dim_customers_snapshot %}

{{
    config(
        target_schema='snapshots',
        unique_key='customer_id',
        strategy='check',
        check_cols=['first_name', 'last_name'],
    )
}}

select * from {{ ref('stg_customers') }}

{% endsnapshot %}
