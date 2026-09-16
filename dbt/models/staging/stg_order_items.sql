{{
    config(
        materialized = 'view'
    )
}}

with source as (
    select * from {{ source('raw_ecommerce', 'raw_order_items') }}
)

select
    order_item_id,
    order_id,
    product_id,
    quantity,
    cast(unit_price as numeric) as unit_price,
    cast(quantity * unit_price as numeric) as line_total
from source
