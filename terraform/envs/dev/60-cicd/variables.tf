variable "project_id" {
  description = "Target GCP project ID for this environment."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, pro)."
  type        = string
}

variable "region" {
  description = "Primary region/location for Cloud Build triggers."
  type        = string
  default     = "europe-west1"
}

variable "service_name" {
  description = "Service identifier used in naming conventions."
  type        = string
  default     = "aldesa-buildtrack"
}

variable "bootstrap_remote_state" {
  description = "Remote-state settings used to read bootstrap outputs."
  type = object({
    bucket           = optional(string)
    bootstrap_prefix = optional(string)
  })
  default = {}
}

variable "orchestration_remote_state" {
  description = "Remote-state settings used to read orchestration outputs."
  type = object({
    bucket               = optional(string)
    orchestration_prefix = optional(string)
  })
  default = {}
}

variable "cicd_dependencies" {
  description = "Optional overrides for CI/CD dependencies resolved from remote state."
  type = object({
    terraform_service_account_email = optional(string)
    dags_bucket_name                = optional(string)
  })
  default = {}
}

variable "cloudbuild" {
  description = "Cloud Build CI/CD settings (identities + optional triggers)."
  type = object({
    enabled                                                      = optional(bool)
    trigger_location                                             = optional(string)
    repository_resource_name                                     = optional(string)
    github_pat_secret_name                                       = optional(string)
    grant_cloudbuild_service_agent_impersonation_on_terraform_sa = optional(bool)
    grant_logging_log_writer_on_terraform_sa                     = optional(bool)
    dags_sync_pipeline = optional(object({
      enabled                    = optional(bool)
      service_account_id         = optional(string)
      display_name               = optional(string)
      grant_storage_object_admin = optional(bool)
      grant_logging_log_writer   = optional(bool)
    }))
    triggers = optional(list(object({
      name                     = string
      description              = optional(string)
      enabled                  = optional(bool)
      disabled                 = optional(bool)
      location                 = optional(string)
      repository_resource_name = optional(string)
      event                    = string
      branch_regex             = optional(string)
      tag_regex                = optional(string)
      invert_regex             = optional(bool)
      comment_control          = optional(string)
      require_approval         = optional(bool)
      filename                 = string
      included_files           = optional(list(string))
      ignored_files            = optional(list(string))
      substitutions            = optional(map(string))
      tags                     = optional(list(string))
      service_account_ref      = optional(string)
      service_account_email    = optional(string)
    })))
  })
  default = {}
}
