variable "project_id" {
  description = "Target GCP project ID for this environment."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, pro)."
  type        = string
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
}

variable "additional_labels" {
  description = "Additional labels merged into default governance labels."
  type        = map(string)
  default     = {}
}

variable "storage_bq_remote_state" {
  description = "Remote-state settings used to read storage-bq outputs."
  type = object({
    bucket            = optional(string)
    storage_bq_prefix = optional(string)
  })
  default = {}
}

variable "governed_resources" {
  description = "Optional overrides for medallion dataset ids scanned by Dataplex."
  type = object({
    raw_dataset_id    = optional(string)
    bronze_dataset_id = optional(string)
    silver_dataset_id = optional(string)
    gold_dataset_id   = optional(string)
  })
  default = {}

  validation {
    condition = alltrue([
      for dataset_id in [
        try(var.governed_resources.raw_dataset_id, null),
        try(var.governed_resources.bronze_dataset_id, null),
        try(var.governed_resources.silver_dataset_id, null),
        try(var.governed_resources.gold_dataset_id, null),
      ] :
      dataset_id == null || (can(regex("^[A-Za-z_][A-Za-z0-9_]*$", dataset_id)) && length(dataset_id) <= 1024)
    ])
    error_message = "governed_resources dataset ids must follow BigQuery dataset naming rules."
  }

  validation {
    condition = length(compact([
      try(var.governed_resources.raw_dataset_id, null),
      try(var.governed_resources.bronze_dataset_id, null),
      try(var.governed_resources.silver_dataset_id, null),
      try(var.governed_resources.gold_dataset_id, null),
      ])) == length(toset(compact([
        try(var.governed_resources.raw_dataset_id, null),
        try(var.governed_resources.bronze_dataset_id, null),
        try(var.governed_resources.silver_dataset_id, null),
        try(var.governed_resources.gold_dataset_id, null),
    ])))
    error_message = "governed_resources raw/bronze/silver/gold dataset ids must be unique when provided."
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
}
