variable "project_id" {
  description = "Target GCP project ID for this environment."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, pro)."
  type        = string
}

variable "region" {
  description = "Primary region for foundation resources."
  type        = string
  default     = "europe-west1"
}

variable "service_name" {
  description = "Service identifier used in naming conventions."
  type        = string
  default     = "aldesa-buildtrack"
}

variable "network" {
  description = "Foundation VPC settings."
  type = object({
    delete_default_routes_on_create = optional(bool)
    mtu                             = optional(number)
    name                            = optional(string)
    routing_mode                    = optional(string)
  })
  default = {}
}

variable "subnetwork" {
  description = "Foundation subnet settings."
  type = object({
    cidr = string
    flow_logs = optional(object({
      aggregation_interval = optional(string)
      enabled              = optional(bool)
      metadata             = optional(string)
      sampling             = optional(number)
    }))
    name                     = optional(string)
    private_ip_google_access = optional(bool)
  })
}

variable "firewall" {
  description = "Foundation firewall settings."
  type = object({
    allow_internal_name   = optional(string)
    create_allow_internal = optional(bool)
  })
  default = {}
}

variable "nat" {
  description = "Foundation Cloud Router and Cloud NAT settings."
  type = object({
    cloud_nat_name               = optional(string)
    cloud_router_name            = optional(string)
    enable_logging               = optional(bool)
    endpoint_independent_mapping = optional(bool)
    logging_filter               = optional(string)
    min_ports_per_vm             = optional(number)
  })
  default = {}
}
