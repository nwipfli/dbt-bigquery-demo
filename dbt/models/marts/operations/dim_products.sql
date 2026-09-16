{{
    config(
        materialized = 'table',
        tags = ['operations']
    )
}}

with products as (
    select * from {{ ref('stg_products') }}
)

select
    product_id,
    product_name,
    category,
    price,
    cost,
    gross_margin_per_unit,
    margin_percentage,
    case
        when margin_percentage >= 50 then 'High Margin'
        when margin_percentage >= 30 then 'Medium Margin'
        else 'Standard Margin'
    end as margin_tier,
    created_at
from products
