variable "project_id" {
  description = "Target GCP project ID."
  type        = string
}

variable "member" {
  description = "IAM member (for example: serviceAccount:... )."
  type        = string
}

variable "roles" {
  description = "Project-level IAM roles to bind to member."
  type        = list(string)
}
