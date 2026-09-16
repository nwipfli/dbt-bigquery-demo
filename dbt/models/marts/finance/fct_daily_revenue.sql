{{
    config(
        materialized = 'table',
        tags = ['finance']
    )
}}

with orders as (
    select * from {{ ref('fct_orders') }}
)

select
    order_date,
    count(order_id) as total_orders,
    countif(order_status in ('completed', 'shipped')) as completed_orders,
    countif(order_status = 'cancelled') as cancelled_orders,
    countif(order_status = 'returned') as returned_orders,
    sum(gross_order_amount) as total_gross_revenue,
    sum(net_order_revenue) as total_net_revenue,
    round(safe_divide(sum(net_order_revenue), countif(order_status in ('completed', 'shipped'))), 2) as average_order_value
from orders
group by order_date
