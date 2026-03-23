variable "project_id" {
  description = "Target GCP project ID for this environment."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string

  validation {
    condition     = contains(["shared", "pre", "dev", "pro"], var.environment)
    error_message = "environment must be one of: shared, pre, dev, pro."
  }
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

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.service_name))
    error_message = "service_name must contain lowercase letters, numbers and hyphens only."
  }
}

variable "additional_labels" {
  description = "Additional labels merged into default orchestration labels."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for k in keys(var.additional_labels) :
      can(regex("^[a-z][a-z0-9_-]{0,62}$", k))
    ])
    error_message = "additional_labels keys must match ^[a-z][a-z0-9_-]{0,62}$."
  }

  validation {
    condition = alltrue([
      for v in values(var.additional_labels) :
      can(regex("^[a-z0-9_-]{0,63}$", v))
    ])
    error_message = "additional_labels values must match ^[a-z0-9_-]{0,63}$."
  }

  validation {
    condition = length(setintersection(
      toset(keys(var.additional_labels)),
      toset(["component", "environment", "managed_by", "project_name"])
    )) == 0
    error_message = "additional_labels cannot redefine component, environment, managed_by or project_name."
  }
}

variable "network_self_link" {
  description = "Foundation VPC network self link used by Composer."
  type        = string
}

variable "subnetwork_self_link" {
  description = "Foundation subnetwork self link used by Composer."
  type        = string
}

variable "landing_bucket_name" {
  description = "Landing bucket name from storage-bq used for GCS notifications."
  type        = string
}

variable "bronze_parquet_bucket_name" {
  description = "Bronze parquet historical bucket name from storage-bq."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.bronze_parquet_bucket_name == null || can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bronze_parquet_bucket_name))
    error_message = "bronze_parquet_bucket_name must be a valid GCS bucket name."
  }
}

variable "composer_bigquery_access" {
  description = "Optional BigQuery IAM grants for the Composer service account."
  type = object({
    grant_job_user          = optional(bool)
    dataset_data_editor_ids = optional(list(string))
  })
  default = {}

  validation {
    condition = alltrue([
      for dataset_id in coalesce(try(var.composer_bigquery_access.dataset_data_editor_ids, null), []) :
      can(regex("^[A-Za-z_][A-Za-z0-9_]*$", dataset_id)) && length(dataset_id) <= 1024
    ])
    error_message = "composer_bigquery_access.dataset_data_editor_ids values must be valid BigQuery dataset ids."
  }
}

