locals {
  project_id_has_environment_suffix = endswith(var.project_id, "-${var.environment}")
  naming_environment_token          = local.project_id_has_environment_suffix ? "" : "-${var.environment}"
  state_bucket_name                 = coalesce(try(var.storage_bq_remote_state.bucket, null), "${var.project_id}${local.naming_environment_token}-tfstate-${var.region}")

  storage_bq_state_prefix = coalesce(try(var.storage_bq_remote_state.storage_bq_prefix, null), "${var.environment}/20-storage-bq")
}

# Read outputs from storage-bq to resolve BI dataset dependencies.
data "terraform_remote_state" "storage_bq" {
  backend = "gcs"

  config = {
    bucket = local.state_bucket_name
    prefix = local.storage_bq_state_prefix
  }
}

# Resolve optional overrides for BI dependencies.
locals {
  bi_dependencies = {
    gold_dataset_id = coalesce(try(var.bi_dependencies.gold_dataset_id, null), data.terraform_remote_state.storage_bq.outputs.gold_dataset_id)
  }
}

# Provision BI access controls for Looker Studio Pro.
module "bi" {
  source = "../../../components/50-bi"

  project_id      = var.project_id
  environment     = var.environment
  gold_dataset_id = local.bi_dependencies.gold_dataset_id

  looker_studio        = var.looker_studio
  context_aware_access = var.context_aware_access
}
