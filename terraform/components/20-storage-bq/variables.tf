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
  description = "Primary region for storage and BigQuery resources."
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
  description = "Additional labels merged into default storage-bq labels."
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

  validation {
    condition = (
      try(var.landing_bucket.public_access_prevention, null) == null ||
      contains(["enforced", "inherited"], lower(var.landing_bucket.public_access_prevention))
    )
    error_message = "landing_bucket.public_access_prevention must be either enforced or inherited."
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

  validation {
    condition     = var.datasphere_ingest_sa_id_override == null || can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.datasphere_ingest_sa_id_override))
    error_message = "datasphere_ingest_sa_id_override must be a valid service account id (6-30 chars)."
  }
}

variable "datasphere_ingest_sa_key_secret_id_override" {
  description = "Optional override for the SAP Datasphere service account key secret id."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.datasphere_ingest_sa_key_secret_id_override == null || can(regex("^[A-Za-z0-9_-]{1,255}$", var.datasphere_ingest_sa_key_secret_id_override))
    error_message = "datasphere_ingest_sa_key_secret_id_override must be a valid Secret Manager secret id."
  }
}

variable "datasphere_landing_bucket_roles" {
  description = "Optional extra IAM roles granted to the SAP Datasphere ingestion service account on the landing bucket."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for role in var.datasphere_landing_bucket_roles : can(regex("^(roles/[A-Za-z0-9_.]+|projects/[a-z][a-z0-9-]{4,28}[a-z0-9]/roles/[A-Za-z0-9_.]+|organizations/[0-9]+/roles/[A-Za-z0-9_.]+)$", role))
    ])
    error_message = "datasphere_landing_bucket_roles must contain valid role names (roles/*, projects/*/roles/*, or organizations/*/roles/*)."
  }
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

  validation {
    condition     = var.dataform_git_token_secret_id_override == null || can(regex("^[A-Za-z0-9_-]{1,255}$", var.dataform_git_token_secret_id_override))
    error_message = "dataform_git_token_secret_id_override must be a valid Secret Manager secret id."
  }
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

  validation {
    condition = length(compact([
      try(var.dataset_ids.raw, null),
      try(var.dataset_ids.logs, null),
      try(var.dataset_ids.bronze, null),
      try(var.dataset_ids.silver, null),
      try(var.dataset_ids.gold, null),
      try(var.dataset_ids.alerts, null),
      ])) == length(toset(compact([
        try(var.dataset_ids.alerts, null),
        try(var.dataset_ids.logs, null),
        try(var.dataset_ids.raw, null),
        try(var.dataset_ids.bronze, null),
        try(var.dataset_ids.silver, null),
        try(var.dataset_ids.gold, null),
    ])))
    error_message = "dataset_ids values must be unique when provided."
  }
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
  description = "Raw table definitions keyed by table id."
  type = map(object({
    schema_json = string
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
  description = "Bronze table definitions keyed by table id."
  type = map(object({
    schema_json = string
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
  description = "Silver table definitions keyed by table id."
  type = map(object({
    schema_json = string
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
  description = "Gold table definitions keyed by table id."
  type = map(object({
    schema_json = string
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
  description = "Alerts table definitions keyed by table id."
  type = map(object({
    schema_json = string
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
  description = "Logs table definitions keyed by table id."
  type = map(object({
    schema_json = string
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
