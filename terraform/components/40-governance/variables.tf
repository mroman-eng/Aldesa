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
  description = "Primary region for Dataplex DataScans."
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
  description = "Additional labels merged into default governance labels."
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

variable "source_resources" {
  description = "BigQuery dataset ids used as DataScan targets by medallion layer."
  type = object({
    raw_dataset_id    = string
    bronze_dataset_id = string
    silver_dataset_id = string
    gold_dataset_id   = string
  })

  validation {
    condition = alltrue([
      for dataset_id in [
        var.source_resources.raw_dataset_id,
        var.source_resources.bronze_dataset_id,
        var.source_resources.silver_dataset_id,
        var.source_resources.gold_dataset_id,
      ] :
      can(regex("^[A-Za-z_][A-Za-z0-9_]*$", dataset_id)) && length(dataset_id) <= 1024
    ])
    error_message = "source_resources dataset ids must follow BigQuery dataset naming rules."
  }

  validation {
    condition = length(toset([
      var.source_resources.raw_dataset_id,
      var.source_resources.bronze_dataset_id,
      var.source_resources.silver_dataset_id,
      var.source_resources.gold_dataset_id,
    ])) == 4
    error_message = "source_resources raw/bronze/silver/gold dataset ids must be unique."
  }
}

variable "dataplex_datascans" {
  description = "Dataplex Data Profile/Data Quality scans configuration keyed by scan id."
  type = object({
    profile_scans = optional(map(any))
    quality_scans = optional(map(any))
  })
  default = {}
}

variable "auto_profile_scans" {
  description = "Automatic Dataplex profile scan generation settings."
  type = object({
    enabled        = optional(bool)
    include_layers = optional(list(string))
  })
  default = {}

  validation {
    condition = alltrue([
      for layer in coalesce(try(var.auto_profile_scans.include_layers, null), ["raw", "bronze", "silver"]) :
      contains(["raw", "bronze", "silver", "gold"], layer)
    ])
    error_message = "auto_profile_scans.include_layers can contain only: raw, bronze, silver, gold."
  }
}

variable "auto_profile_scan_table_ids_by_layer" {
  description = "Table ids discovered per medallion layer and used to auto-create profile scans."
  type = object({
    raw    = optional(list(string))
    bronze = optional(list(string))
    silver = optional(list(string))
    gold   = optional(list(string))
  })
  default = {}
}
