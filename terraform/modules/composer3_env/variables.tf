variable "name" {
  description = "Cloud Composer environment name."
  type        = string
}

variable "project_id" {
  description = "Target GCP project ID."
  type        = string
}

variable "region" {
  description = "Composer region."
  type        = string
}

variable "network" {
  description = "VPC network self link for Composer nodes."
  type        = string
}

variable "subnetwork" {
  description = "Subnetwork self link for Composer nodes."
  type        = string
}

variable "service_account_email" {
  description = "User-managed service account email used by Composer."
  type        = string
}

variable "dags_bucket_name" {
  description = "Custom DAG bucket name for Composer storage_config.bucket."
  type        = string
}

variable "composer_image_version" {
  description = "Composer image version (for example, composer-3-airflow-2)."
  type        = string
}

variable "environment_size" {
  description = "Composer environment size."
  type        = string
  default     = "ENVIRONMENT_SIZE_SMALL"

  validation {
    condition = contains([
      "ENVIRONMENT_SIZE_SMALL",
      "ENVIRONMENT_SIZE_MEDIUM",
      "ENVIRONMENT_SIZE_LARGE",
    ], var.environment_size)
    error_message = "environment_size must be ENVIRONMENT_SIZE_SMALL, ENVIRONMENT_SIZE_MEDIUM or ENVIRONMENT_SIZE_LARGE."
  }
}

variable "worker_min_count" {
  description = "Minimum number of Airflow workers for Composer autoscaling. Set with worker_max_count."
  type        = number
  default     = null
}

variable "worker_max_count" {
  description = "Maximum number of Airflow workers for Composer autoscaling. Set with worker_min_count."
  type        = number
  default     = null
}

variable "enable_private_environment" {
  description = "Enable private IP environment in Composer."
  type        = bool
  default     = true
}

variable "enable_private_builds_only" {
  description = "Restrict build connectivity to private networking only."
  type        = bool
  default     = false
}

variable "composer_internal_ipv4_cidr_block" {
  description = "Composer internal IPv4 range in CIDR notation (for example, 100.64.128.0/20)."
  type        = string
  default     = "100.64.128.0/20"

  validation {
    condition     = can(cidrhost(var.composer_internal_ipv4_cidr_block, 0))
    error_message = "composer_internal_ipv4_cidr_block must be a valid CIDR block."
  }
}

variable "airflow_config_overrides" {
  description = "Airflow configuration overrides."
  type        = map(string)
  default     = {}
}

variable "env_variables" {
  description = "Environment variables for Composer workers."
  type        = map(string)
  default     = {}
}

variable "pypi_packages" {
  description = "PyPI packages installed in Composer."
  type        = map(string)
  default     = {}
}

variable "labels" {
  description = "Labels applied to the Composer environment."
  type        = map(string)
  default     = {}
}
