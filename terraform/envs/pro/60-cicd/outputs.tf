output "project_id" {
  description = "CI/CD target project."
  value       = module.cicd.project_id
}

output "cloudbuild" {
  description = "Effective Cloud Build CI/CD configuration and trigger readiness."
  value       = module.cicd.cloudbuild
}

output "cloudbuild_triggers" {
  description = "Summary of Cloud Build triggers defined by Terraform."
  value       = module.cicd.cloudbuild_triggers
}

output "cloudbuild_trigger_ids" {
  description = "Cloud Build trigger ids created in this environment."
  value       = module.cicd.cloudbuild_trigger_ids
}

output "dags_sync_pipeline_service_account_email" {
  description = "Dedicated service account email for DAG sync pipeline jobs."
  value       = module.cicd.dags_sync_pipeline_service_account_email
}
