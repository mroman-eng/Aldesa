variable "project_id" {
  description = "Target GCP project ID."
  type        = string
}

variable "name" {
  description = "Bucket name. Must be globally unique."
  type        = string
}

variable "location" {
  description = "Bucket location (region or multi-region)."
  type        = string
}

variable "storage_class" {
  description = "Storage class for the bucket."
  type        = string
  default     = "STANDARD"
}

variable "force_destroy" {
  description = "Whether to allow deleting non-empty bucket."
  type        = bool
  default     = false
}

variable "versioning_enabled" {
  description = "Enable object versioning. Recommended for Terraform state."
  type        = bool
  default     = true
}

variable "delete_noncurrent_versions_after_days" {
  description = "Optional lifecycle rule that deletes noncurrent object versions after the given number of days."
  type        = number
  default     = null
  nullable    = true
}

variable "public_access_prevention" {
  description = "Public access prevention mode."
  type        = string
  default     = "enforced"
}

variable "labels" {
  description = "Labels applied to the bucket."
  type        = map(string)
  default     = {}
}
