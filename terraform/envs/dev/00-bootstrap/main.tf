module "bootstrap" {
  source = "../../../components/00-bootstrap"

  project_id        = var.project_id
  environment       = var.environment
  region            = var.region
  service_name      = var.service_name
  additional_labels = var.additional_labels

  terraform_project_iam_custom_role_id  = var.terraform_project_iam_custom_role_id
  state_bucket_name_override            = var.state_bucket_name_override
  terraform_service_account_id_override = var.terraform_service_account_id_override
  kms_key_ring_name_override            = var.kms_key_ring_name_override
  kms_crypto_key_name_override          = var.kms_crypto_key_name_override
}
