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
  description = "Default region/location used for Cloud Build triggers."
  type        = string
  default     = "europe-west1"
}

variable "service_name" {
  description = "Project/service identifier used in naming conventions."
  type        = string
  default     = "aldesa-buildtrack"
}

variable "terraform_service_account_email" {
  description = "Terraform deployer service account email (pre-created by project owners and wired from bootstrap/override)."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+@[a-z0-9-]+\\.iam\\.gserviceaccount\\.com$", var.terraform_service_account_email))
    error_message = "terraform_service_account_email must be a valid service account email."
  }
}

variable "dags_bucket_name" {
  description = "Composer DAG bucket used by the DAG sync pipeline."
  type        = string

  validation {
    condition     = length(trimspace(var.dags_bucket_name)) > 0
    error_message = "dags_bucket_name must not be empty."
  }
}

variable "cloudbuild" {
  description = "Cloud Build CI/CD configuration (triggers remain optional until the GitHub repo is connected in GCP)."
  type = object({
    enabled                                                      = optional(bool)
    trigger_location                                             = optional(string)
    repository_resource_name                                     = optional(string)
    default_trigger_disabled                                     = optional(bool)
    grant_cloudbuild_service_agent_impersonation_on_terraform_sa = optional(bool)
    grant_logging_log_writer_on_terraform_sa                     = optional(bool)
    github_pat_secret_name                                       = optional(string)
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

  validation {
    condition = alltrue([
      for t in try(var.cloudbuild.triggers, []) :
      contains(["PUSH", "PULL_REQUEST"], upper(t.event))
    ])
    error_message = "cloudbuild.triggers[*].event must be PUSH or PULL_REQUEST."
  }

  validation {
    condition = alltrue([
      for t in try(var.cloudbuild.triggers, []) :
      try(t.service_account_ref, null) == null || contains(["default", "terraform", "dags_sync"], lower(t.service_account_ref))
    ])
    error_message = "cloudbuild.triggers[*].service_account_ref must be one of: default, terraform, dags_sync."
  }

  validation {
    condition = alltrue([
      for t in try(var.cloudbuild.triggers, []) :
      try(t.comment_control, null) == null || contains(["COMMENTS_DISABLED", "COMMENTS_ENABLED", "COMMENTS_ENABLED_FOR_EXTERNAL_CONTRIBUTORS_ONLY"], upper(t.comment_control))
    ])
    error_message = "cloudbuild.triggers[*].comment_control must be a valid Cloud Build PR comment control value."
  }

  validation {
    condition = (
      try(var.cloudbuild.dags_sync_pipeline.service_account_id, null) == null ||
      can(regex("^[a-z]([-a-z0-9]{4,28}[a-z0-9])$", var.cloudbuild.dags_sync_pipeline.service_account_id))
    )
    error_message = "cloudbuild.dags_sync_pipeline.service_account_id must be a valid Google service account account_id (6-30 chars, lowercase, hyphen allowed)."
  }
}