variable "composer_project_roles" {
  description = "Optional project-level IAM roles granted to the Composer service account."
  type        = list(string)
  default     = ["roles/dataform.admin", "roles/dataplex.editor"]

  validation {
    condition = alltrue([
      for role in var.composer_project_roles :
      can(regex("^(roles/[A-Za-z0-9_.]+|projects/[a-z][a-z0-9-]{4,28}[a-z0-9]/roles/[A-Za-z0-9_.]+|organizations/[0-9]+/roles/[A-Za-z0-9_.]+)$", role))
    ])
    error_message = "composer_project_roles must contain valid role names (roles/*, projects/*/roles/*, or organizations/*/roles/*)."
  }
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

  validation {
    condition     = try(var.landing_to_composer_trigger.function_name, null) == null || can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.landing_to_composer_trigger.function_name))
    error_message = "landing_to_composer_trigger.function_name must be a valid RFC1035 name (max 63 chars)."
  }

  validation {
    condition     = try(var.landing_to_composer_trigger.runtime_service_account_id, null) == null || can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.landing_to_composer_trigger.runtime_service_account_id))
    error_message = "landing_to_composer_trigger.runtime_service_account_id must be a valid service account id (6-30 chars)."
  }

  validation {
    condition     = try(var.landing_to_composer_trigger.trigger_service_account_id, null) == null || can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.landing_to_composer_trigger.trigger_service_account_id))
    error_message = "landing_to_composer_trigger.trigger_service_account_id must be a valid service account id (6-30 chars)."
  }

  validation {
    condition     = try(var.landing_to_composer_trigger.pubsub_topic_name, null) == null || can(regex("^[A-Za-z][A-Za-z0-9._~+%-]{2,254}$", var.landing_to_composer_trigger.pubsub_topic_name))
    error_message = "landing_to_composer_trigger.pubsub_topic_name must be a valid Pub/Sub topic id."
  }

  validation {
    condition = (
      try(var.landing_to_composer_trigger.retry_policy, null) == null ||
      contains(["RETRY_POLICY_RETRY", "RETRY_POLICY_DO_NOT_RETRY"], var.landing_to_composer_trigger.retry_policy)
    )
    error_message = "landing_to_composer_trigger.retry_policy must be RETRY_POLICY_RETRY or RETRY_POLICY_DO_NOT_RETRY."
  }

  validation {
    condition = (
      try(var.landing_to_composer_trigger.available_memory, null) == null ||
      contains(["128M", "256M", "512M", "1G", "2G", "4G", "8G", "16G", "32G"], var.landing_to_composer_trigger.available_memory)
    )
    error_message = "landing_to_composer_trigger.available_memory must be one of the supported Cloud Functions Gen2 memory values."
  }

  validation {
    condition = (
      try(var.landing_to_composer_trigger.max_instance_request_concurrency, null) == null ||
      (
        var.landing_to_composer_trigger.max_instance_request_concurrency >= 1 &&
        var.landing_to_composer_trigger.max_instance_request_concurrency <= 1000
      )
    )
    error_message = "landing_to_composer_trigger.max_instance_request_concurrency must be between 1 and 1000."
  }

  validation {
    condition = (
      try(var.landing_to_composer_trigger.ingress_settings, null) == null ||
      contains(["ALLOW_ALL", "ALLOW_INTERNAL_ONLY", "ALLOW_INTERNAL_AND_GCLB"], var.landing_to_composer_trigger.ingress_settings)
    )
    error_message = "landing_to_composer_trigger.ingress_settings must be ALLOW_ALL, ALLOW_INTERNAL_ONLY or ALLOW_INTERNAL_AND_GCLB."
  }

  validation {
    condition = (
      try(var.landing_to_composer_trigger.eventarc_subscription_tuning.ack_deadline_seconds, null) == null ||
      (
        var.landing_to_composer_trigger.eventarc_subscription_tuning.ack_deadline_seconds >= 10 &&
        var.landing_to_composer_trigger.eventarc_subscription_tuning.ack_deadline_seconds <= 600
      )
    )
    error_message = "landing_to_composer_trigger.eventarc_subscription_tuning.ack_deadline_seconds must be between 10 and 600."
  }
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

  validation {
    condition     = try(var.composer.environment_name, null) == null || can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.composer.environment_name))
    error_message = "composer.environment_name must be a valid RFC1035 name (max 63 chars)."
  }

  validation {
    condition     = try(var.composer.service_account_id, null) == null || can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.composer.service_account_id))
    error_message = "composer.service_account_id must be a valid service account id (6-30 chars)."
  }

  validation {
    condition = (
      try(var.composer.environment_size, null) == null ||
      contains([
        "ENVIRONMENT_SIZE_SMALL",
        "ENVIRONMENT_SIZE_MEDIUM",
        "ENVIRONMENT_SIZE_LARGE",
        "ENVIRONMENT_SIZE_EXTRA_LARGE",
      ], var.composer.environment_size)
    )
    error_message = "composer.environment_size must be ENVIRONMENT_SIZE_SMALL, ENVIRONMENT_SIZE_MEDIUM, ENVIRONMENT_SIZE_LARGE or ENVIRONMENT_SIZE_EXTRA_LARGE."
  }

  validation {
    condition     = try(var.composer.internal_ipv4_cidr_block, null) == null || can(cidrhost(var.composer.internal_ipv4_cidr_block, 0))
    error_message = "composer.internal_ipv4_cidr_block must be a valid CIDR range."
  }

  validation {
    condition = (
      (try(var.composer.worker_min_count, null) == null && try(var.composer.worker_max_count, null) == null) ||
      (try(var.composer.worker_min_count, null) != null && try(var.composer.worker_max_count, null) != null)
    )
    error_message = "composer.worker_min_count and composer.worker_max_count must be set together."
  }

  validation {
    condition     = try(var.composer.worker_min_count, null) == null || var.composer.worker_min_count >= 0
    error_message = "composer.worker_min_count must be greater than or equal to 0."
  }

  validation {
    condition     = try(var.composer.worker_max_count, null) == null || var.composer.worker_max_count >= 1
    error_message = "composer.worker_max_count must be greater than or equal to 1."
  }

  validation {
    condition = (
      try(var.composer.worker_min_count, null) == null ||
      try(var.composer.worker_max_count, null) == null ||
      var.composer.worker_max_count >= var.composer.worker_min_count
    )
    error_message = "composer.worker_max_count must be greater than or equal to composer.worker_min_count."
  }

  validation {
    condition = (
      try(var.composer.scheduler_count, null) == null ||
      var.composer.scheduler_count >= 1
    )
    error_message = "composer.scheduler_count must be greater than or equal to 1."
  }

  validation {
    condition = (
      try(var.composer.dag_processor_count, null) == null ||
      var.composer.dag_processor_count >= 1
    )
    error_message = "composer.dag_processor_count must be greater than or equal to 1."
  }

  validation {
    condition = (
      try(var.composer.triggerer_count, null) == null ||
      var.composer.triggerer_count >= 1
    )
    error_message = "composer.triggerer_count must be greater than or equal to 1."
  }

  validation {
    condition = alltrue([
      for value in [
        try(var.composer.scheduler_cpu, null),
        try(var.composer.scheduler_memory_gb, null),
        try(var.composer.scheduler_storage_gb, null),
        try(var.composer.dag_processor_cpu, null),
        try(var.composer.dag_processor_memory_gb, null),
        try(var.composer.dag_processor_storage_gb, null),
        try(var.composer.triggerer_cpu, null),
        try(var.composer.triggerer_memory_gb, null),
        try(var.composer.web_server_cpu, null),
        try(var.composer.web_server_memory_gb, null),
        try(var.composer.web_server_storage_gb, null),
        try(var.composer.worker_cpu, null),
        try(var.composer.worker_memory_gb, null),
        try(var.composer.worker_storage_gb, null),
      ] : value == null || value > 0
    ])
    error_message = "composer workload CPU/memory/storage values must be greater than 0 when set."
  }
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

  validation {
    condition     = try(var.dags_bucket.name, null) == null || can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.dags_bucket.name))
    error_message = "dags_bucket.name must be a valid GCS bucket name."
  }

  validation {
    condition = (
      try(var.dags_bucket.public_access_prevention, null) == null ||
      contains(["enforced", "inherited"], lower(var.dags_bucket.public_access_prevention))
    )
    error_message = "dags_bucket.public_access_prevention must be either enforced or inherited."
  }
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

  validation {
    condition     = try(var.dataform.repository_name, null) == null || can(regex("^[a-z][a-z0-9-]{2,62}$", var.dataform.repository_name))
    error_message = "dataform.repository_name must be a valid Dataform repository id."
  }

  validation {
    condition     = try(var.dataform.execution_service_account_id, null) == null || can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.dataform.execution_service_account_id))
    error_message = "dataform.execution_service_account_id must be a valid service account id (6-30 chars)."
  }

  validation {
    condition     = try(var.dataform.git_remote_url, null) == null || can(regex("^https://[^\\s]+\\.git$", var.dataform.git_remote_url))
    error_message = "dataform.git_remote_url must be an HTTPS URL ending in .git."
  }

  validation {
    condition     = try(var.dataform.git_remote_default_branch, null) == null || can(regex("^[^\\s]+$", var.dataform.git_remote_default_branch))
    error_message = "dataform.git_remote_default_branch cannot contain whitespace."
  }

  validation {
    condition     = try(var.dataform.git_token_secret_name, null) == null || can(regex("^[A-Za-z0-9_-]{1,255}$", var.dataform.git_token_secret_name))
    error_message = "dataform.git_token_secret_name must be a valid Secret Manager secret id."
  }

  validation {
    condition = (
      try(var.dataform.git_token_secret_version, null) == null ||
      can(regex("^[A-Za-z0-9_-]{1,255}$", var.dataform.git_token_secret_version))
    )
    error_message = "dataform.git_token_secret_version must be a valid Secret Manager version id or alias (for example: latest, 1)."
  }

  validation {
    condition     = try(var.dataform.release_config.name, null) == null || can(regex("^[a-z][a-z0-9-]{2,62}$", var.dataform.release_config.name))
    error_message = "dataform.release_config.name must be a valid Dataform release config id."
  }

  validation {
    condition     = try(var.dataform.workflow_config.name, null) == null || can(regex("^[a-z][a-z0-9-]{2,62}$", var.dataform.workflow_config.name))
    error_message = "dataform.workflow_config.name must be a valid Dataform workflow config id."
  }

  validation {
    condition = (
      try(var.dataform.release_config.code_compilation_config.default_schema, null) == null ||
      can(regex("^[A-Za-z_][A-Za-z0-9_]*$", var.dataform.release_config.code_compilation_config.default_schema))
    )
    error_message = "dataform.release_config.code_compilation_config.default_schema must be a valid BigQuery dataset id."
  }

  validation {
    condition = (
      try(var.dataform.release_config.code_compilation_config.assertion_schema, null) == null ||
      can(regex("^[A-Za-z_][A-Za-z0-9_]*$", var.dataform.release_config.code_compilation_config.assertion_schema))
    )
    error_message = "dataform.release_config.code_compilation_config.assertion_schema must be a valid BigQuery dataset id."
  }
}
