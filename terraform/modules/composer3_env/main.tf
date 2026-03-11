resource "google_composer_environment" "this" {
  provider = google-beta

  project = var.project_id
  region  = var.region
  name    = var.name
  labels  = var.labels

  storage_config {
    bucket = var.dags_bucket_name
  }

  config {
    enable_private_environment = var.enable_private_environment
    enable_private_builds_only = var.enable_private_builds_only
    environment_size           = var.environment_size

    dynamic "workloads_config" {
      for_each = (var.worker_min_count == null && var.worker_max_count == null) ? [] : [1]
      content {
        worker {
          min_count = var.worker_min_count
          max_count = var.worker_max_count
        }
      }
    }

    node_config {
      composer_internal_ipv4_cidr_block = var.composer_internal_ipv4_cidr_block
      network                           = var.network
      service_account                   = var.service_account_email
      subnetwork                        = var.subnetwork
    }

    software_config {
      airflow_config_overrides = var.airflow_config_overrides
      env_variables            = var.env_variables
      image_version            = var.composer_image_version
      pypi_packages            = var.pypi_packages
    }
  }
}
