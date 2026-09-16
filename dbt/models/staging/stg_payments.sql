{{
    config(
        materialized = 'view'
    )
}}

with source as (
    select * from {{ source('raw_ecommerce', 'raw_payments') }}
)

select
    payment_id,
    order_id,
    lower(trim(payment_method)) as payment_method,
    cast(amount as numeric) as payment_amount,
    lower(trim(payment_status)) as payment_status,
    payment_timestamp,
    date(payment_timestamp) as payment_date
from source
