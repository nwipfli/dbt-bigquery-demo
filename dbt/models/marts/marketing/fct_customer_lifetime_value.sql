{{
    config(
        materialized = 'table',
        tags = ['marketing']
    )
}}

with customers as (
    select * from {{ ref('dim_customers') }}
)

select
    format_timestamp('%Y-%m', signup_date) as signup_cohort_month,
    country,
    count(customer_id) as cohort_total_customers,
    countif(lifetime_orders_count > 0) as cohort_active_buyers_count,
    countif(customer_tier = 'VIP') as cohort_vip_count,
    sum(lifetime_net_spend) as cohort_cumulative_revenue,
    round(safe_divide(sum(lifetime_net_spend), count(customer_id)), 2) as average_clv_per_registered_user,
    round(safe_divide(sum(lifetime_net_spend), countif(lifetime_orders_count > 0)), 2) as average_clv_per_active_buyer
from customers
group by 1, 2
