# Resolve BI toggles, principals and Context-Aware Access defaults.
locals {
  looker_studio_enabled = coalesce(try(var.looker_studio.enabled, null), true)

  looker_studio_user_emails = distinct(compact([
    for email in coalesce(try(var.looker_studio.user_emails, null), []) :
    lower(trimspace(email))
  ]))
  looker_studio_user_principals = [
    for email in local.looker_studio_user_emails :
    "user:${email}"
  ]
  looker_studio_viewer_principals = distinct(compact(concat(
    local.looker_studio_user_principals,
    coalesce(try(var.looker_studio.viewer_principals, null), [])
  )))
  looker_studio_grant_bigquery_job_user        = coalesce(try(var.looker_studio.grant_bigquery_job_user, null), true)
  looker_studio_grant_gold_dataset_data_viewer = coalesce(try(var.looker_studio.grant_gold_dataset_data_viewer, null), true)

  context_aware_access_enabled          = coalesce(try(var.context_aware_access.enabled, null), false)
  context_aware_access_policy_id        = try(var.context_aware_access.access_policy_id, null)
  context_aware_access_level_short_name = coalesce(try(var.context_aware_access.access_level_short_name, null), "ls_${var.environment}_corp_access")
  context_aware_access_level_title      = coalesce(try(var.context_aware_access.title, null), "Looker Studio ${upper(var.environment)} allowed networks")
  context_aware_access_allowed_ip_cidrs = distinct(compact(coalesce(try(var.context_aware_access.allowed_ip_cidrs, null), [])))
  context_aware_access_scope            = try(var.context_aware_access.scope, null)
  context_aware_access_mode             = try(var.context_aware_access.mode, null)
}

# Validate Looker Studio IAM and Context-Aware Access inputs.
check "looker_studio_inputs_are_valid" {
  assert {
    condition = (
      !local.looker_studio_enabled ||
      !(local.looker_studio_grant_bigquery_job_user || local.looker_studio_grant_gold_dataset_data_viewer) ||
      length(local.looker_studio_viewer_principals) > 0
    )
    error_message = "Set looker_studio.user_emails and/or looker_studio.viewer_principals when Looker Studio BigQuery grants are enabled."
  }

  assert {
    condition     = alltrue([for p in local.looker_studio_viewer_principals : can(regex("^(user|group|serviceAccount):.+$", p))])
    error_message = "Each looker_studio.viewer_principals entry must use IAM member syntax (user:, group:, serviceAccount:)."
  }

  assert {
    condition = (
      !local.context_aware_access_enabled ||
      (
        local.context_aware_access_policy_id != null &&
        can(regex("^accessPolicies/[0-9]+$", local.context_aware_access_policy_id))
      )
    )
    error_message = "context_aware_access.access_policy_id is required when enabled and must match accessPolicies/<numeric_id>."
  }

  assert {
    condition     = !local.context_aware_access_enabled || can(regex("^[A-Za-z][A-Za-z0-9_]{0,49}$", local.context_aware_access_level_short_name))
    error_message = "context_aware_access.access_level_short_name must start with a letter and contain only alphanumeric or underscore characters."
  }

  assert {
    condition     = !local.context_aware_access_enabled || length(local.context_aware_access_allowed_ip_cidrs) > 0
    error_message = "Set at least one CIDR in context_aware_access.allowed_ip_cidrs when Context-Aware Access is enabled."
  }

  assert {
    condition     = !local.context_aware_access_enabled || alltrue([for cidr in local.context_aware_access_allowed_ip_cidrs : can(cidrnetmask(cidr))])
    error_message = "All context_aware_access.allowed_ip_cidrs entries must be valid CIDR blocks."
  }
}

# Grant Looker Studio users permission to run BigQuery jobs in the project.
resource "google_project_iam_member" "looker_studio_bigquery_job_user" {
  for_each = local.looker_studio_enabled && local.looker_studio_grant_bigquery_job_user ? toset(local.looker_studio_viewer_principals) : toset([])

  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = each.value
}

# Grant Looker Studio users read-only access on the GOLD dataset.
resource "google_bigquery_dataset_iam_member" "looker_studio_gold_data_viewer" {
  for_each = local.looker_studio_enabled && local.looker_studio_grant_gold_dataset_data_viewer ? toset(local.looker_studio_viewer_principals) : toset([])

  project    = var.project_id
  dataset_id = var.gold_dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = each.value
}

# Context-Aware Access assignment is managed manually in Google Admin Console by an org admin.
