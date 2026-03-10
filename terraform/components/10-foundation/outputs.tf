output "project_id" {
  description = "Foundation target project."
  value       = var.project_id
}

output "network_config" {
  description = "Effective foundation network configuration."
  value = {
    delete_default_routes_on_create = local.delete_default_routes_on_create
    mtu                             = local.network_mtu
    name                            = local.network_name
    routing_mode                    = local.routing_mode
  }
}

output "subnetwork_config" {
  description = "Effective foundation subnetwork configuration."
  value = {
    cidr                           = local.subnetwork_cidr
    flow_logs_aggregation_interval = local.subnetwork_flow_logs_aggregation_interval
    flow_logs_enabled              = local.enable_subnetwork_flow_logs
    flow_logs_metadata             = local.subnetwork_flow_logs_metadata
    flow_logs_sampling             = local.subnetwork_flow_logs_sampling
    name                           = local.subnetwork_name
    private_ip_google_access       = local.private_ip_google_access
  }
}

output "nat_config" {
  description = "Effective foundation Cloud Router/NAT configuration."
  value = {
    cloud_nat_enable_logging               = local.cloud_nat_enable_logging
    cloud_nat_endpoint_independent_mapping = local.cloud_nat_endpoint_independent_mapping
    cloud_nat_logging_filter               = local.cloud_nat_logging_filter
    cloud_nat_min_ports_per_vm             = local.cloud_nat_min_ports_per_vm
    cloud_nat_name                         = local.cloud_nat_name
    cloud_router_name                      = local.cloud_router_name
  }
}

output "firewall_config" {
  description = "Effective foundation firewall configuration."
  value = {
    allow_internal_firewall_name = local.allow_internal_firewall_name
    create_allow_internal        = local.create_allow_internal_firewall
  }
}

output "allow_internal_firewall_name" {
  description = "Internal firewall name when enabled."
  value       = module.foundation_network.allow_internal_firewall_name
}

output "network_id" {
  description = "Foundation VPC network resource ID."
  value       = module.foundation_network.network_id
}

output "network_name" {
  description = "Foundation VPC network name."
  value       = module.foundation_network.network_name
}

output "network_self_link" {
  description = "Foundation VPC network self link."
  value       = module.foundation_network.network_self_link
}

output "subnetwork_id" {
  description = "Foundation subnet resource ID."
  value       = module.foundation_network.subnetwork_id
}

output "subnetwork_name" {
  description = "Foundation subnet name."
  value       = module.foundation_network.subnetwork_name
}

output "subnetwork_self_link" {
  description = "Foundation subnet self link."
  value       = module.foundation_network.subnetwork_self_link
}

output "subnetwork_ip_cidr_range" {
  description = "Primary CIDR range configured in foundation subnet."
  value       = module.foundation_network.subnetwork_ip_cidr_range
}

output "cloud_router_id" {
  description = "Foundation Cloud Router resource ID."
  value       = module.foundation_network.cloud_router_id
}

output "cloud_router_name" {
  description = "Foundation Cloud Router name."
  value       = module.foundation_network.cloud_router_name
}

output "cloud_router_self_link" {
  description = "Foundation Cloud Router self link."
  value       = module.foundation_network.cloud_router_self_link
}

output "cloud_nat_id" {
  description = "Foundation Cloud NAT resource ID."
  value       = module.foundation_network.cloud_nat_id
}

output "cloud_nat_name" {
  description = "Foundation Cloud NAT name."
  value       = module.foundation_network.cloud_nat_name
}
