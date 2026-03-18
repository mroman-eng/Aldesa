locals {
  project_id_has_environment_suffix       = endswith(var.project_id, "-${var.environment}")
  naming_environment_token                = local.project_id_has_environment_suffix ? "" : "-${var.environment}"
  state_bucket_name                       = coalesce(try(var.bootstrap_remote_state.bucket, null), "${var.project_id}${local.naming_environment_token}-tfstate-${var.region}")
  terraform_service_account_email_default = "sa-terraform-buildtrack@${var.project_id}.iam.gserviceaccount.com"

  bootstrap_state_prefix     = coalesce(try(var.bootstrap_remote_state.bootstrap_prefix, null), "${var.environment}/00-bootstrap")
  orchestration_state_prefix = coalesce(try(var.orchestration_remote_state.orchestration_prefix, null), "${var.environment}/30-orchestration")
}

# Read outputs from bootstrap to reuse the Terraform deployer service account.
data "terraform_remote_state" "bootstrap" {
  backend = "gcs"

  config = {
    bucket = local.state_bucket_name
    prefix = local.bootstrap_state_prefix
  }
}

# Read outputs from orchestration to reuse the Composer DAG bucket.
data "terraform_remote_state" "orchestration" {
  backend = "gcs"

  config = {
    bucket = coalesce(try(var.orchestration_remote_state.bucket, null), local.state_bucket_name)
    prefix = local.orchestration_state_prefix
  }
}

# Resolve optional overrides for CI/CD dependencies.
locals {
  cicd_terraform_service_account_email_override = try(var.cicd_dependencies.terraform_service_account_email, null)
  cicd_dags_bucket_name_override                = try(var.cicd_dependencies.dags_bucket_name, null)

  cicd_dependencies = {
    terraform_service_account_email = (
      local.cicd_terraform_service_account_email_override != null && length(trimspace(local.cicd_terraform_service_account_email_override)) > 0
      ? local.cicd_terraform_service_account_email_override
      : coalesce(
        try(data.terraform_remote_state.bootstrap.outputs.terraform_service_account_email, null),
        local.terraform_service_account_email_default
      )
    )
    dags_bucket_name = (
      local.cicd_dags_bucket_name_override != null && length(trimspace(local.cicd_dags_bucket_name_override)) > 0
      ? local.cicd_dags_bucket_name_override
      : try(data.terraform_remote_state.orchestration.outputs.dags_bucket_name, null)
    )
  }
}

# Ensure required dependency values are available via remote state or explicit overrides.
check "cicd_dependency_outputs_are_available" {
  assert {
    condition     = local.cicd_dependencies.terraform_service_account_email != null && length(trimspace(local.cicd_dependencies.terraform_service_account_email)) > 0
    error_message = "Could not resolve terraform_service_account_email. Set cicd_dependencies.terraform_service_account_email (for example if bootstrap uses a non-default Terraform SA name)."
  }

  assert {
    condition     = local.cicd_dependencies.dags_bucket_name != null && length(trimspace(local.cicd_dependencies.dags_bucket_name)) > 0
    error_message = "Could not resolve dags_bucket_name from orchestration remote state. Apply orchestration first or set cicd_dependencies.dags_bucket_name."
  }
}

# Provision Cloud Build CI/CD identities and optional triggers.
module "cicd" {
  source = "../../../components/60-cicd"

  project_id   = var.project_id
  environment  = var.environment
  region       = var.region
  service_name = var.service_name

  terraform_service_account_email = local.cicd_dependencies.terraform_service_account_email
  dags_bucket_name                = local.cicd_dependencies.dags_bucket_name

  cloudbuild = var.cloudbuild
}
