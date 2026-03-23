variable "project_id" {
  description = "Target GCP project ID for this environment."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "region" {
  description = "Primary region for dev resources."
  type        = string
  default     = "europe-west1"
}

variable "service_name" {
  description = "Service identifier used in naming conventions."
  type        = string
  default     = "aldesa-buildtrack"
}

variable "additional_labels" {
  description = "Additional labels merged into default labels."
  type        = map(string)
  default     = {}
}

variable "dev_enabled" {
  description = "Whether the dev stack should exist."
  type        = bool
  default     = false
}

variable "foundation_remote_state" {
  description = "Remote-state settings used to read shared foundation outputs."
  type = object({
    bucket            = optional(string)
    foundation_prefix = optional(string)
  })
  default = {}
}

variable "use_requirements_txt_pypi_packages" {
  description = "Load Composer PyPI packages from composer_requirements_file when true."
  type        = bool
  default     = false
}

variable "composer_requirements_file" {
  description = "Path to Composer requirements.txt (absolute, or relative to this env directory)."
  type        = string
  default     = "../../../composer/requirements.txt"
}

variable "landing_bucket" {
  description = "Landing bucket settings."
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

variable "bronze_parquet_bucket" {
  description = "Bronze parquet historical bucket settings."
  type = object({
    delete_noncurrent_versions_after_days = optional(number)
    force_destroy                         = optional(bool)
    location                              = optional(string)
    name                                  = optional(string)
    public_access_prevention              = optional(string)
    storage_class                         = optional(string)
    versioning_enabled                    = optional(bool)
  })
  default = {}
}

variable "bigquery_location_override" {
  description = "Optional override for BigQuery datasets location."
  type        = string
  default     = null
  nullable    = true
}

variable "dataset_ids" {
  description = "Dataset ids keyed by data layer."
  type = object({
    alerts = optional(string)
    logs   = optional(string)
    raw    = optional(string)
    bronze = optional(string)
    silver = optional(string)
    gold   = optional(string)
  })
  default = {}
}

variable "bq_dataset_delete_contents_on_destroy" {
  description = "Delete all tables/views before deleting datasets."
  type        = bool
  default     = false
}

variable "bq_default_table_expiration_ms" {
  description = "Optional default table expiration applied to managed datasets."
  type        = number
  default     = null
  nullable    = true
}

variable "bq_table_deletion_protection" {
  description = "Enable deletion protection for managed tables."
  type        = bool
  default     = false
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

variable "composer_project_roles" {
  description = "Optional project-level IAM roles granted to the Composer service account."
  type        = list(string)
  default     = []
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
