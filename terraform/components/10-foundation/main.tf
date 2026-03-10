# Local naming conventions for network foundation resources.
locals {
  network_name                    = coalesce(try(var.network.name, null), "vpc-${var.service_name}-${var.environment}")
  routing_mode                    = upper(coalesce(try(var.network.routing_mode, null), "REGIONAL"))
  network_mtu                     = coalesce(try(var.network.mtu, null), 1460)
  delete_default_routes_on_create = coalesce(try(var.network.delete_default_routes_on_create, null), false)

  subnetwork_name          = coalesce(try(var.subnetwork.name, null), "snet-${var.service_name}-${var.environment}-${var.region}-dp")
  subnetwork_cidr          = var.subnetwork.cidr
  private_ip_google_access = coalesce(try(var.subnetwork.private_ip_google_access, null), true)

  enable_subnetwork_flow_logs               = coalesce(try(var.subnetwork.flow_logs.enabled, null), true)
  subnetwork_flow_logs_aggregation_interval = coalesce(try(var.subnetwork.flow_logs.aggregation_interval, null), "INTERVAL_5_MIN")
  subnetwork_flow_logs_sampling             = coalesce(try(var.subnetwork.flow_logs.sampling, null), 0.5)
  subnetwork_flow_logs_metadata             = coalesce(try(var.subnetwork.flow_logs.metadata, null), "INCLUDE_ALL_METADATA")

  cloud_router_name                      = coalesce(try(var.nat.cloud_router_name, null), "cr-${var.service_name}-${var.environment}-${var.region}")
  cloud_nat_name                         = coalesce(try(var.nat.cloud_nat_name, null), "nat-${var.service_name}-${var.environment}-${var.region}")
  cloud_nat_enable_logging               = coalesce(try(var.nat.enable_logging, null), true)
  cloud_nat_logging_filter               = coalesce(try(var.nat.logging_filter, null), "ERRORS_ONLY")
  cloud_nat_min_ports_per_vm             = coalesce(try(var.nat.min_ports_per_vm, null), 64)
  cloud_nat_endpoint_independent_mapping = coalesce(try(var.nat.endpoint_independent_mapping, null), true)

  create_allow_internal_firewall = coalesce(try(var.firewall.create_allow_internal, null), true)
  allow_internal_firewall_name   = coalesce(try(var.firewall.allow_internal_name, null), "fw-${var.service_name}-${var.environment}-${var.region}-allow-internal")
}

# Validate generated network resource names.
check "generated_names_are_valid" {
  assert {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", local.network_name))
    error_message = "Generated network_name is invalid. Set network.name with a valid name."
  }

  assert {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", local.subnetwork_name))
    error_message = "Generated subnetwork_name is invalid. Set subnetwork.name with a valid name."
  }

  assert {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", local.cloud_router_name))
    error_message = "Generated cloud_router_name is invalid. Set nat.cloud_router_name with a valid name."
  }

  assert {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", local.cloud_nat_name))
    error_message = "Generated cloud_nat_name is invalid. Set nat.cloud_nat_name with a valid name."
  }

  assert {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", local.allow_internal_firewall_name))
    error_message = "Generated allow_internal_firewall_name is invalid. Set firewall.allow_internal_name with a valid name."
  }
}

# Provision VPC, subnet, Cloud Router, NAT and internal firewall.
module "foundation_network" {
  source = "../../modules/vpc_shared"

  project_id      = var.project_id
  region          = var.region
  network_name    = local.network_name
  subnetwork_name = local.subnetwork_name
  subnetwork_cidr = local.subnetwork_cidr

  routing_mode                    = local.routing_mode
  network_mtu                     = local.network_mtu
  delete_default_routes_on_create = local.delete_default_routes_on_create
  private_ip_google_access        = local.private_ip_google_access

  enable_subnetwork_flow_logs               = local.enable_subnetwork_flow_logs
  subnetwork_flow_logs_aggregation_interval = local.subnetwork_flow_logs_aggregation_interval
  subnetwork_flow_logs_sampling             = local.subnetwork_flow_logs_sampling
  subnetwork_flow_logs_metadata             = local.subnetwork_flow_logs_metadata

  create_allow_internal_firewall = local.create_allow_internal_firewall
  allow_internal_firewall_name   = local.allow_internal_firewall_name

  cloud_router_name                      = local.cloud_router_name
  cloud_nat_name                         = local.cloud_nat_name
  cloud_nat_enable_logging               = local.cloud_nat_enable_logging
  cloud_nat_logging_filter               = local.cloud_nat_logging_filter
  cloud_nat_min_ports_per_vm             = local.cloud_nat_min_ports_per_vm
  cloud_nat_endpoint_independent_mapping = local.cloud_nat_endpoint_independent_mapping
}
