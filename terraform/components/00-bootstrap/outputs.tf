output "project_id" {
  description = "Bootstrap target project."
  value       = var.project_id
}

output "enabled_services" {
  description = "Service APIs enabled during bootstrap."
  value       = module.project_services.enabled_services
}

output "state_bucket_name" {
  description = "Expected GCS bucket name for Terraform remote state (bucket is owner-managed, not created by bootstrap)."
  value       = local.state_bucket_name
}

output "terraform_service_account_email" {
  description = "Terraform service account email used by bootstrap (pre-existing SA)."
  value       = data.google_service_account.terraform.email
}

output "terraform_custom_role_name" {
  description = "Existing custom role resource name expected for Terraform IAM policy management."
  value       = local.terraform_project_iam_custom_role_name
}

output "kms_key_ring_id" {
  description = "KMS key ring ID for SOPS encryption usage."
  value       = module.sops_kms.key_ring_id
}

output "kms_crypto_key_id" {
  description = "KMS crypto key ID for SOPS encryption usage."
  value       = module.sops_kms.crypto_key_id
}
