variable "project_id" {
  description = "Target GCP project ID."
  type        = string
}

variable "location" {
  description = "BigQuery location."
  type        = string
}

variable "dataset_ids" {
  description = "List of BigQuery dataset ids to create."
  type        = list(string)

  validation {
    condition = alltrue([
      for dataset_id in var.dataset_ids :
      can(regex("^[A-Za-z_][A-Za-z0-9_]*$", dataset_id)) && length(dataset_id) <= 1024
    ])
    error_message = "Each dataset id must match BigQuery dataset naming rules."
  }
}

variable "delete_contents_on_destroy" {
  description = "Delete all tables/views in datasets before deleting the dataset."
  type        = bool
  default     = false
}

variable "default_table_expiration_ms" {
  description = "Optional default table expiration for datasets."
  type        = number
  default     = null
  nullable    = true
}

variable "labels" {
  description = "Labels applied to datasets."
  type        = map(string)
  default     = {}
}
