variable "project_id" {
  description = "Target GCP project ID."
  type        = string
}

variable "location" {
  description = "KMS location."
  type        = string
}

variable "key_ring_name" {
  description = "KMS key ring name."
  type        = string
}

variable "crypto_key_name" {
  description = "KMS crypto key name."
  type        = string
}

variable "rotation_period" {
  description = "Crypto key rotation period in seconds with suffix 's'."
  type        = string
  default     = "7776000s"
}

variable "labels" {
  description = "Labels applied to KMS resources."
  type        = map(string)
  default     = {}
}
