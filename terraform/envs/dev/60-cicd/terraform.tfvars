project_id   = "data-buildtrack-dev"
environment  = "dev"
region       = "europe-west1"
service_name = "aldesa-buildtrack"

bootstrap_remote_state = {
  bucket           = "data-buildtrack-dev-tfstate-europe-west1"
  bootstrap_prefix = "dev/00-bootstrap"
}

orchestration_remote_state = {
  bucket               = "data-buildtrack-dev-tfstate-europe-west1"
  orchestration_prefix = "dev/30-orchestration"
}

cicd_dependencies = {
  terraform_service_account_email = null
  dags_bucket_name                = null
}

# Cloud Build CI/CD foundation: dedicated DAG sync SA + optional triggers.
# Cloud Build 2nd gen triggers must use the same region as the connected repository.
cloudbuild = {
  enabled                                                      = true
  trigger_location                                             = "europe-southwest1"
  repository_resource_name                                     = "projects/data-buildtrack-dev/locations/europe-southwest1/connections/github-data-build-track/repositories/GrupoAldesa-build-track-gcp-dataops"
  github_pat_secret_name                                       = "sec-aldesa-buildtrack-dev-dataform-github-pat"
  grant_cloudbuild_service_agent_impersonation_on_terraform_sa = true
  grant_logging_log_writer_on_terraform_sa                     = true

  dags_sync_pipeline = {
    enabled                    = true
    service_account_id         = null
    display_name               = "Cloud Build DAG sync (DEV)"
    grant_storage_object_admin = true
    grant_logging_log_writer   = true
  }

  triggers = [
    # PR validations (target branch: develop)
    {
      name                = "cb-pr-dev-python"
      description         = "PR validation for Python files - Always-on"
      event               = "PULL_REQUEST"
      disabled            = false
      branch_regex        = "^develop$"
      comment_control     = "COMMENTS_DISABLED"
      filename            = "cloudbuild/pr-validate-python.yaml"
      service_account_ref = "terraform"
    },
    {
      name                = "cb-pr-dev-dataform"
      description         = "PR validation for Dataform changes - Always-on"
      event               = "PULL_REQUEST"
      disabled            = false
      branch_regex        = "^develop$"
      comment_control     = "COMMENTS_DISABLED"
      filename            = "cloudbuild/pr-validate-dataform.yaml"
      service_account_ref = "terraform"
    },
    {
      name                = "cb-pr-dev-terraform"
      description         = "PR validation for Terraform changes - Always-on"
      event               = "PULL_REQUEST"
      disabled            = false
      branch_regex        = "^develop$"
      comment_control     = "COMMENTS_DISABLED"
      filename            = "cloudbuild/pr-validate-terraform.yaml"
      service_account_ref = "terraform"
    },

    # Push to develop (deploy DEV with a single ordered Terraform pipeline)
    {
      name                = "cb-dev-tf-apply-ordered"
      description         = "Apply Terraform components in dependency order in DEV on push to develop."
      event               = "PUSH"
      disabled            = true
      branch_regex        = "^develop$"
      filename            = "cloudbuild/push-terraform-apply-ordered.yaml"
      service_account_ref = "terraform"
      included_files = [
        "Makefile",
        "mk/**",
        "terraform/modules/**",
        "terraform/components/10-foundation/**",
        "terraform/components/20-storage-bq/**",
        "terraform/components/30-orchestration/**",
        "terraform/components/40-governance/**",
        "terraform/components/50-bi/**",
        "terraform/components/60-cicd/**",
        "terraform/envs/dev/10-foundation/**",
        "terraform/envs/dev/20-storage-bq/**",
        "terraform/envs/dev/30-orchestration/**",
        "terraform/envs/dev/40-governance/**",
        "terraform/envs/dev/50-bi/**",
        "terraform/envs/dev/60-cicd/**",
        "functions/**",
        "composer/requirements.txt",
      ]
    },
    {
      name                = "cb-dev-dags-sync"
      description         = "Sync repository dags/ to Composer DAG bucket in DEV on push to develop."
      event               = "PUSH"
      disabled            = true
      branch_regex        = "^develop$"
      filename            = "cloudbuild/push-dags-sync.yaml"
      service_account_ref = "dags_sync"
      included_files = [
        "dags/**",
      ]
    },
  ]
}
