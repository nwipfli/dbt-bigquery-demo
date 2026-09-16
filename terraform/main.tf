terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Lookup project details for service account number resolution
data "google_project" "project" {
  project_id = var.project_id
}

# Required Google Cloud APIs for BigQuery, Data Lineage, and Knowledge Catalog
locals {
  services = [
    "bigquery.googleapis.com",
    "datalineage.googleapis.com",
    "datacatalog.googleapis.com",
    "dataplex.googleapis.com",
    "storage.googleapis.com"
  ]
}

resource "google_project_service" "required_apis" {
  for_each           = toset(local.services)
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

# BigQuery Datasets
resource "google_bigquery_dataset" "raw" {
  dataset_id                 = "${var.dataset_prefix}_raw"
  friendly_name              = "Raw E-commerce Ingestion Data"
  description                = "Synthetic raw e-commerce tables populated by Python ingestion script"
  location                   = var.region
  delete_contents_on_destroy = true

  labels = {
    env  = "demo"
    tier = "raw"
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_bigquery_dataset" "staging" {
  dataset_id                 = "${var.dataset_prefix}_staging"
  friendly_name              = "Staging E-commerce Views"
  description                = "dbt staging views with cleaned, standardized, and typed attributes"
  location                   = var.region
  delete_contents_on_destroy = true

  labels = {
    env  = "demo"
    tier = "staging"
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_bigquery_dataset" "marts" {
  dataset_id                 = "${var.dataset_prefix}_marts"
  friendly_name              = "Production E-commerce Analytics Marts"
  description                = "dbt production mart tables across finance, marketing, and operations"
  location                   = var.region
  delete_contents_on_destroy = true

  labels = {
    env  = "demo"
    tier = "marts"
  }

  depends_on = [google_project_service.required_apis]
}

# Dataplex Entry Group for dbt metadata ingestion
resource "google_dataplex_entry_group" "dbt_metadata" {
  project        = var.project_id
  location       = var.region
  entry_group_id = var.entry_group_id
  description    = "Entry group for dbt Core and MetricFlow metadata ingestion"
  display_name   = "dbt Metadata Ingestion"

  depends_on = [google_project_service.required_apis]
}

# Cloud Storage Staging Bucket for dbt metadata import JSONL
resource "google_storage_bucket" "dbt_metadata_staging" {
  name                        = "${var.project_id}-${var.dataset_prefix}-dbt-staging"
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true

  labels = {
    env  = "demo"
    tier = "metadata-staging"
  }

  depends_on = [google_project_service.required_apis]
}

# Grant Knowledge Catalog Service Agent read access to staging bucket
resource "google_storage_bucket_iam_member" "dataplex_sa_viewer" {
  bucket = google_storage_bucket.dbt_metadata_staging.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-dataplex.iam.gserviceaccount.com"

  depends_on = [google_storage_bucket.dbt_metadata_staging]
}
