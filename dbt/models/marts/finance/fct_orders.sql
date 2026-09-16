{{
    config(
        materialized = 'table',
        tags = ['finance']
    )
}}

with orders as (
    select * from {{ ref('stg_orders') }}
),

order_items as (
    select
        order_id,
        count(order_item_id) as total_items_count,
        sum(quantity) as total_units_count,
        sum(line_total) as gross_order_amount
    from {{ ref('stg_order_items') }}
    group by order_id
),

payments as (
    select
        order_id,
        sum(case when payment_status = 'success' then payment_amount else 0 end) as total_paid_amount,
        sum(case when payment_status = 'refunded' then payment_amount else 0 end) as total_refunded_amount
    from {{ ref('stg_payments') }}
    group by order_id
)

select
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_date,
    o.order_timestamp,
    coalesce(oi.total_items_count, 0) as total_items_count,
    coalesce(oi.total_units_count, 0) as total_units_count,
    coalesce(oi.gross_order_amount, 0) as gross_order_amount,
    coalesce(p.total_paid_amount, 0) as total_paid_amount,
    coalesce(p.total_refunded_amount, 0) as total_refunded_amount,
    case
        when o.order_status in ('completed', 'shipped') then coalesce(oi.gross_order_amount, 0) - coalesce(p.total_refunded_amount, 0)
        else 0
    end as net_order_revenue,
    case
        when coalesce(p.total_paid_amount, 0) > 0 then true
        else false
    end as is_paid
from orders o
left join order_items oi on o.order_id = oi.order_id
left join payments p on o.order_id = p.order_id
