variable "project_id" {
  description = "Target GCP project ID."
  type        = string
}

variable "tables" {
  description = "Map of BigQuery table definitions keyed by table id."
  type = map(object({
    dataset_id  = string
    table_id    = string
    schema_json = string
    description = optional(string, null)
    time_partitioning = optional(object({
      type          = optional(string, "DAY")
      field         = optional(string, null)
      expiration_ms = optional(number, null)
    }), null)
    clustering_fields        = optional(list(string), [])
    require_partition_filter = optional(bool, false)
    deletion_protection      = optional(bool, false)
    labels                   = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for table in values(var.tables) :
      table.time_partitioning == null || contains(["DAY", "HOUR", "MONTH", "YEAR"], upper(table.time_partitioning.type))
    ])
    error_message = "time_partitioning.type must be one of DAY, HOUR, MONTH or YEAR."
  }
}
