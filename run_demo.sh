#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# dbt BigQuery Multi-Pipeline Demo Runner with Dataplex Metadata Ingestion
# Orchestrates Terraform, Synthetic Data, dbt Prerequisites, & Knowledge Catalog
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Handle --destroy or --clean flags directly
if [[ "${1:-}" == "--destroy" || "${1:-}" == "--clean" ]]; then
    exec ./cleanup.sh
fi

echo "==================================================================="
echo "  dbt + BigQuery Multi-Pipeline Demo (Data Lineage & Dataplex)"
echo "==================================================================="

# 1. Pre-flight Checks
echo "--> Checking CLI prerequisites..."
for tool in gcloud terraform uv; do
    if ! command -v "${tool}" &> /dev/null; then
        echo "Error: Required tool '${tool}' is not installed or not in PATH."
        exit 1
    fi
done
echo "    [OK] gcloud, terraform, and uv are present."

# 2. Check and Load Environment Variables
if [[ ! -f ".env" ]]; then
    if [[ -f ".env.example" ]]; then
        echo "Notice: .env not found. Creating .env from .env.example..."
        cp .env.example .env
        echo "Please edit .env with your GCP_PROJECT_ID and rerun this script."
        exit 1
    else
        echo "Error: Neither .env nor .env.example found."
        exit 1
    fi
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
export DBT_PROFILES_DIR="${SCRIPT_DIR}/dbt"

echo "    Project ID:          ${GCP_PROJECT_ID}"
echo "    Region:              ${GCP_REGION}"
echo "    Dataset Prefix:      ${DBT_DATASET_PREFIX}"
echo "    Dataplex Entry Group:${DATAPLEX_ENTRY_GROUP}"
echo ""

# 3. Step 1: Terraform Infrastructure Provisioning
echo "==================================================================="
echo "  Step 1: Provisioning GCP Infrastructure with Terraform"
echo "==================================================================="
echo "--> Initializing and applying Terraform resources..."
terraform -chdir=terraform init -input=false
terraform -chdir=terraform apply -auto-approve -input=false
echo "    [OK] BigQuery datasets, Dataplex entry group, and GCS staging bucket provisioned."
echo ""

# 4. Step 2: Python Environment & Synthetic Data Ingestion
echo "==================================================================="
echo "  Step 2: Generating Synthetic E-commerce Ingestion Data"
echo "==================================================================="
echo "--> Syncing Python environment with uv..."
uv sync
echo "--> Generating relational mock data and streaming to BigQuery raw tables..."
uv run python scripts/generate_synthetic_data.py
echo "    [OK] Raw tables populated in ${GCP_PROJECT_ID}.${DBT_DATASET_PREFIX}_raw."
echo ""

# 5. Step 3: dbt Prerequisites & Model Execution
echo "==================================================================="
echo "  Step 3: Executing dbt Lifecycle (Dataplex Metadata Prerequisites)"
echo "==================================================================="
echo "--> Verifying BigQuery connection..."
uv run dbt debug --project-dir dbt --profiles-dir dbt

echo ""
echo "--> [1/3] Running 'dbt source freshness' (generates sources.json)..."
uv run dbt source freshness --project-dir dbt --profiles-dir dbt

echo ""
echo "--> [2/3] Running 'dbt build' (materializes views/tables, executes tests, generates manifest.json & run_results.json)..."
uv run dbt build --project-dir dbt --profiles-dir dbt

echo ""
echo "--> [3/3] Running 'dbt docs generate --no-compile' (generates catalog.json without erasing test results)..."
uv run dbt docs generate --project-dir dbt --profiles-dir dbt --no-compile

echo ""
echo "--> Verifying generated dbt metadata artifacts:"
for artifact in manifest.json catalog.json run_results.json sources.json; do
    if [[ -f "dbt/target/${artifact}" ]]; then
        echo "    [OK] dbt/target/${artifact} is ready."
    else
        echo "    [WARNING] dbt/target/${artifact} is missing."
    fi
done
echo ""

# 6. Step 4: Ingest dbt Metadata into Dataplex Knowledge Catalog
echo "==================================================================="
echo "  Step 4: Ingesting dbt Metadata into Dataplex Knowledge Catalog"
echo "==================================================================="
STAGING_BUCKET="${GCP_PROJECT_ID}-${DBT_DATASET_PREFIX}-dbt-staging"
STORAGE_URI="gs://${STAGING_BUCKET}/dbt-imports/"

echo "--> Target Entry Group: ${DATAPLEX_ENTRY_GROUP}"
echo "--> Staging URI:        ${STORAGE_URI}"
echo "--> Executing gcloud alpha dataplex dbt metadata-jobs create..."

gcloud alpha dataplex dbt metadata-jobs create \
    --project="${GCP_PROJECT_ID}" \
    --location="${GCP_REGION}" \
    --artifacts-path="dbt/target" \
    --entry-group="${DATAPLEX_ENTRY_GROUP}" \
    --storage-uri="${STORAGE_URI}"

echo "    [OK] dbt metadata imported into Dataplex Knowledge Catalog!"
echo ""

# 7. Step 5: Verification & UI Exploration Instructions
echo "==================================================================="
echo "  Demo Execution Completed Successfully! 🎉"
echo "==================================================================="
echo ""
echo "1. Data Lineage in BigQuery Studio:"
echo "   URL: https://console.cloud.google.com/bigquery?project=${GCP_PROJECT_ID}"
echo "   - Expand dataset: ${DBT_DATASET_PREFIX}_marts"
echo "   - Click on 'fct_orders', 'dim_customers', or 'fct_daily_revenue'"
echo "   - Click the 'Lineage' tab to see upstream/downstream graph"
echo ""
echo "2. dbt Metadata in Knowledge Catalog:"
echo "   URL: https://console.cloud.google.com/dataplex/dp-search?project=${GCP_PROJECT_ID}"
echo "   - Search: system=DBT"
echo "   - Or filter by: Imported Context > Managed Connectors > dbt"
echo "   - Inspect rich aspects: SQL definitions, column descriptions, source freshness, and test results!"
echo ""
echo "To tear down all resources when finished:"
echo "  ./cleanup.sh"
echo "==================================================================="
