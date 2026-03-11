# Local naming and labels for bootstrap resources.
locals {
  project_id_has_environment_suffix = endswith(var.project_id, "-${var.environment}")
  naming_environment_token          = local.project_id_has_environment_suffix ? "" : "-${var.environment}"

  common_labels = merge(
    {
      component    = "00-bootstrap"
      environment  = var.environment
      managed_by   = "terraform"
      project_name = var.service_name
    },
    var.additional_labels
  )

  state_bucket_name                      = coalesce(var.state_bucket_name_override, "${var.project_id}${local.naming_environment_token}-tfstate-${var.region}")
  terraform_service_account_id           = coalesce(var.terraform_service_account_id_override, "sa-terraform-buildtrack")
  terraform_project_iam_custom_role_name = "projects/${var.project_id}/roles/${var.terraform_project_iam_custom_role_id}"
  # Keep legacy names by default to avoid replacing existing keys in already-bootstrapped projects.
  kms_key_ring_name   = coalesce(var.kms_key_ring_name_override, "kr-${var.service_name}-${var.environment}-sops")
  kms_crypto_key_name = coalesce(var.kms_crypto_key_name_override, "ck-${var.service_name}-${var.environment}-sops")
}

# Validate generated names before creating bootstrap resources.
check "generated_names_are_valid" {
  assert {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", local.state_bucket_name))
    error_message = "Generated state bucket name is invalid. Set state_bucket_name_override with a valid bucket name."
  }

  assert {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", local.terraform_service_account_id))
    error_message = "Generated Terraform service account id is invalid. Set terraform_service_account_id_override with a valid id."
  }
}

# Enable required Google APIs for the platform bootstrap.
module "project_services" {
  source = "../../modules/project_services"

  project_id = var.project_id
  services   = var.bootstrap_services
}

# Read pre-existing Terraform execution service account (created by project owners).
data "google_service_account" "terraform" {
  project    = var.project_id
  account_id = local.terraform_service_account_id

  depends_on = [module.project_services]
}

# Bind broad admin roles to the Terraform service account.
module "terraform_sa_bindings" {
  source = "../../modules/iam_bindings"

  project_id = var.project_id
  member     = "serviceAccount:${data.google_service_account.terraform.email}"
  roles      = var.terraform_admin_roles
}

# Preserve state addresses after renaming the internal KMS module.
moved {
  from = module.sops_kms.google_kms_key_ring.this
  to   = module.bootstrap_kms.google_kms_key_ring.this
}

moved {
  from = module.sops_kms.google_kms_crypto_key.this
  to   = module.bootstrap_kms.google_kms_crypto_key.this
}

moved {
  from = google_kms_crypto_key_iam_member.terraform_sops_key_encrypter_decrypter
  to   = google_kms_crypto_key_iam_member.terraform_kms_key_encrypter_decrypter
}

# Create KMS key ring and crypto key for platform encryption use cases.
module "bootstrap_kms" {
  source = "../../modules/kms"

  project_id      = var.project_id
  location        = var.region
  key_ring_name   = local.kms_key_ring_name
  crypto_key_name = local.kms_crypto_key_name
  labels          = local.common_labels

  depends_on = [module.project_services]
}

# Grant Terraform service account encrypt/decrypt access on the bootstrap KMS key.
resource "google_kms_crypto_key_iam_member" "terraform_kms_key_encrypter_decrypter" {
  crypto_key_id = module.bootstrap_kms.crypto_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_service_account.terraform.email}"
}
