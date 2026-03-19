locals {
  table_schema_dir = coalesce(var.table_schema_dir_override, "${path.module}/bq_table_schemas")

  raw_tables_with_schema = {
    for table_id, table in var.raw_tables : table_id => merge(table, {
      schema_json = file("${local.table_schema_dir}/raw/${table_id}.json")
    })
  }

  bronze_tables_with_schema = {
    for table_id, table in var.bronze_tables : table_id => merge(table, {
      schema_json = file("${local.table_schema_dir}/bronze/${table_id}.json")
    })
  }

  silver_tables_with_schema = {
    for table_id, table in var.silver_tables : table_id => merge(table, {
      schema_json = file("${local.table_schema_dir}/silver/${table_id}.json")
    })
  }

  gold_tables_with_schema = {
    for table_id, table in var.gold_tables : table_id => merge(table, {
      schema_json = file("${local.table_schema_dir}/gold/${table_id}.json")
    })
  }

  alerts_tables_with_schema = {
    for table_id, table in var.alerts_tables : table_id => merge(table, {
      schema_json = file("${local.table_schema_dir}/alerts/${table_id}.json")
    })
  }

  logs_tables_with_schema = {
    for table_id, table in var.logs_tables : table_id => merge(table, {
      schema_json = file("${local.table_schema_dir}/logs/${table_id}.json")
    })
  }
}

module "storage_bq" {
  source = "../../../components/20-storage-bq"

  project_id        = var.project_id
  environment       = var.environment
  region            = var.region
  service_name      = var.service_name
  additional_labels = var.additional_labels

  landing_bucket                              = var.landing_bucket
  enable_datasphere_ingest_service_account    = var.enable_datasphere_ingest_service_account
  datasphere_ingest_sa_id_override            = var.datasphere_ingest_sa_id_override
  datasphere_ingest_sa_key_secret_id_override = var.datasphere_ingest_sa_key_secret_id_override
  datasphere_landing_bucket_roles             = var.datasphere_landing_bucket_roles
  enable_dataform_git_token_secret            = var.enable_dataform_git_token_secret
  dataform_git_token_secret_id_override       = var.dataform_git_token_secret_id_override

  bigquery_location_override = var.bigquery_location_override

  dataset_ids = var.dataset_ids

  bq_dataset_delete_contents_on_destroy = var.bq_dataset_delete_contents_on_destroy
  bq_default_table_expiration_ms        = var.bq_default_table_expiration_ms
  bq_table_deletion_protection          = var.bq_table_deletion_protection

  raw_tables    = local.raw_tables_with_schema
  bronze_tables = local.bronze_tables_with_schema
  silver_tables = local.silver_tables_with_schema
  gold_tables   = local.gold_tables_with_schema
  alerts_tables = local.alerts_tables_with_schema
  logs_tables   = local.logs_tables_with_schema
}
