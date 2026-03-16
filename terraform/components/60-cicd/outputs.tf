output "project_id" {
  description = "CI/CD target project."
  value       = var.project_id
}

output "cloudbuild" {
  description = "Effective Cloud Build CI/CD configuration and trigger readiness."
  value = {
    enabled                           = local.cloudbuild_enabled
    trigger_location                  = local.cloudbuild_trigger_location
    repository_resource_name_default  = local.cloudbuild_repository_resource_name_default
    cloudbuild_service_agent_email    = local.cloudbuild_service_agent_email
    pending_trigger_connection        = local.cloudbuild_trigger_pending_connection
    configured_trigger_names          = sort(keys(local.cloudbuild_trigger_requests))
    created_trigger_names             = sort(keys(google_cloudbuild_trigger.this))
    terraform_trigger_service_account = var.terraform_service_account_email
    dags_sync_pipeline = {
      enabled                    = local.dags_sync_pipeline_enabled
      service_account_id         = local.dags_sync_pipeline_service_account_id
      service_account_email      = try(google_service_account.dags_sync_pipeline[0].email, null)
      dags_bucket_name           = var.dags_bucket_name
      grant_storage_object_admin = local.dags_sync_pipeline_grant_storage_object_admin
      grant_logging_log_writer   = local.dags_sync_pipeline_grant_logging_log_writer
    }
  }
}

output "cloudbuild_trigger_ids" {
  description = "Cloud Build trigger ids created in this environment."
  value       = { for name, trigger in google_cloudbuild_trigger.this : name => trigger.id }
}

output "cloudbuild_triggers" {
  description = "Summary of Cloud Build triggers defined by Terraform."
  value = {
    for name, t in local.cloudbuild_trigger_requests : name => {
      event                    = t.event
      location                 = t.location
      repository_resource_name = t.repository_resource_name
      filename                 = t.filename
      disabled                 = t.disabled
      require_approval         = t.require_approval
      service_account_ref      = t.service_account_ref
      service_account_email = (
        try(t.service_account_email, null) != null
        ? t.service_account_email
        : lookup(local.cloudbuild_trigger_service_account_email_by_ref, t.service_account_ref, null)
      )
      created    = contains(keys(google_cloudbuild_trigger.this), name)
      trigger_id = try(google_cloudbuild_trigger.this[name].id, null)
    }
  }
}

output "dags_sync_pipeline_service_account_email" {
  description = "Dedicated service account email for DAG sync pipeline jobs."
  value       = try(google_service_account.dags_sync_pipeline[0].email, null)
}
