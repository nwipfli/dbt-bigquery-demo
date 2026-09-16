{{
    config(
        materialized = 'table',
        tags = ['marketing']
    )
}}

with customers as (
    select * from {{ ref('stg_customers') }}
),

customer_orders as (
    select
        customer_id,
        min(order_date) as first_order_date,
        max(order_date) as most_recent_order_date,
        count(order_id) as lifetime_orders_count,
        sum(gross_order_amount) as lifetime_gross_spend,
        sum(net_order_revenue) as lifetime_net_spend
    from {{ ref('fct_orders') }}
    group by customer_id
)

select
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.country,
    c.signup_date,
    co.first_order_date,
    co.most_recent_order_date,
    coalesce(co.lifetime_orders_count, 0) as lifetime_orders_count,
    coalesce(co.lifetime_gross_spend, 0) as lifetime_gross_spend,
    coalesce(co.lifetime_net_spend, 0) as lifetime_net_spend,
    case
        when coalesce(co.lifetime_net_spend, 0) >= 500 then 'VIP'
        when coalesce(co.lifetime_net_spend, 0) >= 150 then 'Regular'
        when coalesce(co.lifetime_orders_count, 0) > 0 then 'Occasional'
        else 'Prospect'
    end as customer_tier
from customers c
left join customer_orders co on c.customer_id = co.customer_id
