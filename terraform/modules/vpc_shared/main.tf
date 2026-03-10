locals {
  allow_internal_firewall_name = coalesce(var.allow_internal_firewall_name, "${var.network_name}-allow-internal")
}

resource "google_compute_network" "this" {
  project                         = var.project_id
  name                            = var.network_name
  auto_create_subnetworks         = false
  delete_default_routes_on_create = var.delete_default_routes_on_create
  mtu                             = var.network_mtu
  routing_mode                    = var.routing_mode
}

resource "google_compute_subnetwork" "this" {
  project                  = var.project_id
  name                     = var.subnetwork_name
  ip_cidr_range            = var.subnetwork_cidr
  region                   = var.region
  network                  = google_compute_network.this.id
  private_ip_google_access = var.private_ip_google_access
  stack_type               = "IPV4_ONLY"

  dynamic "log_config" {
    for_each = var.enable_subnetwork_flow_logs ? [1] : []
    content {
      aggregation_interval = var.subnetwork_flow_logs_aggregation_interval
      flow_sampling        = var.subnetwork_flow_logs_sampling
      metadata             = var.subnetwork_flow_logs_metadata
    }
  }
}

resource "google_compute_firewall" "allow_internal" {
  count = var.create_allow_internal_firewall ? 1 : 0

  project = var.project_id
  name    = local.allow_internal_firewall_name
  network = google_compute_network.this.name

  description = "Allow internal traffic inside foundation subnetwork."
  direction   = "INGRESS"

  source_ranges = [var.subnetwork_cidr]

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }
}

resource "google_compute_router" "this" {
  project = var.project_id
  name    = var.cloud_router_name
  region  = var.region
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  project = var.project_id
  name    = var.cloud_nat_name
  router  = google_compute_router.this.name
  region  = var.region

  nat_ip_allocate_option              = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat  = "LIST_OF_SUBNETWORKS"
  min_ports_per_vm                    = var.cloud_nat_min_ports_per_vm
  enable_endpoint_independent_mapping = var.cloud_nat_endpoint_independent_mapping

  subnetwork {
    name                    = google_compute_subnetwork.this.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = var.cloud_nat_enable_logging
    filter = var.cloud_nat_logging_filter
  }
}
