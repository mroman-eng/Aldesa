locals {
  project_id_has_environment_suffix = endswith(var.project_id, "-${var.environment}")
  naming_environment_token          = local.project_id_has_environment_suffix ? "" : "-${var.environment}"
  foundation_state_prefix           = coalesce(try(var.foundation_remote_state.foundation_prefix, null), "${var.environment}/10-foundation")
  storage_bq_state_prefix           = coalesce(try(var.storage_bq_remote_state.storage_bq_prefix, null), "${var.environment}/20-storage-bq")
  state_bucket_name                 = coalesce(try(var.foundation_remote_state.bucket, null), "${var.project_id}${local.naming_environment_token}-tfstate-${var.region}")
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
    env_variables = merge(
      try(var.composer.env_variables, {}),
      try(data.terraform_remote_state.storage_bq.outputs.bronze_parquet_bucket_name, null) == null ? {} : {
        BRONZE_PARQUET_BUCKET = data.terraform_remote_state.storage_bq.outputs.bronze_parquet_bucket_name
      }
    ),
    pypi_packages = merge(try(var.composer.pypi_packages, {}), local.composer_requirements_pypi_packages)
  })
  composer_bigquery_access_config = merge(
    var.composer_bigquery_access,
    {
      dataset_data_editor_ids = (
        length(coalesce(try(var.composer_bigquery_access.dataset_data_editor_ids, null), [])) > 0 ?
        var.composer_bigquery_access.dataset_data_editor_ids :
        [coalesce(try(data.terraform_remote_state.storage_bq.outputs.logs_dataset_id, null), "logs")]
      )
    }
  )
  dataform_config = merge(
    try(data.terraform_remote_state.storage_bq.outputs.dataform_git_token_secret_id, null) == null ? {} : {
      git_token_secret_name = data.terraform_remote_state.storage_bq.outputs.dataform_git_token_secret_id
    },
    var.dataform
  )
  landing_to_composer_trigger_source_dir_input = try(var.landing_to_composer_trigger.source_dir, null)
  landing_to_composer_trigger_source_dir = (
    local.landing_to_composer_trigger_source_dir_input == null ?
    "../../../../functions/clf-ingesta-sap" :
    local.landing_to_composer_trigger_source_dir_input
  )
  landing_to_composer_trigger_config = merge(
    var.landing_to_composer_trigger,
    {
      source_dir = local.landing_to_composer_trigger_source_dir
    },
    var.landing_to_composer_trigger_eventarc_subscription_name_override == null ? {} : {
      eventarc_subscription_tuning = merge(
        try(var.landing_to_composer_trigger.eventarc_subscription_tuning, {}),
        {
          subscription_name = var.landing_to_composer_trigger_eventarc_subscription_name_override
        }
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

data "terraform_remote_state" "storage_bq" {
  backend = "gcs"

  config = {
    bucket = coalesce(try(var.storage_bq_remote_state.bucket, null), local.state_bucket_name)
    prefix = local.storage_bq_state_prefix
  }
}

module "orchestration" {
  source = "../../../components/30-orchestration"

  project_id        = var.project_id
  environment       = var.environment
  region            = var.region
  service_name      = var.service_name
  additional_labels = var.additional_labels

  network_self_link          = data.terraform_remote_state.foundation.outputs.network_self_link
  subnetwork_self_link       = data.terraform_remote_state.foundation.outputs.subnetwork_self_link
  landing_bucket_name        = data.terraform_remote_state.storage_bq.outputs.landing_bucket_name
  bronze_parquet_bucket_name = try(data.terraform_remote_state.storage_bq.outputs.bronze_parquet_bucket_name, null)

  composer                    = local.composer_config
  composer_bigquery_access    = local.composer_bigquery_access_config
  dags_bucket                 = var.dags_bucket
  dataform                    = local.dataform_config
  landing_to_composer_trigger = local.landing_to_composer_trigger_config
}
