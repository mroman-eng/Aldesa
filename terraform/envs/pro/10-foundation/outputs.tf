output "project_id" {
  description = "Foundation target project."
  value       = module.foundation.project_id
}

output "network_config" {
  description = "Effective foundation network configuration."
  value       = module.foundation.network_config
}

output "subnetwork_config" {
  description = "Effective foundation subnetwork configuration."
  value       = module.foundation.subnetwork_config
}

output "nat_config" {
  description = "Effective foundation Cloud Router/NAT configuration."
  value       = module.foundation.nat_config
}

output "firewall_config" {
  description = "Effective foundation firewall configuration."
  value       = module.foundation.firewall_config
}

output "allow_internal_firewall_name" {
  description = "Internal firewall name when enabled."
  value       = module.foundation.allow_internal_firewall_name
}

output "network_id" {
  description = "Foundation VPC network resource ID."
  value       = module.foundation.network_id
}

output "network_name" {
  description = "Foundation VPC network name."
  value       = module.foundation.network_name
}

output "network_self_link" {
  description = "Foundation VPC network self link."
  value       = module.foundation.network_self_link
}

output "subnetwork_id" {
  description = "Foundation subnet resource ID."
  value       = module.foundation.subnetwork_id
}

output "subnetwork_name" {
  description = "Foundation subnet name."
  value       = module.foundation.subnetwork_name
}

output "subnetwork_self_link" {
  description = "Foundation subnet self link."
  value       = module.foundation.subnetwork_self_link
}

output "subnetwork_ip_cidr_range" {
  description = "Primary CIDR range configured in foundation subnet."
  value       = module.foundation.subnetwork_ip_cidr_range
}

output "cloud_router_id" {
  description = "Foundation Cloud Router resource ID."
  value       = module.foundation.cloud_router_id
}

output "cloud_router_name" {
  description = "Foundation Cloud Router name."
  value       = module.foundation.cloud_router_name
}

output "cloud_router_self_link" {
  description = "Foundation Cloud Router self link."
  value       = module.foundation.cloud_router_self_link
}

output "cloud_nat_id" {
  description = "Foundation Cloud NAT resource ID."
  value       = module.foundation.cloud_nat_id
}

output "cloud_nat_name" {
  description = "Foundation Cloud NAT name."
  value       = module.foundation.cloud_nat_name
}
