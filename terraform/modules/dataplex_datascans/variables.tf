variable "project_id" {
  description = "Target GCP project ID for Dataplex DataScans."
  type        = string
}

variable "location" {
  description = "Dataplex location (region) for DataScans."
  type        = string
}

variable "labels" {
  description = "Base labels to apply to all DataScans."
  type        = map(string)
  default     = {}
}

variable "dataset_ids_by_layer" {
  description = "BigQuery dataset ids keyed by medallion layer."
  type        = map(string)
}

variable "datascans" {
  description = "Dataplex profiling/quality scans configuration. Supports layer+table_id or resource_uri targets."
  type = object({
    profile_scans = optional(map(any))
    quality_scans = optional(map(any))
  })
  default = {}
}
