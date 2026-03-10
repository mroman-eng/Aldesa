output "project_id" {
  description = "Storage-BQ target project."
  value       = module.storage_bq.project_id
}

output "landing_bucket_config" {
  description = "Effective landing bucket configuration."
  value       = module.storage_bq.landing_bucket_config
}

output "landing_bucket_name" {
  description = "Landing bucket name for parquet files."
  value       = module.storage_bq.landing_bucket_name
}

output "datasphere_ingest_service_account_email" {
  description = "Dedicated SAP Datasphere ingestion service account email."
  value       = module.storage_bq.datasphere_ingest_service_account_email
}

output "datasphere_ingest_sa_key_secret_id" {
  description = "Secret id used to store the SAP Datasphere service account key JSON."
  value       = module.storage_bq.datasphere_ingest_sa_key_secret_id
}

output "dataset_ids" {
  description = "Effective dataset ids by data layer."
  value       = module.storage_bq.dataset_ids
}

output "medallion_dataset_ids" {
  description = "All managed dataset ids."
  value       = module.storage_bq.medallion_dataset_ids
}

output "raw_dataset_id" {
  description = "Raw dataset id."
  value       = module.storage_bq.raw_dataset_id
}

output "logs_dataset_id" {
  description = "Logs dataset id."
  value       = module.storage_bq.logs_dataset_id
}

output "bronze_dataset_id" {
  description = "Bronze dataset id."
  value       = module.storage_bq.bronze_dataset_id
}

output "silver_dataset_id" {
  description = "Silver dataset id."
  value       = module.storage_bq.silver_dataset_id
}

output "gold_dataset_id" {
  description = "Gold dataset id."
  value       = module.storage_bq.gold_dataset_id
}

output "medallion_table_ids" {
  description = "All managed table resource ids."
  value       = module.storage_bq.medallion_table_ids
}

output "raw_table_ids" {
  description = "Raw table resource ids."
  value       = module.storage_bq.raw_table_ids
}

output "bronze_table_ids" {
  description = "Bronze table resource ids."
  value       = module.storage_bq.bronze_table_ids
}

output "silver_table_ids" {
  description = "Silver table resource ids."
  value       = module.storage_bq.silver_table_ids
}

output "gold_table_ids" {
  description = "Gold table resource ids."
  value       = module.storage_bq.gold_table_ids
}

output "logs_table_ids" {
  description = "Logs table resource ids."
  value       = module.storage_bq.logs_table_ids
}
