variable "project_id" {
  description = "Target GCP project ID for this environment."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string

  validation {
    condition     = contains(["dev", "pro"], var.environment)
    error_message = "environment must be one of: dev, pro."
  }
}

variable "region" {
  description = "Primary region for bootstrap resources."
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
  description = "Additional labels merged into default bootstrap labels."
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

variable "state_bucket_name_override" {
  description = "Optional override for Terraform state bucket name."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.state_bucket_name_override == null || can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name_override))
    error_message = "state_bucket_name_override must be a valid GCS bucket name (3-63 chars, lowercase letters, digits, dot or hyphen)."
  }
}

variable "terraform_service_account_id_override" {
  description = "Optional override for pre-existing Terraform service account account_id (default: sa-terraform-buildtrack)."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.terraform_service_account_id_override == null || can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.terraform_service_account_id_override))
    error_message = "terraform_service_account_id_override must match GCP service account id format (6-30 chars)."
  }
}

variable "terraform_project_iam_custom_role_id" {
  description = "Existing custom project role id for Terraform IAM policy management (not managed by this bootstrap)."
  type        = string
  default     = "terraformIamPolicyAdmin"

  validation {
    condition     = can(regex("^[A-Za-z0-9_]{3,64}$", var.terraform_project_iam_custom_role_id))
    error_message = "terraform_project_iam_custom_role_id must be 3-64 chars and use letters, numbers or underscores."
  }
}

variable "kms_key_ring_name_override" {
  description = "Optional override for KMS key ring name used for SOPS secrets."
  type        = string
  default     = null
  nullable    = true
}

variable "kms_crypto_key_name_override" {
  description = "Optional override for KMS crypto key name used for SOPS secrets."
  type        = string
  default     = null
  nullable    = true
}
