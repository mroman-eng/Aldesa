project_id   = "data-buildtrack-dev"
environment  = "pre"
region       = "europe-west1"
service_name = "aldesa-buildtrack"

additional_labels = {}

use_requirements_txt_pypi_packages = true
composer_requirements_file         = "../../../../composer/requirements.txt"

foundation_remote_state = {
  bucket            = "data-buildtrack-dev-tfstate-europe-west1"
  foundation_prefix = "shared/10-foundation"
}

storage_bq_remote_state = {
  bucket            = "data-buildtrack-dev-tfstate-europe-west1"
  storage_bq_prefix = "pre/20-storage-bq"
}

composer = {
  image_version    = "composer-3-airflow-2.10.5-build.29"
  environment_name = "pre-data-buildtrack-dev-orchestrator-sap-europe-west1"
  airflow_config_overrides = {
    "email-email_backend" = "airflow.providers.sendgrid.utils.emailer.send_email"
    "sendgrid-from_email" = "maypher.roman@vasscompany.com"
  }
  env_variables = {
    GCP_PROJECT_ID     = "data-buildtrack-dev"
    GCP_LOCATION       = "europe-west1"
    LANDING_BUCKET     = "pre-data-buildtrack-dev-ingesta-sap-europe-west1"
    DATASET_EVENT_URI  = "gs://pre-data-buildtrack-dev-ingesta-sap-europe-west1/"
    OBJECT_NAME_PREFIX = ""
  }
  service_account_id         = "cmp-pre-aldesa-buildtrack"
  environment_size           = "ENVIRONMENT_SIZE_SMALL"
  scheduler_count            = 2
  scheduler_cpu              = 1
  scheduler_memory_gb        = 2
  scheduler_storage_gb       = 1
  dag_processor_count        = 2
  dag_processor_cpu          = 1
  dag_processor_memory_gb    = 4
  dag_processor_storage_gb   = 1
  triggerer_count            = 2
  triggerer_cpu              = 1
  triggerer_memory_gb        = 1
  web_server_cpu             = 1
  web_server_memory_gb       = 2
  web_server_storage_gb      = 1
  worker_min_count           = 2 # autoscaling, minimum number of workers to keep running
  worker_max_count           = 4 # autoscaling, maximum number of workers to scale up to when needed
  worker_cpu                 = 1
  worker_memory_gb           = 2
  worker_storage_gb          = 10
  enable_private_environment = true
  enable_private_builds_only = false
  internal_ipv4_cidr_block   = "100.64.128.0/20"
}

composer_bigquery_access = {
  grant_job_user          = true
  dataset_data_editor_ids = ["pre_bronze", "pre_silver", "pre_gold", "pre_assertions"]
}

dags_bucket = {
  name          = "pre-data-buildtrack-dev-dags-composer-europe-west1"
  location      = "europe-west1"
  force_destroy = false
}

dataform = {
  enabled                      = true
  execution_service_account_id = "dfm-pre-aldesa-buildtrack"
  repository_name              = "pre-data-buildtrack-dev-dataform-sap-europe-west1"
  git_remote_url               = "https://github.com/GrupoAldesa/build-track-gcp-dataops.git"
  git_remote_default_branch    = "develop"
  git_token_secret_name        = "sec-aldesa-buildtrack-dev-dataform-github-pat"
  git_token_secret_version     = "latest"
  release_config = {
    enabled       = true
    name          = "dfrc-aldesa-buildtrack-pre"
    git_commitish = "develop"
    cron_schedule = null
    time_zone     = "UTC"
    code_compilation_config = {
      assertion_schema = "pre_assertions"
      default_database = "data-buildtrack-dev"
      default_location = "europe-west1"
      default_schema   = "pre_bronze"
      schema_suffix    = null
      table_prefix     = null
      vars             = {}
    }
  }
  workflow_config = {
    enabled       = true
    name          = "dfwc-aldesa-buildtrack-pre"
    cron_schedule = null
    time_zone     = "UTC"
  }
}

# GCS->Pub/Sub->Cloud Function trigger to launch Composer DAGs on new landing files.
landing_to_composer_trigger = {
  enabled                          = true
  function_name                    = "pre-data-buildtrack-dev-clf-ingesta-sap"
  runtime_service_account_id       = "cf-pre-aldesa-buildtrack-dag"
  trigger_service_account_id       = "evt-pre-aldesa-buildtrack-dag"
  pubsub_topic_name                = "pre-data-buildtrack-dev-ps-ingesta-sap-europe-west1"
  source_dir                       = "../../../../functions/clf-ingesta-sap"
  source_object_prefix             = "functions/pre-data-buildtrack-dev-clf-ingesta-sap"
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
  object_name_prefix               = ""
  retry_policy                     = "RETRY_POLICY_RETRY"
  eventarc_receiver_project_role   = true
  environment_variables = {
    DATASET_EVENT_URI  = "gs://pre-data-buildtrack-dev-ingesta-sap-europe-west1/"
    OBJECT_NAME_PREFIX = ""
  }
  # Eventarc creates the push subscription automatically.
  # Keep this block enabled from day one; leave subscription_name = null.
  # The orchestration make targets auto-discover/import the subscription after the trigger exists.
  eventarc_subscription_tuning = {
    enabled                                 = true
    subscription_name                       = null
    ack_deadline_seconds                    = 600
    minimum_backoff                         = "10s"
    maximum_backoff                         = "600s"
    dead_letter_enabled                     = true
    dead_letter_topic_name                  = "pre-data-buildtrack-dev-ps-ingesta-sap-europe-west1-dlq"
    dead_letter_subscription_name           = "pre-data-buildtrack-dev-ps-ingesta-sap-europe-west1-dlq-sub"
    dead_letter_max_delivery_attempts       = 10
    dead_letter_alert_enabled               = true
    dead_letter_alert_notification_channels = []
  }
}
