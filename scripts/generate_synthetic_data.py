#!/usr/bin/env python3
"""
Synthetic Relational Data Generator for dbt BigQuery Multi-Pipeline Demo.
Populates BigQuery raw tables in the raw dataset with consistent referential integrity.
"""

import os
import random
from datetime import datetime, timedelta, timezone
from pathlib import Path
from dotenv import load_dotenv
from faker import Faker
from google.cloud import bigquery

# Load environment variables
env_path = Path(__file__).resolve().parent.parent / ".env"
load_dotenv(dotenv_path=env_path)

PROJECT_ID = os.getenv("GCP_PROJECT_ID")
REGION = os.getenv("GCP_REGION", "us-central1")
DATASET_PREFIX = os.getenv("DBT_DATASET_PREFIX", "ecommerce")
RAW_DATASET_ID = f"{DATASET_PREFIX}_raw"

if not PROJECT_ID:
    raise ValueError("GCP_PROJECT_ID environment variable is required. Check your .env file.")

fake = Faker()
Faker.seed(42)
random.seed(42)


def get_bigquery_client():
    return bigquery.Client(project=PROJECT_ID, location=REGION)


def generate_and_load_data():
    client = get_bigquery_client()
    raw_dataset_ref = f"{PROJECT_ID}.{RAW_DATASET_ID}"
    print(f"Target BigQuery Dataset: {raw_dataset_ref} (Location: {REGION})")

    # 1. Generate Products
    print("Generating products...")
    categories = ["Electronics", "Home & Kitchen", "Apparel", "Beauty & Health", "Sports & Outdoors", "Books"]
    product_adjectives = ["Smart", "Eco-friendly", "Premium", "Ultra", "Classic", "Wireless", "Ergonomic", "Portable"]
    product_nouns = ["Hub", "Speaker", "Backpack", "Watch", "Blender", "Kettle", "Headphones", "Mat", "Lamp"]

    products = []
    num_products = 150
    for i in range(1, num_products + 1):
        prod_id = f"PROD-{i:04d}"
        category = random.choice(categories)
        name = f"{random.choice(product_adjectives)} {random.choice(product_nouns)} {random.randint(100, 999)}"
        cost = round(random.uniform(5.0, 150.0), 2)
        margin_multiplier = random.uniform(1.3, 2.5)
        price = round(cost * margin_multiplier, 2)
        created_at = fake.date_time_between(start_date="-2y", end_date="-1y", tzinfo=timezone.utc).isoformat()
        products.append({
            "product_id": prod_id,
            "product_name": name,
            "category": category,
            "price": float(price),
            "cost": float(cost),
            "created_at": created_at,
        })

    # 2. Generate Customers
    print("Generating customers...")
    customers = []
    num_customers = 1000
    countries = ["US", "CA", "GB", "DE", "FR", "AU", "JP"]
    for i in range(1, num_customers + 1):
        cust_id = f"CUST-{i:05d}"
        first_name = fake.first_name()
        # Synthetic email using RFC 2606 reserved example.com domain to guarantee no real inbox collisions
        email = f"{first_name.lower()}.{last_name.lower()}.{i}@example.com"
        country = random.choices(countries, weights=[50, 10, 10, 8, 8, 7, 7])[0]
        signup_date = fake.date_time_between(start_date="-2y", end_date="now", tzinfo=timezone.utc).isoformat()
        customers.append({
            "customer_id": cust_id,
            "first_name": first_name,
            "last_name": last_name,
            "email": email,
            "country": country,
            "signup_date": signup_date,
        })

    # 3. Generate Orders & Order Items & Payments
    print("Generating orders, line items, and payments...")
    orders = []
    order_items = []
    payments = []

    order_statuses = ["completed", "completed", "completed", "shipped", "cancelled", "returned"]
    payment_methods = ["credit_card", "paypal", "bank_transfer", "apple_pay"]
    order_item_counter = 1
    payment_counter = 1

    num_orders = 4000
    base_start = datetime.now(timezone.utc) - timedelta(days=365)

    for i in range(1, num_orders + 1):
        order_id = f"ORD-{i:06d}"
        customer = random.choice(customers)
        status = random.choice(order_statuses)
        order_time = fake.date_time_between(start_date=base_start, end_date="now", tzinfo=timezone.utc)
        order_timestamp = order_time.isoformat()

        # Add 1 to 4 items per order
        num_items = random.randint(1, 4)
        order_total = 0.0
        selected_prods = random.sample(products, k=min(num_items, len(products)))

        for prod in selected_prods:
            qty = random.randint(1, 3)
            unit_price = prod["price"]
            line_total = round(qty * unit_price, 2)
            order_total += line_total

            order_items.append({
                "order_item_id": f"ITEM-{order_item_counter:07d}",
                "order_id": order_id,
                "product_id": prod["product_id"],
                "quantity": qty,
                "unit_price": float(unit_price),
            })
            order_item_counter += 1

        orders.append({
            "order_id": order_id,
            "customer_id": customer["customer_id"],
            "order_status": status,
            "order_timestamp": order_timestamp,
        })

        # Generate payment if order is not cancelled
        if status != "cancelled":
            pay_status = "refunded" if status == "returned" else "success"
            payments.append({
                "payment_id": f"PAY-{payment_counter:06d}",
                "order_id": order_id,
                "payment_method": random.choice(payment_methods),
                "amount": round(order_total, 2),
                "payment_status": pay_status,
                "payment_timestamp": order_timestamp,
            })
            payment_counter += 1

    # Load into BigQuery using WRITE_TRUNCATE
    schemas = {
        "raw_products": [
            bigquery.SchemaField("product_id", "STRING", mode="REQUIRED"),
            bigquery.SchemaField("product_name", "STRING", mode="REQUIRED"),
            bigquery.SchemaField("category", "STRING", mode="REQUIRED"),
            bigquery.SchemaField("price", "NUMERIC", mode="REQUIRED"),
            bigquery.SchemaField("cost", "NUMERIC", mode="REQUIRED"),
            bigquery.SchemaField("created_at", "TIMESTAMP", mode="REQUIRED"),
        ],
        "raw_customers": [
            bigquery.SchemaField("customer_id", "STRING", mode="REQUIRED"),
            bigquery.SchemaField("first_name", "STRING", mode="REQUIRED"),
            bigquery.SchemaField("last_name", "STRING", mode="REQUIRED"),
            bigquery.SchemaField("email", "STRING", mode="REQUIRED"),
            bigquery.SchemaField("country", "STRING", mode="REQUIRED"),
            bigquery.SchemaField("signup_date", "TIMESTAMP", mode="REQUIRED"),
        ],
        "raw_orders": [
            bigquery.SchemaField("order_id", "STRING", mode="REQUIRED"),
            bigquery.SchemaField("customer_id", "STRING", mode="REQUIRED"),
            bigquery.SchemaField("order_status", "STRING", mode="REQUIRED"),
            bigquery.SchemaField("order_timestamp", "TIMESTAMP", mode="REQUIRED"),
        ],
        "raw_order_items": [
            bigquery.SchemaField("order_item_id", "STRING", mode="REQUIRED"),
            bigquery.SchemaField("order_id", "STRING", mode="REQUIRED"),
            bigquery.SchemaField("product_id", "STRING", mode="REQUIRED"),
            bigquery.SchemaField("quantity", "INT64", mode="REQUIRED"),
            bigquery.SchemaField("unit_price", "NUMERIC", mode="REQUIRED"),
        ],
        "raw_payments": [
            bigquery.SchemaField("payment_id", "STRING", mode="REQUIRED"),
            bigquery.SchemaField("order_id", "STRING", mode="REQUIRED"),
            bigquery.SchemaField("payment_method", "STRING", mode="REQUIRED"),
            bigquery.SchemaField("amount", "NUMERIC", mode="REQUIRED"),
            bigquery.SchemaField("payment_status", "STRING", mode="REQUIRED"),
            bigquery.SchemaField("payment_timestamp", "TIMESTAMP", mode="REQUIRED"),
        ],
    }

    tables_data = {
        "raw_products": products,
        "raw_customers": customers,
        "raw_orders": orders,
        "raw_order_items": order_items,
        "raw_payments": payments,
    }

    for table_name, rows in tables_data.items():
        table_ref = f"{raw_dataset_ref}.{table_name}"
        job_config = bigquery.LoadJobConfig(
            schema=schemas[table_name],
            write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        )
        print(f"Loading {len(rows)} rows into {table_ref}...")
        job = client.load_table_from_json(rows, table_ref, job_config=job_config)
        job.result()  # Wait for load job to complete
        print(f" Successfully loaded {table_ref}")

    print("\nAll synthetic raw tables generated and loaded successfully into BigQuery!")


if __name__ == "__main__":
    generate_and_load_data()
