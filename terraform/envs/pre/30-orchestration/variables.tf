variable "project_id" {
  description = "Target GCP project ID for this environment."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, pro)."
  type        = string
}

variable "region" {
  description = "Primary region for orchestration resources."
  type        = string
  default     = "europe-west1"
}

variable "service_name" {
  description = "Service identifier used in naming conventions."
  type        = string
  default     = "aldesa-buildtrack"
}

variable "additional_labels" {
  description = "Additional labels merged into default orchestration labels."
  type        = map(string)
  default     = {}
}

variable "foundation_remote_state" {
  description = "Remote-state settings used to read foundation outputs."
  type = object({
    bucket            = optional(string)
    foundation_prefix = optional(string)
  })
  default = {}
}

variable "storage_bq_remote_state" {
  description = "Remote-state settings used to read storage-bq outputs."
  type = object({
    bucket            = optional(string)
    storage_bq_prefix = optional(string)
  })
  default = {}
}

variable "use_requirements_txt_pypi_packages" {
  description = "Load Composer PyPI packages from composer_requirements_file when true."
  type        = bool
  default     = false
}

variable "composer_requirements_file" {
  description = "Path to Composer requirements.txt (absolute, or relative to this env module directory)."
  type        = string
  default     = "../../../../composer/requirements.txt"
}

variable "composer" {
  description = "Composer environment settings."
  type = object({
    airflow_config_overrides   = optional(map(string))
    dag_processor_count        = optional(number)
    dag_processor_cpu          = optional(number)
    dag_processor_memory_gb    = optional(number)
    dag_processor_storage_gb   = optional(number)
    enable_private_builds_only = optional(bool)
    enable_private_environment = optional(bool)
    env_variables              = optional(map(string))
    environment_name           = optional(string)
    environment_size           = optional(string)
    image_version              = optional(string)
    internal_ipv4_cidr_block   = optional(string)
    pypi_packages              = optional(map(string))
    scheduler_count            = optional(number)
    scheduler_cpu              = optional(number)
    scheduler_memory_gb        = optional(number)
    scheduler_storage_gb       = optional(number)
    service_account_id         = optional(string)
    triggerer_count            = optional(number)
    triggerer_cpu              = optional(number)
    triggerer_memory_gb        = optional(number)
    web_server_cpu             = optional(number)
    web_server_memory_gb       = optional(number)
    web_server_storage_gb      = optional(number)
    worker_cpu                 = optional(number)
    worker_max_count           = optional(number)
    worker_memory_gb           = optional(number)
    worker_min_count           = optional(number)
    worker_storage_gb          = optional(number)
  })
  default = {}
}

variable "composer_bigquery_access" {
  description = "Optional BigQuery IAM grants for the Composer service account."
  type = object({
    grant_job_user          = optional(bool)
    dataset_data_editor_ids = optional(list(string))
  })
  default = {}
}

variable "dags_bucket" {
  description = "Custom DAG bucket settings for Composer."
  type = object({
    force_destroy            = optional(bool)
    location                 = optional(string)
    name                     = optional(string)
    public_access_prevention = optional(string)
    storage_class            = optional(string)
    versioning_enabled       = optional(bool)
  })
  default = {}
}

variable "dataform" {
  description = "Dataform repository, secret and scheduling settings."
  type = object({
    enabled                      = optional(bool)
    execution_service_account_id = optional(string)
    git_remote_default_branch    = optional(string)
    git_remote_url               = optional(string)
    git_token_secret_name        = optional(string)
    git_token_secret_version     = optional(string)
    release_config = optional(object({
      cron_schedule = optional(string)
      enabled       = optional(bool)
      git_commitish = optional(string)
      name          = optional(string)
      time_zone     = optional(string)
      code_compilation_config = optional(object({
        assertion_schema = optional(string)
        database_suffix  = optional(string)
        default_database = optional(string)
        default_location = optional(string)
        default_schema   = optional(string)
        schema_suffix    = optional(string)
        table_prefix     = optional(string)
        vars             = optional(map(string))
      }))
    }))
    repository_name = optional(string)
    workflow_config = optional(object({
      cron_schedule = optional(string)
      enabled       = optional(bool)
      name          = optional(string)
      time_zone     = optional(string)
    }))
  })
  default = {}
}

variable "landing_to_composer_trigger" {
  description = "Optional GCS->Pub/Sub->Cloud Function trigger that launches Composer DAGs."
  type = object({
    enabled                          = optional(bool)
    function_name                    = optional(string)
    runtime_service_account_id       = optional(string)
    trigger_service_account_id       = optional(string)
    pubsub_topic_name                = optional(string)
    source_dir                       = optional(string)
    source_object_prefix             = optional(string)
    source_archive_bucket_name       = optional(string)
    entry_point                      = optional(string)
    runtime                          = optional(string)
    available_cpu                    = optional(string)
    available_memory                 = optional(string)
    timeout_seconds                  = optional(number)
    min_instance_count               = optional(number)
    max_instance_count               = optional(number)
    max_instance_request_concurrency = optional(number)
    ingress_settings                 = optional(string)
    object_name_prefix               = optional(string)
    retry_policy                     = optional(string)
    environment_variables            = optional(map(string))
    eventarc_receiver_project_role   = optional(bool)
    eventarc_subscription_tuning = optional(object({
      enabled              = optional(bool)
      subscription_name    = optional(string)
      ack_deadline_seconds = optional(number)
      minimum_backoff      = optional(string)
      maximum_backoff      = optional(string)
    }))
  })
  default = {}
}

variable "landing_to_composer_trigger_eventarc_subscription_name_override" {
  description = "Auto-discovered Eventarc Pub/Sub subscription name injected by make automation (do not set manually unless needed)."
  type        = string
  default     = null
}
