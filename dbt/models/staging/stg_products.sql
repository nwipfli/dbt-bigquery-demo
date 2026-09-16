{{
    config(
        materialized = 'view'
    )
}}

with source as (
    select * from {{ source('raw_ecommerce', 'raw_products') }}
)

select
    product_id,
    trim(product_name) as product_name,
    trim(category) as category,
    cast(price as numeric) as price,
    cast(cost as numeric) as cost,
    cast(price - cost as numeric) as gross_margin_per_unit,
    round(safe_divide(price - cost, price) * 100, 2) as margin_percentage,
    created_at
from source
