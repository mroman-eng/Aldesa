project_id   = "data-buildtrack-dev"
environment  = "dev"
region       = "europe-west1"
service_name = "aldesa-buildtrack"

additional_labels = {}

dev_enabled = true # use this variable to enable/disable the deployment of dev resources. Set to false to destroy them.

foundation_remote_state = {
  bucket            = "data-buildtrack-dev-tfstate-europe-west1"
  foundation_prefix = "shared/10-foundation"
}

use_requirements_txt_pypi_packages = true
composer_requirements_file         = "../../../composer/requirements.txt"

landing_bucket = {
  name          = "dev-data-buildtrack-dev-ingesta-sap-europe-west1"
  location      = "europe-west1"
  force_destroy = true
}

dataset_ids = {
  alerts = "dev_alerts"
  logs   = "dev_logs"
  raw    = "dev_raw"
  bronze = "dev_bronze"
  silver = "dev_silver"
  gold   = "dev_gold"
}

bigquery_location_override = "europe-west1"

composer = {
  image_version    = "composer-3-airflow-2.10.5-build.29"
  environment_name = "dev-data-buildtrack-dev-orchestrator-sap-europe-west1"
  env_variables = {
    GCP_PROJECT_ID    = "data-buildtrack-dev"
    GCP_LOCATION      = "europe-west1"
    GCP_REPOSITORY_ID = "pre-data-buildtrack-dev-dataform-sap-europe-west1"
    LANDING_BUCKET    = "dev-data-buildtrack-dev-ingesta-sap-europe-west1"
  }
  service_account_id         = "cmp-dev-aldesa-buildtrack"
  environment_size           = "ENVIRONMENT_SIZE_SMALL"
  scheduler_count            = 1
  scheduler_cpu              = 1
  scheduler_memory_gb        = 2
  scheduler_storage_gb       = 1
  dag_processor_count        = 1
  dag_processor_cpu          = 1
  dag_processor_memory_gb    = 4
  dag_processor_storage_gb   = 1
  triggerer_count            = 1
  triggerer_cpu              = 1
  triggerer_memory_gb        = 1
  web_server_cpu             = 1
  web_server_memory_gb       = 2
  web_server_storage_gb      = 1
  worker_min_count           = 1
  worker_max_count           = 3
  worker_cpu                 = 1
  worker_memory_gb           = 2
  worker_storage_gb          = 10
  enable_private_environment = true
  enable_private_builds_only = false
  internal_ipv4_cidr_block   = "100.64.144.0/20"
}

composer_bigquery_access = {
  grant_job_user          = true
  dataset_data_editor_ids = ["dev_alerts", "dev_logs", "dev_raw", "dev_bronze", "dev_silver", "dev_gold"]
}

dags_bucket = {
  name          = "dev-data-buildtrack-dev-dags-composer-europe-west1"
  location      = "europe-west1"
  force_destroy = false
}
