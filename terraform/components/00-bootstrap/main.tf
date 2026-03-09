# Local naming, labels and IAM role sets for bootstrap resources.
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

  bootstrap_services = [
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "bigquerydatatransfer.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudkms.googleapis.com",
    "composer.googleapis.com",
    "compute.googleapis.com",
    "dataform.googleapis.com",
    "dataplex.googleapis.com",
    "eventarc.googleapis.com",
    "iam.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
  ]

  state_bucket_name                      = coalesce(var.state_bucket_name_override, "${var.project_id}${local.naming_environment_token}-tfstate-${var.region}")
  terraform_service_account_id           = coalesce(var.terraform_service_account_id_override, "sa-terraform-buildtrack")
  terraform_project_iam_custom_role_name = "projects/${var.project_id}/roles/${var.terraform_project_iam_custom_role_id}"
  kms_key_ring_name                      = coalesce(var.kms_key_ring_name_override, "kr-${var.service_name}-${var.environment}-sops")
  kms_crypto_key_name                    = coalesce(var.kms_crypto_key_name_override, "ck-${var.service_name}-${var.environment}-sops")

  terraform_admin_roles = [
    "roles/artifactregistry.admin",
    "roles/bigquery.admin",
    "roles/cloudbuild.builds.editor",
    "roles/cloudfunctions.admin",
    "roles/composer.admin",
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin",
    "roles/dataform.admin",
    "roles/dataplex.admin",
    "roles/eventarc.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/pubsub.admin",
    "roles/run.admin",
    "roles/secretmanager.admin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/storage.admin",
  ]
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
  services   = local.bootstrap_services
}

# Create the GCS bucket used as Terraform remote state backend.
module "state_bucket" {
  source = "../../modules/gcs_bucket"

  project_id = var.project_id
  name       = local.state_bucket_name
  location   = var.region
  labels     = local.common_labels

  depends_on = [module.project_services]
}

# Ensure BigQuery Data Transfer service agent exists in the project.
resource "google_project_service_identity" "bigquery_data_transfer" {
  provider = google-beta

  project = var.project_id
  service = "bigquerydatatransfer.googleapis.com"

  depends_on = [module.project_services]
}

# Grant required service agent role to BigQuery Data Transfer identity.
resource "google_project_iam_member" "bigquery_data_transfer_service_agent_role" {
  project = var.project_id
  role    = "roles/bigquerydatatransfer.serviceAgent"
  member  = "serviceAccount:${google_project_service_identity.bigquery_data_transfer.email}"
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
  roles      = local.terraform_admin_roles
}

# Create KMS key ring and crypto key for SOPS use cases.
module "sops_kms" {
  source = "../../modules/kms"

  project_id      = var.project_id
  location        = var.region
  key_ring_name   = local.kms_key_ring_name
  crypto_key_name = local.kms_crypto_key_name
  labels          = local.common_labels

  depends_on = [module.project_services]
}

# Grant Terraform service account encrypt/decrypt access on the SOPS KMS key.
resource "google_kms_crypto_key_iam_member" "terraform_sops_key_encrypter_decrypter" {
  crypto_key_id = module.sops_kms.crypto_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_service_account.terraform.email}"
}
