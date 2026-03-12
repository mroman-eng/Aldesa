locals {
  include_worker = (
    var.worker_min_count != null ||
    var.worker_max_count != null ||
    var.worker_cpu != null ||
    var.worker_memory_gb != null ||
    var.worker_storage_gb != null
  )

  include_scheduler = (
    var.scheduler_count != null ||
    var.scheduler_cpu != null ||
    var.scheduler_memory_gb != null ||
    var.scheduler_storage_gb != null
  )

  include_dag_processor = (
    var.dag_processor_count != null ||
    var.dag_processor_cpu != null ||
    var.dag_processor_memory_gb != null ||
    var.dag_processor_storage_gb != null
  )

  include_triggerer = (
    var.triggerer_count != null ||
    var.triggerer_cpu != null ||
    var.triggerer_memory_gb != null
  )

  include_web_server = (
    var.web_server_cpu != null ||
    var.web_server_memory_gb != null ||
    var.web_server_storage_gb != null
  )

  include_workloads_config = (
    local.include_worker ||
    local.include_scheduler ||
    local.include_dag_processor ||
    local.include_triggerer ||
    local.include_web_server
  )

  worker_min_count_effective = coalesce(var.worker_min_count, 1)
  worker_max_count_effective = coalesce(var.worker_max_count, 3)
  worker_cpu_effective       = coalesce(var.worker_cpu, 0.5)
  worker_memory_gb_effective = coalesce(var.worker_memory_gb, 2)
  worker_storage_gb_effective = coalesce(
    var.worker_storage_gb,
    10
  )

  scheduler_count_effective      = coalesce(var.scheduler_count, 1)
  scheduler_cpu_effective        = coalesce(var.scheduler_cpu, 0.5)
  scheduler_memory_gb_effective  = coalesce(var.scheduler_memory_gb, 2)
  scheduler_storage_gb_effective = coalesce(var.scheduler_storage_gb, 1)

  dag_processor_count_effective      = coalesce(var.dag_processor_count, 1)
  dag_processor_cpu_effective        = coalesce(var.dag_processor_cpu, 1)
  dag_processor_memory_gb_effective  = coalesce(var.dag_processor_memory_gb, 4)
  dag_processor_storage_gb_effective = coalesce(var.dag_processor_storage_gb, 1)

  triggerer_count_effective     = coalesce(var.triggerer_count, 1)
  triggerer_cpu_effective       = coalesce(var.triggerer_cpu, 0.5)
  triggerer_memory_gb_effective = coalesce(var.triggerer_memory_gb, 1)

  web_server_cpu_effective        = coalesce(var.web_server_cpu, 1)
  web_server_memory_gb_effective  = coalesce(var.web_server_memory_gb, 2)
  web_server_storage_gb_effective = coalesce(var.web_server_storage_gb, 1)
}

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
      for_each = local.include_workloads_config ? [1] : []
      content {
        dynamic "scheduler" {
          for_each = local.include_scheduler ? [1] : []
          content {
            count      = local.scheduler_count_effective
            cpu        = local.scheduler_cpu_effective
            memory_gb  = local.scheduler_memory_gb_effective
            storage_gb = local.scheduler_storage_gb_effective
          }
        }

        dynamic "dag_processor" {
          for_each = local.include_dag_processor ? [1] : []
          content {
            count      = local.dag_processor_count_effective
            cpu        = local.dag_processor_cpu_effective
            memory_gb  = local.dag_processor_memory_gb_effective
            storage_gb = local.dag_processor_storage_gb_effective
          }
        }

        dynamic "triggerer" {
          for_each = local.include_triggerer ? [1] : []
          content {
            count     = local.triggerer_count_effective
            cpu       = local.triggerer_cpu_effective
            memory_gb = local.triggerer_memory_gb_effective
          }
        }

        dynamic "web_server" {
          for_each = local.include_web_server ? [1] : []
          content {
            cpu        = local.web_server_cpu_effective
            memory_gb  = local.web_server_memory_gb_effective
            storage_gb = local.web_server_storage_gb_effective
          }
        }

        dynamic "worker" {
          for_each = local.include_worker ? [1] : []
          content {
            min_count  = local.worker_min_count_effective
            max_count  = local.worker_max_count_effective
            cpu        = local.worker_cpu_effective
            memory_gb  = local.worker_memory_gb_effective
            storage_gb = local.worker_storage_gb_effective
          }
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
