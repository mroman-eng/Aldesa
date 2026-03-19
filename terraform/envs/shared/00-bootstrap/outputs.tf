output "project_id" {
  description = "Bootstrap target project."
  value       = module.bootstrap.project_id
}

output "enabled_services" {
  description = "Service APIs enabled during bootstrap."
  value       = module.bootstrap.enabled_services
}

output "state_bucket_name" {
  description = "Expected GCS bucket name for Terraform remote state (owner-managed)."
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

output "kms_key_ring_id" {
  description = "KMS key ring ID managed by bootstrap."
  value       = module.bootstrap.kms_key_ring_id
}

output "kms_crypto_key_id" {
  description = "KMS crypto key ID managed by bootstrap."
  value       = module.bootstrap.kms_crypto_key_id
}
