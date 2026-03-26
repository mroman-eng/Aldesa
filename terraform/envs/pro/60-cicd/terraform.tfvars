project_id   = "data-buildtrack-pro"
environment  = "pro"
region       = "europe-west1"
service_name = "aldesa-buildtrack"

bootstrap_remote_state = {
  bucket           = "data-buildtrack-pro-tfstate-europe-west1"
  bootstrap_prefix = "pro/00-bootstrap"
}

orchestration_remote_state = {
  bucket               = "data-buildtrack-pro-tfstate-europe-west1"
  orchestration_prefix = "pro/30-orchestration"
}

cicd_dependencies = {
  terraform_service_account_email = null
  dags_bucket_name                = "pro-data-buildtrack-pro-dags-composer-europe-west1"
}

# Cloud Build CI/CD foundation: dedicated DAG sync SA + optional triggers.
cloudbuild = {
  enabled                                                      = true
  trigger_location                                             = "europe-southwest1"
  repository_resource_name                                     = "projects/data-buildtrack-pro/locations/europe-southwest1/connections/github-data-build-track/repositories/GrupoAldesa-build-track-gcp-dataops"
  github_pat_secret_name                                       = "sec-aldesa-buildtrack-pro-dataform-github-pat"
  grant_cloudbuild_service_agent_impersonation_on_terraform_sa = true
  grant_logging_log_writer_on_terraform_sa                     = true

  dags_sync_pipeline = {
    enabled                    = true
    service_account_id         = null
    display_name               = "Cloud Build DAG sync (PRO)"
    grant_storage_object_admin = true
    grant_logging_log_writer   = true
  }

  triggers = [
    # PR validations (target branch: main)
    {
      name                = "cb-pr-pro-python"
      description         = "PR validation for Python function files - Always-on"
      event               = "PULL_REQUEST"
      disabled            = true
      branch_regex        = "^main$"
      comment_control     = "COMMENTS_DISABLED"
      filename            = "cloudbuild/pr-validate-python.yaml"
      service_account_ref = "terraform"
      included_files = [
        "functions/**",
        "tests/dags/**",
      ]
    },
    {
      name                = "cb-pr-pro-dags"
      description         = "PR validation for Airflow DAG changes - Always-on"
      event               = "PULL_REQUEST"
      disabled            = true
      branch_regex        = "^main$"
      comment_control     = "COMMENTS_DISABLED"
      filename            = "cloudbuild/pr-validate-dags.yaml"
      service_account_ref = "terraform"
      included_files = [
        "dags/**",
      ]
    },
    {
      name                = "cb-pr-pro-dataform"
      description         = "PR validation for Dataform changes - Always-on"
      event               = "PULL_REQUEST"
      disabled            = true
      branch_regex        = "^main$"
      comment_control     = "COMMENTS_DISABLED"
      filename            = "cloudbuild/pr-validate-dataform.yaml"
      service_account_ref = "terraform"
      included_files = [
        "definitions/**",
        "includes/**",
        "workflow_settings.yaml",
        "package.json",
        "package-lock.json",
      ]
    },
    {
      name                = "cb-pr-pro-terraform"
      description         = "PR validation for Terraform changes - Always-on"
      event               = "PULL_REQUEST"
      disabled            = true
      branch_regex        = "^main$"
      comment_control     = "COMMENTS_DISABLED"
      filename            = "cloudbuild/pr-validate-terraform.yaml"
      service_account_ref = "terraform"
      included_files = [
        "Makefile",
        "mk/**",
        "terraform/modules/**",
        "terraform/components/00-bootstrap/**",
        "terraform/components/10-foundation/**",
        "terraform/components/20-storage-bq/**",
        "terraform/components/30-orchestration/**",
        "terraform/components/40-governance/**",
        "terraform/components/50-bi/**",
        "terraform/components/60-cicd/**",
        "terraform/envs/pro/00-bootstrap/**",
        "terraform/envs/pro/10-foundation/**",
        "terraform/envs/pro/20-storage-bq/**",
        "terraform/envs/pro/30-orchestration/**",
        "terraform/envs/pro/40-governance/**",
        "terraform/envs/pro/50-bi/**",
        "terraform/envs/pro/60-cicd/**",
        "functions/**",
        "composer/requirements.txt",
        "cloudbuild/**",
      ]
    },

    # Push to main (deploy PRO with a single ordered Terraform pipeline)
    {
      name                = "cb-pro-tf-apply-ordered"
      description         = "Apply Terraform components in dependency order in PRO on push to main."
      event               = "PUSH"
      disabled            = true
      branch_regex        = "^main$"
      filename            = "cloudbuild/push-terraform-apply-ordered.yaml"
      service_account_ref = "terraform"
      substitutions = {
        _INCLUDE_BOOTSTRAP  = "true"
        _INCLUDE_FOUNDATION = "true"
      }
      included_files = [
        "Makefile",
        "mk/**",
        "terraform/modules/**",
        "terraform/components/00-bootstrap/**",
        "terraform/components/10-foundation/**",
        "terraform/components/20-storage-bq/**",
        "terraform/components/30-orchestration/**",
        "terraform/components/40-governance/**",
        "terraform/components/50-bi/**",
        "terraform/components/60-cicd/**",
        "terraform/envs/pro/00-bootstrap/**",
        "terraform/envs/pro/10-foundation/**",
        "terraform/envs/pro/20-storage-bq/**",
        "terraform/envs/pro/30-orchestration/**",
        "terraform/envs/pro/40-governance/**",
        "terraform/envs/pro/50-bi/**",
        "terraform/envs/pro/60-cicd/**",
        "functions/**",
        "composer/requirements.txt",
      ]
    },
    {
      name                = "cb-pro-dags-sync"
      description         = "Sync repository dags/ to Composer DAG bucket in PRO on push to main."
      event               = "PUSH"
      disabled            = true
      branch_regex        = "^main$"
      filename            = "cloudbuild/push-dags-sync.yaml"
      service_account_ref = "dags_sync"
      included_files = [
        "dags/**",
      ]
    },
  ]
}
