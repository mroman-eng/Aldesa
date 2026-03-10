output "project_id" {
  description = "Storage-BQ target project."
  value       = var.project_id
}

output "landing_bucket_config" {
  description = "Effective landing bucket configuration."
  value = {
    force_destroy            = local.landing_bucket_force_destroy
    location                 = local.landing_bucket_location
    name                     = local.landing_bucket_name
    public_access_prevention = lower(local.landing_bucket_public_access_prevention)
    storage_class            = local.landing_bucket_storage_class
    versioning_enabled       = local.landing_bucket_versioning_enabled
  }
}

output "landing_bucket_name" {
  description = "Landing bucket name for parquet files."
  value       = module.landing_bucket.name
}

output "datasphere_ingest_service_account_email" {
  description = "Dedicated SAP Datasphere ingestion service account email."
  value       = try(google_service_account.datasphere_ingest[0].email, null)
}

output "datasphere_ingest_sa_key_secret_id" {
  description = "Secret Manager secret id used to store the SAP Datasphere service account key JSON."
  value       = try(google_secret_manager_secret.datasphere_ingest_sa_key[0].secret_id, null)
}

output "dataset_ids" {
  description = "Effective dataset ids by data layer."
  value = {
    alerts = local.alerts_dataset_id
    logs   = local.logs_dataset_id
    raw    = local.raw_dataset_id
    bronze = local.bronze_dataset_id
    silver = local.silver_dataset_id
    gold   = local.gold_dataset_id
  }
}

output "medallion_dataset_ids" {
  description = "All managed dataset ids."
  value       = module.medallion_datasets.dataset_ids
}

output "raw_dataset_id" {
  description = "Raw dataset id."
  value       = local.raw_dataset_id
}

output "alerts_dataset_id" {
  description = "Alerts dataset id."
  value       = local.alerts_dataset_id
}

output "logs_dataset_id" {
  description = "Logs dataset id."
  value       = local.logs_dataset_id
}

output "bronze_dataset_id" {
  description = "Bronze dataset id."
  value       = local.bronze_dataset_id
}

output "silver_dataset_id" {
  description = "Silver dataset id."
  value       = local.silver_dataset_id
}

output "gold_dataset_id" {
  description = "Gold dataset id."
  value       = local.gold_dataset_id
}

output "medallion_table_ids" {
  description = "All managed table resource ids keyed by internal '<layer>:<table_id>' key."
  value       = module.medallion_tables.table_ids
}

output "raw_table_ids" {
  description = "Raw table resource ids."
  value = {
    for resource_key, table_resource_id in module.medallion_tables.table_ids :
    local.layered_table_definitions[resource_key].table_id => table_resource_id
    if local.layered_table_definitions[resource_key].dataset_id == local.raw_dataset_id
  }
}

output "bronze_table_ids" {
  description = "Bronze table resource ids."
  value = {
    for resource_key, table_resource_id in module.medallion_tables.table_ids :
    local.layered_table_definitions[resource_key].table_id => table_resource_id
    if local.layered_table_definitions[resource_key].dataset_id == local.bronze_dataset_id
  }
}

output "silver_table_ids" {
  description = "Silver table resource ids."
  value = {
    for resource_key, table_resource_id in module.medallion_tables.table_ids :
    local.layered_table_definitions[resource_key].table_id => table_resource_id
    if local.layered_table_definitions[resource_key].dataset_id == local.silver_dataset_id
  }
}

output "gold_table_ids" {
  description = "Gold table resource ids."
  value = {
    for resource_key, table_resource_id in module.medallion_tables.table_ids :
    local.layered_table_definitions[resource_key].table_id => table_resource_id
    if local.layered_table_definitions[resource_key].dataset_id == local.gold_dataset_id
  }
}

output "alerts_table_ids" {
  description = "Alerts table resource ids."
  value = {
    for resource_key, table_resource_id in module.medallion_tables.table_ids :
    local.layered_table_definitions[resource_key].table_id => table_resource_id
    if local.layered_table_definitions[resource_key].dataset_id == local.alerts_dataset_id
  }
}

output "logs_table_ids" {
  description = "Logs table resource ids."
  value = {
    for resource_key, table_resource_id in module.medallion_tables.table_ids :
    local.layered_table_definitions[resource_key].table_id => table_resource_id
    if local.layered_table_definitions[resource_key].dataset_id == local.logs_dataset_id
  }
}

output "medallion_view_ids" {
  description = "All managed view resource ids keyed by internal '<layer>:<view_id>' key."
  value       = { for resource_key, view in google_bigquery_table.medallion_views : resource_key => view.id }
}

output "raw_view_ids" {
  description = "Raw view resource ids."
  value = {
    for resource_key, view in google_bigquery_table.medallion_views :
    local.medallion_view_definitions[resource_key].table_id => view.id
    if local.medallion_view_definitions[resource_key].dataset_id == local.raw_dataset_id
  }
}

output "bronze_view_ids" {
  description = "Bronze view resource ids."
  value = {
    for resource_key, view in google_bigquery_table.medallion_views :
    local.medallion_view_definitions[resource_key].table_id => view.id
    if local.medallion_view_definitions[resource_key].dataset_id == local.bronze_dataset_id
  }
}

output "silver_view_ids" {
  description = "Silver view resource ids."
  value = {
    for resource_key, view in google_bigquery_table.medallion_views :
    local.medallion_view_definitions[resource_key].table_id => view.id
    if local.medallion_view_definitions[resource_key].dataset_id == local.silver_dataset_id
  }
}

output "gold_view_ids" {
  description = "Gold view resource ids."
  value = {
    for resource_key, view in google_bigquery_table.medallion_views :
    local.medallion_view_definitions[resource_key].table_id => view.id
    if local.medallion_view_definitions[resource_key].dataset_id == local.gold_dataset_id
  }
}

output "alerts_view_ids" {
  description = "Alerts view resource ids."
  value = {
    for resource_key, view in google_bigquery_table.medallion_views :
    local.medallion_view_definitions[resource_key].table_id => view.id
    if local.medallion_view_definitions[resource_key].dataset_id == local.alerts_dataset_id
  }
}

output "logs_view_ids" {
  description = "Logs view resource ids."
  value = {
    for resource_key, view in google_bigquery_table.medallion_views :
    local.medallion_view_definitions[resource_key].table_id => view.id
    if local.medallion_view_definitions[resource_key].dataset_id == local.logs_dataset_id
  }
}
