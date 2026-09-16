#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# dbt BigQuery Multi-Pipeline Demo Cleanup / Teardown Script
# Destroys BigQuery datasets, tables, Dataplex resources, and Terraform state.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "==================================================================="
echo "  dbt + BigQuery Demo: Teardown & Resource Cleanup"
echo "==================================================================="

if [[ ! -f ".env" ]]; then
    echo "Error: .env file not found. Cannot determine target project."
    exit 1
fi

# Load variables
set -a
source .env
set +a

if [[ -z "${GCP_PROJECT_ID:-}" ]]; then
    echo "Error: GCP_PROJECT_ID is not set in .env."
    exit 1
fi

GCP_REGION="${GCP_REGION:-us-central1}"
DBT_DATASET_PREFIX="${DBT_DATASET_PREFIX:-ecommerce}"
DATAPLEX_ENTRY_GROUP="${DATAPLEX_ENTRY_GROUP:-dbt-metadata-ingestion}"

export TF_VAR_project_id="${GCP_PROJECT_ID}"
export TF_VAR_region="${GCP_REGION}"
export TF_VAR_dataset_prefix="${DBT_DATASET_PREFIX}"
export TF_VAR_entry_group_id="${DATAPLEX_ENTRY_GROUP}"

# Prompt for confirmation if not forced
if [[ "${1:-}" != "-y" && "${1:-}" != "--force" ]]; then
    echo "WARNING: This will permanently destroy the following demo resources"
    echo "in project '${GCP_PROJECT_ID}':"
    echo "  - BigQuery datasets: ${DBT_DATASET_PREFIX}_raw, ${DBT_DATASET_PREFIX}_staging, ${DBT_DATASET_PREFIX}_marts"
    echo "  - GCS metadata staging bucket: ${GCP_PROJECT_ID}-${DBT_DATASET_PREFIX}-dbt-staging"
    echo "  - Dataplex Entry Group: ${DATAPLEX_ENTRY_GROUP}"
    echo ""
    read -p "Are you sure you want to proceed? (y/N): " -r CONFIRM
    if [[ ! "${CONFIRM}" =~ ^[Yy]$ ]]; then
        echo "Cleanup aborted by user."
        exit 0
    fi
fi

echo ""
echo "--> Destroying demo resources via Terraform..."
terraform -chdir=terraform destroy -auto-approve -input=false

echo "--> Cleaning up local dbt artifacts..."
rm -rf dbt/target dbt/dbt_packages dbt/logs

echo ""
echo "==================================================================="
echo "  [SUCCESS] All demo resources have been cleanly destroyed."
echo "==================================================================="
