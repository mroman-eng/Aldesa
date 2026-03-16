output "project_id" {
  description = "BI target project."
  value       = var.project_id
}

output "looker_studio_access" {
  description = "Effective Looker Studio Pro IAM access applied on BigQuery."
  value = {
    enabled                        = local.looker_studio_enabled
    user_emails                    = local.looker_studio_user_emails
    viewer_principals              = local.looker_studio_viewer_principals
    gold_dataset_id                = var.gold_dataset_id
    grant_bigquery_job_user        = local.looker_studio_grant_bigquery_job_user
    grant_gold_dataset_data_viewer = local.looker_studio_grant_gold_dataset_data_viewer
  }
}

output "context_aware_access" {
  description = "Context-Aware Access level metadata for Looker Studio network restrictions."
  value = {
    enabled                     = local.context_aware_access_enabled
    access_policy_id            = local.context_aware_access_policy_id
    access_level_name           = (local.context_aware_access_policy_id != null ? "${local.context_aware_access_policy_id}/accessLevels/${local.context_aware_access_level_short_name}" : null)
    access_level_short_name     = local.context_aware_access_level_short_name
    access_level_title          = local.context_aware_access_level_title
    allowed_ip_cidrs            = local.context_aware_access_allowed_ip_cidrs
    scope                       = local.context_aware_access_scope
    mode                        = local.context_aware_access_mode
    assignment_manual_step      = local.context_aware_access_enabled
    managed_by_terraform        = false
    assignment_manual_step_note = "Create/verify this Access Level and assign it to Looker Studio in Google Admin Console (Google-owned apps)."
  }
}
