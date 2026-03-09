variable "project_id" {
  description = "Target GCP project ID."
  type        = string
}

variable "services" {
  description = "List of service APIs to enable in the project."
  type        = list(string)
}

variable "disable_on_destroy" {
  description = "Whether services should be disabled when this resource is destroyed."
  type        = bool
  default     = false
}
