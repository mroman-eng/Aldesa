variable "project_id" {
  description = "Target GCP project ID for this environment."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, pro)."
  type        = string
}

variable "region" {
  description = "Primary region for BI resources."
  type        = string
  default     = "europe-west1"
}

variable "service_name" {
  description = "Service identifier used in naming conventions."
  type        = string
  default     = "aldesa-buildtrack"
}

variable "storage_bq_remote_state" {
  description = "Remote-state settings used to read storage-bq outputs."
  type = object({
    bucket            = optional(string)
    storage_bq_prefix = optional(string)
  })
  default = {}
}

variable "bi_dependencies" {
  description = "Optional overrides for dataset consumed by BI."
  type = object({
    gold_dataset_id = optional(string)
  })
  default = {}

  validation {
    condition     = try(var.bi_dependencies.gold_dataset_id, null) == null || (can(regex("^[A-Za-z_][A-Za-z0-9_]*$", var.bi_dependencies.gold_dataset_id)) && length(var.bi_dependencies.gold_dataset_id) <= 1024)
    error_message = "bi_dependencies.gold_dataset_id must follow BigQuery dataset naming rules."
  }
}

variable "looker_studio" {
  description = "Looker Studio Pro access model over BigQuery (user_emails are converted to user: principals)."
  type = object({
    enabled                        = optional(bool)
    user_emails                    = optional(list(string))
    viewer_principals              = optional(list(string))
    grant_bigquery_job_user        = optional(bool)
    grant_gold_dataset_data_viewer = optional(bool)
  })
  default = {}

  validation {
    condition = alltrue([
      for email in coalesce(try(var.looker_studio.user_emails, null), []) :
      can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", trimspace(email)))
    ])
    error_message = "looker_studio.user_emails entries must be valid email addresses."
  }

  validation {
    condition = alltrue([
      for p in coalesce(try(var.looker_studio.viewer_principals, null), []) :
      can(regex("^(user|group|serviceAccount):.+$", p))
    ])
    error_message = "looker_studio.viewer_principals entries must use IAM member syntax (user:, group:, serviceAccount:)."
  }
}

variable "context_aware_access" {
  description = "Reference-only Context-Aware Access metadata for manual Looker Studio policy setup by an org admin."
  type = object({
    enabled                 = optional(bool)
    access_policy_id        = optional(string)
    access_level_short_name = optional(string)
    title                   = optional(string)
    allowed_ip_cidrs        = optional(list(string))
    scope                   = optional(string)
    mode                    = optional(string)
  })
  default = {}

  validation {
    condition = (
      try(var.context_aware_access.enabled, false) == false ||
      (
        try(var.context_aware_access.access_policy_id, null) != null &&
        can(regex("^accessPolicies/[0-9]+$", var.context_aware_access.access_policy_id))
      )
    )
    error_message = "context_aware_access.access_policy_id must be set as accessPolicies/<numeric_id> when enabled=true."
  }

  validation {
    condition = (
      try(var.context_aware_access.enabled, false) == false ||
      try(var.context_aware_access.access_level_short_name, null) == null ||
      can(regex("^[A-Za-z][A-Za-z0-9_]{0,49}$", var.context_aware_access.access_level_short_name))
    )
    error_message = "context_aware_access.access_level_short_name must start with a letter and contain only alphanumeric or underscore characters."
  }

  validation {
    condition = (
      try(var.context_aware_access.enabled, false) == false ||
      alltrue([for cidr in coalesce(try(var.context_aware_access.allowed_ip_cidrs, null), []) : can(cidrnetmask(cidr))])
    )
    error_message = "context_aware_access.allowed_ip_cidrs entries must be valid CIDR blocks."
  }

  validation {
    condition = (
      try(var.context_aware_access.mode, null) == null ||
      contains(["MONITOR", "ACTIVE", "WARN"], upper(var.context_aware_access.mode))
    )
    error_message = "context_aware_access.mode must be one of: MONITOR, ACTIVE, WARN."
  }
}
