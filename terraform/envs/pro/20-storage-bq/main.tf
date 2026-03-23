module "storage_bq" {
  source = "../../../components/20-storage-bq"

  project_id        = var.project_id
  environment       = var.environment
  region            = var.region
  service_name      = var.service_name
  additional_labels = var.additional_labels

  landing_bucket                              = var.landing_bucket
  bronze_parquet_bucket                       = var.bronze_parquet_bucket
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

  raw_tables    = {}
  bronze_tables = {}
  silver_tables = {}
  gold_tables   = {}
  alerts_tables = {}
  logs_tables   = {}
}
