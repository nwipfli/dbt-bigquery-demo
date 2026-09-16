output "project_id" {
  description = "The GCP project ID configured for this deployment."
  value       = var.project_id
}

output "region" {
  description = "The GCP region where datasets reside."
  value       = var.region
}

output "raw_dataset_id" {
  description = "The BigQuery dataset ID for raw data."
  value       = google_bigquery_dataset.raw.dataset_id
}

output "staging_dataset_id" {
  description = "The BigQuery dataset ID for staging views."
  value       = google_bigquery_dataset.staging.dataset_id
}

output "marts_dataset_id" {
  description = "The BigQuery dataset ID for production marts."
  value       = google_bigquery_dataset.marts.dataset_id
}

output "metadata_staging_bucket" {
  description = "The GCS bucket URL for staging dbt metadata."
  value       = google_storage_bucket.dbt_metadata_staging.url
}

output "entry_group_id" {
  description = "The Dataplex entry group ID for dbt metadata."
  value       = google_dataplex_entry_group.dbt_metadata.entry_group_id
}
