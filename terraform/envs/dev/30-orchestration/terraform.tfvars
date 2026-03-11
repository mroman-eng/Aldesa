project_id   = "data-buildtrack-dev"
environment  = "dev"
region       = "europe-west1"
service_name = "aldesa-buildtrack"

additional_labels = {}

use_requirements_txt_pypi_packages = true
composer_requirements_file         = "../../../../composer/requirements.txt"

foundation_remote_state = {
  bucket            = "data-buildtrack-dev-tfstate-europe-west1"
  foundation_prefix = "dev/10-foundation"
}

storage_bq_remote_state = {
  bucket            = "data-buildtrack-dev-tfstate-europe-west1"
  storage_bq_prefix = "dev/20-storage-bq"
}

composer = {
  image_version    = "composer-3-airflow-2.10.5-build.29"
  environment_name = "data-buildtrack-dev-orchestrator-sap-europe-west1"
  airflow_config_overrides = {
    "email-email_backend" = "airflow.providers.sendgrid.utils.emailer.send_email"
    "sendgrid-from_email" = "maypher.roman@vasscompany.com"
  }
  env_variables = {
    GCP_PROJECT_ID = "data-buildtrack-dev"
    GCP_LOCATION   = "europe-west1"
    LANDING_BUCKET = "data-buildtrack-dev-ingesta-sap-europe-west1"
  }
  service_account_id         = "cmp-dev-aldesa-buildtrack"
  environment_size           = "ENVIRONMENT_SIZE_SMALL"
  worker_min_count           = 1
  worker_max_count           = 3
  enable_private_environment = true
  enable_private_builds_only = false
  internal_ipv4_cidr_block   = "100.64.128.0/20"
}

composer_bigquery_access = {
  grant_job_user          = true
  dataset_data_editor_ids = ["raw", "bronze", "silver", "gold", "logs"]
}

dags_bucket = {
  name          = "data-buildtrack-dev-dags-composer-europe-west1"
  location      = "europe-west1"
  force_destroy = false
}

dataform = {
  enabled                   = true
  repository_name           = "data-buildtrack-dev-dataform-sap-europe-west1"
  git_remote_url            = "https://github.com/GrupoAldesa/build-track-gcp-dataops.git"
  git_remote_default_branch = "develop"
  git_token_secret_name     = "sec-aldesa-buildtrack-dev-dataform-github-pat"
  git_token_secret_version  = "latest"
  release_config = {
    enabled       = true
    name          = "dfrc-aldesa-buildtrack-dev"
    git_commitish = "develop"
    cron_schedule = null
    time_zone     = "UTC"
    code_compilation_config = {
      assertion_schema = "bronze_assertions"
      default_database = "data-buildtrack-dev"
      default_location = "europe-west1"
      default_schema   = "bronze"
      vars             = {}
    }
  }
  workflow_config = {
    enabled       = true
    name          = "dfwc-aldesa-buildtrack-dev"
    cron_schedule = null
    time_zone     = "UTC"
  }
}

# GCS->Pub/Sub->Cloud Function trigger to launch Composer DAGs on new landing files.
landing_to_composer_trigger = {
  enabled                          = true
  function_name                    = "data-buildtrack-dev-clf-ingesta-sap"
  runtime_service_account_id       = "cf-dev-aldesa-buildtrack-dag"
  trigger_service_account_id       = "evt-dev-aldesa-buildtrack-dag"
  pubsub_topic_name                = "data-buildtrack-dev-ps-ingesta-sap-europe-west1"
  source_dir                       = "../../../../functions/clf-ingesta-sap"
  source_object_prefix             = "functions/data-buildtrack-dev-clf-ingesta-sap"
  source_archive_bucket_name       = null
  entry_point                      = "trigger_dag"
  runtime                          = "python311"
  available_cpu                    = "1"
  available_memory                 = "512M"
  timeout_seconds                  = 300
  min_instance_count               = 0
  max_instance_count               = 100
  max_instance_request_concurrency = 80
  ingress_settings                 = "ALLOW_ALL"
  object_name_prefix               = "raw/sap/"
  retry_policy                     = "RETRY_POLICY_DO_NOT_RETRY"
  eventarc_receiver_project_role   = true
  environment_variables            = {}
  # Eventarc creates the push subscription automatically.
  # Keep this block enabled from day one; leave subscription_name = null.
  # The orchestration make targets auto-discover/import the subscription after the trigger exists.
  eventarc_subscription_tuning = {
    enabled              = true
    subscription_name    = null
    ack_deadline_seconds = 600
    minimum_backoff      = "10s"
    maximum_backoff      = "600s"
  }
}
