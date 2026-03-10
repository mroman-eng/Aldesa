output "network_id" {
  description = "VPC network resource ID."
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "VPC network name."
  value       = google_compute_network.this.name
}

output "network_self_link" {
  description = "VPC network self link."
  value       = google_compute_network.this.self_link
}

output "subnetwork_id" {
  description = "Subnetwork resource ID."
  value       = google_compute_subnetwork.this.id
}

output "subnetwork_name" {
  description = "Subnetwork name."
  value       = google_compute_subnetwork.this.name
}

output "subnetwork_self_link" {
  description = "Subnetwork self link."
  value       = google_compute_subnetwork.this.self_link
}

output "subnetwork_ip_cidr_range" {
  description = "Primary CIDR range configured in subnetwork."
  value       = google_compute_subnetwork.this.ip_cidr_range
}

output "cloud_router_id" {
  description = "Cloud Router resource ID."
  value       = google_compute_router.this.id
}

output "cloud_router_name" {
  description = "Cloud Router name."
  value       = google_compute_router.this.name
}

output "cloud_router_self_link" {
  description = "Cloud Router self link."
  value       = google_compute_router.this.self_link
}

output "cloud_nat_id" {
  description = "Cloud NAT resource ID."
  value       = google_compute_router_nat.this.id
}

output "cloud_nat_name" {
  description = "Cloud NAT name."
  value       = google_compute_router_nat.this.name
}

output "allow_internal_firewall_name" {
  description = "Internal firewall rule name when enabled."
  value       = try(google_compute_firewall.allow_internal[0].name, null)
}
