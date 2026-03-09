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
