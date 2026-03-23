locals {
  project_id_has_environment_suffix = endswith(var.project_id, "-${var.environment}")
  naming_environment_token          = local.project_id_has_environment_suffix ? "" : "-${var.environment}"
  state_bucket_name                 = coalesce(try(var.storage_bq_remote_state.bucket, null), "${var.project_id}${local.naming_environment_token}-tfstate-${var.region}")
  storage_bq_state_prefix           = coalesce(try(var.storage_bq_remote_state.storage_bq_prefix, null), "${var.environment}/20-storage-bq")
}

data "terraform_remote_state" "storage_bq" {
  backend = "gcs"

  config = {
    bucket = local.state_bucket_name
    prefix = local.storage_bq_state_prefix
  }
}

locals {
  raw_dataset_id = try(
    coalesce(
      try(var.governed_resources.raw_dataset_id, null),
      try(data.terraform_remote_state.storage_bq.outputs.raw_dataset_id, null)
    ),
    null
  )

  source_resources = merge(
    local.raw_dataset_id == null ? {} : {
      raw_dataset_id = local.raw_dataset_id
    },
    {
      bronze_dataset_id = coalesce(try(var.governed_resources.bronze_dataset_id, null), data.terraform_remote_state.storage_bq.outputs.bronze_dataset_id)
      silver_dataset_id = coalesce(try(var.governed_resources.silver_dataset_id, null), data.terraform_remote_state.storage_bq.outputs.silver_dataset_id)
      gold_dataset_id   = coalesce(try(var.governed_resources.gold_dataset_id, null), data.terraform_remote_state.storage_bq.outputs.gold_dataset_id)
    }
  )

  auto_profile_scan_table_ids_by_layer = {
    raw    = keys(coalesce(try(data.terraform_remote_state.storage_bq.outputs.raw_table_ids, null), {}))
    bronze = keys(coalesce(try(data.terraform_remote_state.storage_bq.outputs.bronze_table_ids, null), {}))
    silver = keys(coalesce(try(data.terraform_remote_state.storage_bq.outputs.silver_table_ids, null), {}))
    gold   = keys(coalesce(try(data.terraform_remote_state.storage_bq.outputs.gold_table_ids, null), {}))
  }
}

module "governance" {
  source = "../../../components/40-governance"

  project_id        = var.project_id
  environment       = var.environment
  region            = var.region
  service_name      = var.service_name
  additional_labels = var.additional_labels

  source_resources = local.source_resources

  auto_profile_scans                   = var.auto_profile_scans
  auto_profile_scan_table_ids_by_layer = local.auto_profile_scan_table_ids_by_layer
  dataplex_datascans                   = var.dataplex_datascans
}
