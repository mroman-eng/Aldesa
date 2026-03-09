output "project_id" {
  description = "Bootstrap target project."
  value       = module.bootstrap.project_id
}

output "enabled_services" {
  description = "Service APIs enabled during bootstrap."
  value       = module.bootstrap.enabled_services
}

output "state_bucket_name" {
  description = "GCS bucket name for Terraform remote state."
  value       = module.bootstrap.state_bucket_name
}

output "terraform_service_account_email" {
  description = "Terraform service account email."
  value       = module.bootstrap.terraform_service_account_email
}

output "terraform_custom_role_name" {
  description = "Custom role resource name assigned to Terraform service account."
  value       = module.bootstrap.terraform_custom_role_name
}

output "bigquery_data_transfer_service_agent_email" {
  description = "BigQuery Data Transfer service agent email for this project."
  value       = module.bootstrap.bigquery_data_transfer_service_agent_email
}

output "kms_key_ring_id" {
  description = "KMS key ring ID for SOPS encryption usage."
  value       = module.bootstrap.kms_key_ring_id
}

output "kms_crypto_key_id" {
  description = "KMS crypto key ID for SOPS encryption usage."
  value       = module.bootstrap.kms_crypto_key_id
}
