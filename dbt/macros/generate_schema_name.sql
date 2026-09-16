{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- set prefix = env_var('DBT_DATASET_PREFIX', 'ecommerce') -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ prefix }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
