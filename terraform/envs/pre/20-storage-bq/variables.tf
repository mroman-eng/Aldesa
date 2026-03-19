variable "project_id" {
  description = "Target GCP project ID for this environment."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, pro)."
  type        = string
}

variable "region" {
  description = "Primary region for storage and BigQuery resources."
  type        = string
  default     = "europe-west1"
}

variable "service_name" {
  description = "Service identifier used in naming conventions."
  type        = string
  default     = "aldesa-buildtrack"
}

variable "additional_labels" {
  description = "Additional labels merged into default storage-bq labels."
  type        = map(string)
  default     = {}
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

  validation {
    condition     = try(var.landing_bucket.name, null) == null || can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.landing_bucket.name))
    error_message = "landing_bucket.name must be a valid GCS bucket name."
  }
}

variable "enable_datasphere_ingest_service_account" {
  description = "Create a dedicated service account for SAP Datasphere parquet ingestion."
  type        = bool
  default     = true
}

variable "datasphere_ingest_sa_id_override" {
  description = "Optional override for SAP Datasphere ingestion service account id."
  type        = string
  default     = null
  nullable    = true
}

variable "datasphere_ingest_sa_key_secret_id_override" {
  description = "Optional override for the SAP Datasphere service account key secret id."
  type        = string
  default     = null
  nullable    = true
}

variable "datasphere_landing_bucket_roles" {
  description = "Optional extra IAM roles granted to the SAP Datasphere ingestion service account on the landing bucket."
  type        = list(string)
  default     = []
}

variable "enable_dataform_git_token_secret" {
  description = "Create Secret Manager secret container for Dataform Git token."
  type        = bool
  default     = true
}

variable "dataform_git_token_secret_id_override" {
  description = "Optional override for Dataform Git token secret id."
  type        = string
  default     = null
  nullable    = true
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
    gold   = optional(string)
    silver = optional(string)
  })
  default = {}

  validation {
    condition = alltrue([
      for dataset_id in [
        try(var.dataset_ids.alerts, null),
        try(var.dataset_ids.logs, null),
        try(var.dataset_ids.raw, null),
        try(var.dataset_ids.bronze, null),
        try(var.dataset_ids.silver, null),
        try(var.dataset_ids.gold, null),
      ] :
      dataset_id == null || (can(regex("^[A-Za-z_][A-Za-z0-9_]*$", dataset_id)) && length(dataset_id) <= 1024)
    ])
    error_message = "dataset_ids values must follow BigQuery dataset naming rules."
  }
}

variable "table_schema_dir_override" {
  description = "Optional override for base directory containing per-layer schema subdirectories (raw/bronze/silver/gold/alerts/logs)."
  type        = string
  default     = null
  nullable    = true
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

variable "raw_tables" {
  description = "Raw table definitions keyed by table id (schema is loaded from bq_table_schemas/raw/<table_id>.json)."
  type = map(object({
    description = optional(string, null)
    create_view = optional(bool, false)
    time_partitioning = optional(object({
      type          = optional(string, "DAY")
      field         = optional(string, null)
      expiration_ms = optional(number, null)
    }), null)
    clustering_fields        = optional(list(string), [])
    require_partition_filter = optional(bool, false)
  }))
  default = {}
}

variable "bronze_tables" {
  description = "Bronze table definitions keyed by table id (schema is loaded from bq_table_schemas/bronze/<table_id>.json)."
  type = map(object({
    description = optional(string, null)
    create_view = optional(bool, false)
    time_partitioning = optional(object({
      type          = optional(string, "DAY")
      field         = optional(string, null)
      expiration_ms = optional(number, null)
    }), null)
    clustering_fields        = optional(list(string), [])
    require_partition_filter = optional(bool, false)
  }))
  default = {}
}

variable "silver_tables" {
  description = "Silver table definitions keyed by table id (schema is loaded from bq_table_schemas/silver/<table_id>.json)."
  type = map(object({
    description = optional(string, null)
    create_view = optional(bool, false)
    time_partitioning = optional(object({
      type          = optional(string, "DAY")
      field         = optional(string, null)
      expiration_ms = optional(number, null)
    }), null)
    clustering_fields        = optional(list(string), [])
    require_partition_filter = optional(bool, false)
  }))
  default = {}
}

variable "gold_tables" {
  description = "Gold table definitions keyed by table id (schema is loaded from bq_table_schemas/gold/<table_id>.json)."
  type = map(object({
    description = optional(string, null)
    create_view = optional(bool, false)
    time_partitioning = optional(object({
      type          = optional(string, "DAY")
      field         = optional(string, null)
      expiration_ms = optional(number, null)
    }), null)
    clustering_fields        = optional(list(string), [])
    require_partition_filter = optional(bool, false)
  }))
  default = {}
}

variable "alerts_tables" {
  description = "Alerts table definitions keyed by table id (schema is loaded from bq_table_schemas/alerts/<table_id>.json)."
  type = map(object({
    description = optional(string, null)
    create_view = optional(bool, false)
    time_partitioning = optional(object({
      type          = optional(string, "DAY")
      field         = optional(string, null)
      expiration_ms = optional(number, null)
    }), null)
    clustering_fields        = optional(list(string), [])
    require_partition_filter = optional(bool, false)
  }))
  default = {}
}

variable "logs_tables" {
  description = "Logs table definitions keyed by table id (schema is loaded from bq_table_schemas/logs/<table_id>.json)."
  type = map(object({
    description = optional(string, null)
    create_view = optional(bool, false)
    time_partitioning = optional(object({
      type          = optional(string, "DAY")
      field         = optional(string, null)
      expiration_ms = optional(number, null)
    }), null)
    clustering_fields        = optional(list(string), [])
    require_partition_filter = optional(bool, false)
  }))
  default = {}
}
