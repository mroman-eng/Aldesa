variable "project_id" {
  description = "Target GCP project ID for this environment."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, pro)."
  type        = string
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
}

variable "additional_labels" {
  description = "Additional labels merged into default bootstrap labels."
  type        = map(string)
  default     = {}
}

variable "state_bucket_name_override" {
  description = "Optional override for Terraform state bucket name."
  type        = string
  default     = null
  nullable    = true
}

variable "terraform_service_account_id_override" {
  description = "Optional override for pre-existing Terraform service account account_id (default: sa-terraform-buildtrack)."
  type        = string
  default     = null
  nullable    = true
}

variable "terraform_project_iam_custom_role_id" {
  description = "Existing custom project role id for Terraform IAM policy management (not managed by this bootstrap)."
  type        = string
  default     = "terraformIamPolicyAdmin"
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
