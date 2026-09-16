{{
    config(
        materialized = 'table',
        tags = ['operations']
    )
}}

with products as (
    select * from {{ ref('dim_products') }}
),

order_items as (
    select * from {{ ref('stg_order_items') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

items_joined as (
    select
        oi.product_id,
        oi.quantity,
        oi.line_total,
        o.order_status
    from order_items oi
    inner join orders o on oi.order_id = o.order_id
),

product_metrics as (
    select
        product_id,
        count(*) as total_order_lines,
        sum(quantity) as total_units_ordered,
        sum(line_total) as total_gross_sales,
        sum(case when order_status = 'returned' then quantity else 0 end) as total_units_returned,
        sum(case when order_status in ('completed', 'shipped') then line_total else 0 end) as net_sales_amount
    from items_joined
    group by product_id
)

select
    p.product_id,
    p.product_name,
    p.category,
    p.margin_tier,
    p.price,
    p.cost,
    coalesce(pm.total_units_ordered, 0) as total_units_ordered,
    coalesce(pm.total_units_returned, 0) as total_units_returned,
    coalesce(pm.total_gross_sales, 0) as total_gross_sales,
    coalesce(pm.net_sales_amount, 0) as net_sales_amount,
    round(safe_divide(coalesce(pm.total_units_returned, 0), coalesce(pm.total_units_ordered, 0)) * 100, 2) as return_rate_percentage
from products p
left join product_metrics pm on p.product_id = pm.product_id
