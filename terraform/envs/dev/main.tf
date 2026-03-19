locals {
  foundation_state_prefix = coalesce(try(var.foundation_remote_state.foundation_prefix, null), "shared/10-foundation")
  state_bucket_name       = coalesce(try(var.foundation_remote_state.bucket, null), "${var.project_id}-tfstate-${var.region}")

  composer_requirements_file = (
    startswith(var.composer_requirements_file, "/") ?
    var.composer_requirements_file :
    "${path.module}/${var.composer_requirements_file}"
  )

  composer_requirements_lines = (
    var.use_requirements_txt_pypi_packages ?
    [
      for line in split("\n", file(local.composer_requirements_file)) :
      trimspace(line)
      if length(trimspace(line)) > 0 && !startswith(trimspace(line), "#")
    ] :
    []
  )

  composer_requirements_pypi_packages = (
    var.use_requirements_txt_pypi_packages ?
    tomap({
      for line in local.composer_requirements_lines :
      trimspace(element(split("==", line), 0)) => "==${trimspace(try(element(split("==", line), 1), ""))}"
      if(
        length(split("==", line)) == 2 &&
        length(trimspace(element(split("==", line), 0))) > 0 &&
        length(trimspace(try(element(split("==", line), 1), ""))) > 0
      )
    }) :
    {}
  )

  composer_config = merge(var.composer, {
    pypi_packages = merge(try(var.composer.pypi_packages, {}), local.composer_requirements_pypi_packages)
  })

  composer_bigquery_access_config = merge(
    var.composer_bigquery_access,
    {
      dataset_data_editor_ids = (
        length(coalesce(try(var.composer_bigquery_access.dataset_data_editor_ids, null), [])) > 0 ?
        var.composer_bigquery_access.dataset_data_editor_ids :
        try(values(module.storage_bq[0].dataset_ids), [])
      )
    }
  )
}

check "composer_requirements_file_exists" {
  assert {
    condition     = !var.use_requirements_txt_pypi_packages || can(file(local.composer_requirements_file))
    error_message = "composer_requirements_file not found or unreadable. Set composer_requirements_file to a valid path."
  }
}

check "composer_requirements_file_format" {
  assert {
    condition = !var.use_requirements_txt_pypi_packages || alltrue([
      for line in local.composer_requirements_lines :
      length(split("==", line)) == 2 &&
      length(trimspace(element(split("==", line), 0))) > 0 &&
      length(trimspace(try(element(split("==", line), 1), ""))) > 0
    ])
    error_message = "composer_requirements_file must use one 'package==version' per non-comment line."
  }
}

data "terraform_remote_state" "foundation" {
  backend = "gcs"

  config = {
    bucket = local.state_bucket_name
    prefix = local.foundation_state_prefix
  }
}

module "storage_bq" {
  count = var.dev_enabled ? 1 : 0

  source = "../../components/20-storage-bq"

  project_id        = var.project_id
  environment       = var.environment
  region            = var.region
  service_name      = var.service_name
  additional_labels = var.additional_labels

  landing_bucket                           = var.landing_bucket
  enable_datasphere_ingest_service_account = false
  enable_dataform_git_token_secret         = false
  bigquery_location_override               = var.bigquery_location_override
  dataset_ids                              = var.dataset_ids
  bq_dataset_delete_contents_on_destroy    = var.bq_dataset_delete_contents_on_destroy
  bq_default_table_expiration_ms           = var.bq_default_table_expiration_ms
  bq_table_deletion_protection             = var.bq_table_deletion_protection

  raw_tables    = {}
  bronze_tables = {}
  silver_tables = {}
  gold_tables   = {}
  alerts_tables = {}
  logs_tables   = {}
}

module "orchestration" {
  count = var.dev_enabled ? 1 : 0

  source = "../../components/30-orchestration"

  project_id        = var.project_id
  environment       = var.environment
  region            = var.region
  service_name      = var.service_name
  additional_labels = var.additional_labels

  network_self_link    = data.terraform_remote_state.foundation.outputs.network_self_link
  subnetwork_self_link = data.terraform_remote_state.foundation.outputs.subnetwork_self_link
  landing_bucket_name  = module.storage_bq[0].landing_bucket_name

  composer                 = local.composer_config
  composer_bigquery_access = local.composer_bigquery_access_config
  dags_bucket              = var.dags_bucket
  dataform = {
    enabled = false
  }
  landing_to_composer_trigger = {
    enabled = false
  }
}
