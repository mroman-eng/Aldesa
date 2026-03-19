output "enabled" {
  description = "Whether the dev stack is enabled."
  value       = var.dev_enabled
}

output "project_id" {
  description = "Dev target project."
  value       = var.project_id
}

output "landing_bucket_name" {
  description = "Landing bucket name for dev."
  value       = try(module.storage_bq[0].landing_bucket_name, null)
}

output "dataset_ids" {
  description = "Effective dataset ids by data layer."
  value       = try(module.storage_bq[0].dataset_ids, null)
}

output "composer_environment_name" {
  description = "Dev Composer environment name."
  value       = try(module.orchestration[0].composer_environment_name, null)
}

output "composer_service_account_email" {
  description = "Dev Composer service account email."
  value       = try(module.orchestration[0].composer_service_account_email, null)
}

output "dags_bucket_name" {
  description = "Dev Composer DAG bucket name."
  value       = try(module.orchestration[0].dags_bucket_name, null)
}
