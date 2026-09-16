{{
    config(
        materialized = 'view'
    )
}}

with source as (
    select * from {{ source('raw_ecommerce', 'raw_orders') }}
)

select
    order_id,
    customer_id,
    lower(trim(order_status)) as order_status,
    order_timestamp,
    date(order_timestamp) as order_date
from source
