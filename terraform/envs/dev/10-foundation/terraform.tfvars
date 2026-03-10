project_id   = "data-buildtrack-dev"
environment  = "dev"
region       = "europe-west1"
service_name = "aldesa-buildtrack"

network = {
  name                            = "vpc-aldesa-buildtrack-dev"
  routing_mode                    = "REGIONAL"
  mtu                             = 1460
  delete_default_routes_on_create = false
}

subnetwork = {
  name                     = "snet-aldesa-buildtrack-dev-europe-west1-dp"
  cidr                     = "10.40.0.0/24"
  private_ip_google_access = true
  flow_logs = {
    enabled              = true
    aggregation_interval = "INTERVAL_5_MIN"
    sampling             = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

nat = {
  cloud_router_name            = "cr-aldesa-buildtrack-dev-europe-west1"
  cloud_nat_name               = "nat-aldesa-buildtrack-dev-europe-west1"
  enable_logging               = true
  logging_filter               = "ERRORS_ONLY"
  min_ports_per_vm             = 64
  endpoint_independent_mapping = true
}

firewall = {
  create_allow_internal = true
  allow_internal_name   = "fw-aldesa-buildtrack-dev-europe-west1-allow-internal"
}
