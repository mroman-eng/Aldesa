module "foundation" {
  source = "../../../components/10-foundation"

  project_id   = var.project_id
  environment  = var.environment
  region       = var.region
  service_name = var.service_name

  network    = var.network
  subnetwork = var.subnetwork
  nat        = var.nat
  firewall   = var.firewall
}
