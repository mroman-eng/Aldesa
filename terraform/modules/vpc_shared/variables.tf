variable "project_id" {
  description = "Target GCP project ID."
  type        = string
}

variable "region" {
  description = "Region for regional networking resources."
  type        = string
}

variable "network_name" {
  description = "VPC network name."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.network_name))
    error_message = "network_name must be a valid VPC name (RFC1035, max 63 chars)."
  }
}

variable "subnetwork_name" {
  description = "Subnetwork name."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.subnetwork_name))
    error_message = "subnetwork_name must be a valid subnet name (RFC1035, max 63 chars)."
  }
}

variable "subnetwork_cidr" {
  description = "Primary CIDR range for the subnet."
  type        = string

  validation {
    condition     = can(cidrhost(var.subnetwork_cidr, 0))
    error_message = "subnetwork_cidr must be a valid CIDR range, e.g. 10.40.0.0/24."
  }
}

variable "routing_mode" {
  description = "Dynamic routing mode for the VPC."
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["GLOBAL", "REGIONAL"], var.routing_mode)
    error_message = "routing_mode must be GLOBAL or REGIONAL."
  }
}

variable "network_mtu" {
  description = "MTU for the VPC network."
  type        = number
  default     = 1460

  validation {
    condition     = var.network_mtu >= 1300 && var.network_mtu <= 8896
    error_message = "network_mtu must be between 1300 and 8896."
  }
}

variable "delete_default_routes_on_create" {
  description = "Whether to delete default internet routes after network creation."
  type        = bool
  default     = false
}

variable "private_ip_google_access" {
  description = "Enable Private Google Access in the subnet."
  type        = bool
  default     = true
}

variable "enable_subnetwork_flow_logs" {
  description = "Enable flow logs in the subnet."
  type        = bool
  default     = true
}

variable "subnetwork_flow_logs_aggregation_interval" {
  description = "Flow logs aggregation interval."
  type        = string
  default     = "INTERVAL_5_MIN"

  validation {
    condition = contains([
      "INTERVAL_5_SEC",
      "INTERVAL_30_SEC",
      "INTERVAL_1_MIN",
      "INTERVAL_5_MIN",
      "INTERVAL_10_MIN",
      "INTERVAL_15_MIN",
    ], var.subnetwork_flow_logs_aggregation_interval)
    error_message = "subnetwork_flow_logs_aggregation_interval must be a valid Compute flow-logs interval."
  }
}

variable "subnetwork_flow_logs_sampling" {
  description = "Flow logs sampling ratio in [0.0, 1.0]."
  type        = number
  default     = 0.5

  validation {
    condition     = var.subnetwork_flow_logs_sampling >= 0 && var.subnetwork_flow_logs_sampling <= 1
    error_message = "subnetwork_flow_logs_sampling must be between 0 and 1."
  }
}

variable "subnetwork_flow_logs_metadata" {
  description = "Metadata fields included in flow logs."
  type        = string
  default     = "INCLUDE_ALL_METADATA"

  validation {
    condition = contains([
      "EXCLUDE_ALL_METADATA",
      "INCLUDE_ALL_METADATA",
      "CUSTOM_METADATA",
    ], var.subnetwork_flow_logs_metadata)
    error_message = "subnetwork_flow_logs_metadata must be EXCLUDE_ALL_METADATA, INCLUDE_ALL_METADATA or CUSTOM_METADATA."
  }
}

variable "create_allow_internal_firewall" {
  description = "Create a permissive internal firewall rule for the subnet CIDR."
  type        = bool
  default     = true
}

variable "allow_internal_firewall_name" {
  description = "Optional firewall name override for the internal-allow rule."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.allow_internal_firewall_name == null || can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.allow_internal_firewall_name))
    error_message = "allow_internal_firewall_name must be null or a valid firewall rule name."
  }
}

variable "cloud_router_name" {
  description = "Cloud Router name used by Cloud NAT."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.cloud_router_name))
    error_message = "cloud_router_name must be a valid RFC1035 name."
  }
}

variable "cloud_nat_name" {
  description = "Cloud NAT name."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.cloud_nat_name))
    error_message = "cloud_nat_name must be a valid RFC1035 name."
  }
}

variable "cloud_nat_enable_logging" {
  description = "Enable Cloud NAT logging."
  type        = bool
  default     = true
}

variable "cloud_nat_logging_filter" {
  description = "Cloud NAT logging filter."
  type        = string
  default     = "ERRORS_ONLY"

  validation {
    condition     = contains(["ERRORS_ONLY", "TRANSLATIONS_ONLY", "ALL"], var.cloud_nat_logging_filter)
    error_message = "cloud_nat_logging_filter must be ERRORS_ONLY, TRANSLATIONS_ONLY or ALL."
  }
}

variable "cloud_nat_min_ports_per_vm" {
  description = "Minimum number of ports allocated per VM by Cloud NAT."
  type        = number
  default     = 64

  validation {
    condition     = var.cloud_nat_min_ports_per_vm > 0
    error_message = "cloud_nat_min_ports_per_vm must be greater than 0."
  }
}

variable "cloud_nat_endpoint_independent_mapping" {
  description = "Enable endpoint independent mapping for Cloud NAT."
  type        = bool
  default     = true
}
