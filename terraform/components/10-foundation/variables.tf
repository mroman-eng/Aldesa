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
  description = "Primary region for foundation resources."
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

variable "network" {
  description = "Foundation VPC settings."
  type = object({
    delete_default_routes_on_create = optional(bool)
    mtu                             = optional(number)
    name                            = optional(string)
    routing_mode                    = optional(string)
  })
  default = {}

  validation {
    condition     = try(var.network.name, null) == null || can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.network.name))
    error_message = "network.name must be a valid VPC name (RFC1035, max 63 chars)."
  }

  validation {
    condition = (
      try(var.network.routing_mode, null) == null ||
      contains(["GLOBAL", "REGIONAL"], upper(var.network.routing_mode))
    )
    error_message = "network.routing_mode must be GLOBAL or REGIONAL."
  }

  validation {
    condition = (
      try(var.network.mtu, null) == null ||
      (var.network.mtu >= 1300 && var.network.mtu <= 8896)
    )
    error_message = "network.mtu must be between 1300 and 8896."
  }
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

  validation {
    condition     = can(cidrhost(var.subnetwork.cidr, 0))
    error_message = "subnetwork.cidr must be a valid CIDR range, e.g. 10.40.0.0/24."
  }

  validation {
    condition     = try(var.subnetwork.name, null) == null || can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.subnetwork.name))
    error_message = "subnetwork.name must be a valid subnet name (RFC1035, max 63 chars)."
  }

  validation {
    condition = (
      try(var.subnetwork.flow_logs.aggregation_interval, null) == null ||
      contains([
        "INTERVAL_5_SEC",
        "INTERVAL_30_SEC",
        "INTERVAL_1_MIN",
        "INTERVAL_5_MIN",
        "INTERVAL_10_MIN",
        "INTERVAL_15_MIN",
      ], var.subnetwork.flow_logs.aggregation_interval)
    )
    error_message = "subnetwork.flow_logs.aggregation_interval must be a valid Compute flow-logs interval."
  }

  validation {
    condition = (
      try(var.subnetwork.flow_logs.sampling, null) == null ||
      (var.subnetwork.flow_logs.sampling >= 0 && var.subnetwork.flow_logs.sampling <= 1)
    )
    error_message = "subnetwork.flow_logs.sampling must be between 0 and 1."
  }

  validation {
    condition = (
      try(var.subnetwork.flow_logs.metadata, null) == null ||
      contains([
        "EXCLUDE_ALL_METADATA",
        "INCLUDE_ALL_METADATA",
        "CUSTOM_METADATA",
      ], var.subnetwork.flow_logs.metadata)
    )
    error_message = "subnetwork.flow_logs.metadata must be EXCLUDE_ALL_METADATA, INCLUDE_ALL_METADATA or CUSTOM_METADATA."
  }
}

variable "firewall" {
  description = "Foundation firewall settings."
  type = object({
    allow_internal_name   = optional(string)
    create_allow_internal = optional(bool)
  })
  default = {}

  validation {
    condition     = try(var.firewall.allow_internal_name, null) == null || can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.firewall.allow_internal_name))
    error_message = "firewall.allow_internal_name must be a valid firewall name (RFC1035, max 63 chars)."
  }
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

  validation {
    condition     = try(var.nat.cloud_router_name, null) == null || can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.nat.cloud_router_name))
    error_message = "nat.cloud_router_name must be a valid router name (RFC1035, max 63 chars)."
  }

  validation {
    condition     = try(var.nat.cloud_nat_name, null) == null || can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.nat.cloud_nat_name))
    error_message = "nat.cloud_nat_name must be a valid NAT name (RFC1035, max 63 chars)."
  }

  validation {
    condition = (
      try(var.nat.logging_filter, null) == null ||
      contains(["ERRORS_ONLY", "TRANSLATIONS_ONLY", "ALL"], var.nat.logging_filter)
    )
    error_message = "nat.logging_filter must be ERRORS_ONLY, TRANSLATIONS_ONLY or ALL."
  }

  validation {
    condition = (
      try(var.nat.min_ports_per_vm, null) == null ||
      var.nat.min_ports_per_vm > 0
    )
    error_message = "nat.min_ports_per_vm must be greater than 0."
  }
}
