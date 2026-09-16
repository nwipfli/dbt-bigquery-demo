{{
    config(
        materialized = 'view'
    )
}}

with source as (
    select * from {{ source('raw_ecommerce', 'raw_customers') }}
)

select
    customer_id,
    trim(first_name) as first_name,
    trim(last_name) as last_name,
    lower(trim(email)) as email,
    upper(trim(country)) as country,
    signup_date
from source
