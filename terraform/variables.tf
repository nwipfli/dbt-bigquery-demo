variable "project_id" {
  description = "The Google Cloud Project ID where resources will be provisioned."
  type        = string
}

variable "region" {
  description = "The Google Cloud region for BigQuery datasets and Dataplex (e.g., us-central1)."
  type        = string
  default     = "us-central1"
}

variable "dataset_prefix" {
  description = "Prefix for the BigQuery datasets created for the demo."
  type        = string
  default     = "ecommerce"
}

variable "entry_group_id" {
  description = "The Dataplex entry group ID for dbt metadata ingestion."
  type        = string
  default     = "dbt-metadata-ingestion"
}
