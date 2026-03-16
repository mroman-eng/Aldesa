# Read project metadata to derive Cloud Build service agent identity.
data "google_project" "current" {
  project_id = var.project_id
}

# Resolve Cloud Build CI identities and trigger defaults.
locals {
  cloudbuild_enabled                            = coalesce(try(var.cloudbuild.enabled, null), true)
  cloudbuild_trigger_location                   = coalesce(try(var.cloudbuild.trigger_location, null), var.region)
  cloudbuild_repository_resource_name_default   = try(var.cloudbuild.repository_resource_name, null)
  cloudbuild_default_trigger_disabled           = coalesce(try(var.cloudbuild.default_trigger_disabled, null), false)
  cloudbuild_grant_tf_sa_impersonation          = coalesce(try(var.cloudbuild.grant_cloudbuild_service_agent_impersonation_on_terraform_sa, null), true)
  cloudbuild_grant_tf_sa_logging_writer         = coalesce(try(var.cloudbuild.grant_logging_log_writer_on_terraform_sa, null), true)
  cloudbuild_service_agent_email                = "service-${data.google_project.current.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
  cloudbuild_service_agent_member               = "serviceAccount:${local.cloudbuild_service_agent_email}"
  dags_sync_pipeline_enabled                    = local.cloudbuild_enabled && coalesce(try(var.cloudbuild.dags_sync_pipeline.enabled, null), true)
  dags_sync_pipeline_service_account_id         = coalesce(try(var.cloudbuild.dags_sync_pipeline.service_account_id, null), trimsuffix(substr("cbd-${var.environment}-${var.service_name}-dags", 0, 30), "-"))
  dags_sync_pipeline_display_name               = coalesce(try(var.cloudbuild.dags_sync_pipeline.display_name, null), "Cloud Build DAG sync (${upper(var.environment)})")
  dags_sync_pipeline_grant_storage_object_admin = coalesce(try(var.cloudbuild.dags_sync_pipeline.grant_storage_object_admin, null), true)
  dags_sync_pipeline_grant_logging_log_writer   = coalesce(try(var.cloudbuild.dags_sync_pipeline.grant_logging_log_writer, null), true)
}

# Normalize Cloud Build trigger definitions from tfvars.
locals {
  cloudbuild_trigger_requests = {
    for t in [
      for raw in try(var.cloudbuild.triggers, []) : {
        name        = raw.name
        description = try(raw.description, null)
        enabled     = coalesce(try(raw.enabled, null), true)
        disabled    = coalesce(try(raw.disabled, null), local.cloudbuild_default_trigger_disabled)
        location    = coalesce(try(raw.location, null), local.cloudbuild_trigger_location)
        repository_resource_name = (
          try(raw.repository_resource_name, null) != null
          ? raw.repository_resource_name
          : local.cloudbuild_repository_resource_name_default
        )
        event            = upper(raw.event)
        branch_regex     = try(raw.branch_regex, null)
        tag_regex        = try(raw.tag_regex, null)
        invert_regex     = coalesce(try(raw.invert_regex, null), false)
        comment_control  = try(raw.comment_control, null)
        require_approval = coalesce(try(raw.require_approval, null), false)
        filename         = raw.filename
        included_files   = distinct(compact(try(raw.included_files, null) == null ? [] : raw.included_files))
        ignored_files    = distinct(compact(try(raw.ignored_files, null) == null ? [] : raw.ignored_files))
        substitutions = merge(
          {
            _ENV         = var.environment
            _PROJECT_ID  = var.project_id
            _DAGS_BUCKET = var.dags_bucket_name
          },
          (try(raw.substitutions, null) == null ? {} : raw.substitutions)
        )
        tags                  = distinct(compact(try(raw.tags, null) == null ? [] : raw.tags))
        service_account_ref   = lower(coalesce(try(raw.service_account_ref, null), "default"))
        service_account_email = try(raw.service_account_email, null)
      }
    ] : t.name => t
    if local.cloudbuild_enabled && t.enabled
  }

  cloudbuild_trigger_service_account_email_by_ref = {
    default   = null
    terraform = var.terraform_service_account_email
    dags_sync = try(google_service_account.dags_sync_pipeline[0].email, null)
  }

  cloudbuild_trigger_pending_connection = sort([
    for name, t in local.cloudbuild_trigger_requests : name
    if t.repository_resource_name == null || length(trimspace(t.repository_resource_name)) == 0
  ])

  cloudbuild_trigger_resources = {
    for name, t in local.cloudbuild_trigger_requests : name => t
    if t.repository_resource_name != null && length(trimspace(t.repository_resource_name)) > 0
  }
}

# Validate Cloud Build trigger and CI identity inputs.
check "cicd_inputs_are_valid" {
  assert {
    condition = (
      !local.dags_sync_pipeline_enabled ||
      length(trimspace(var.dags_bucket_name)) > 0
    )
    error_message = "dags_bucket_name must be provided when cloudbuild.dags_sync_pipeline.enabled=true."
  }

  assert {
    condition = alltrue([
      for _, t in local.cloudbuild_trigger_requests :
      contains(["PUSH", "PULL_REQUEST"], t.event)
    ])
    error_message = "cloudbuild.triggers[*].event must be PUSH or PULL_REQUEST."
  }

  assert {
    condition = alltrue([
      for _, t in local.cloudbuild_trigger_requests :
      t.event == "PUSH" ? ((t.branch_regex != null && length(trimspace(t.branch_regex)) > 0) || (t.tag_regex != null && length(trimspace(t.tag_regex)) > 0)) : true
    ])
    error_message = "PUSH triggers require branch_regex or tag_regex."
  }

  assert {
    condition = alltrue([
      for _, t in local.cloudbuild_trigger_requests :
      t.event == "PULL_REQUEST" ? (t.branch_regex != null && length(trimspace(t.branch_regex)) > 0) : true
    ])
    error_message = "PULL_REQUEST triggers require branch_regex."
  }

  assert {
    condition = alltrue([
      for _, t in local.cloudbuild_trigger_requests :
      contains(["default", "terraform", "dags_sync"], t.service_account_ref)
    ])
    error_message = "cloudbuild.triggers[*].service_account_ref must be one of: default, terraform, dags_sync."
  }

  assert {
    condition = alltrue([
      for _, t in local.cloudbuild_trigger_requests :
      t.service_account_ref != "dags_sync" || local.dags_sync_pipeline_enabled
    ])
    error_message = "A trigger uses service_account_ref=dags_sync but cloudbuild.dags_sync_pipeline.enabled=false."
  }

  assert {
    condition = alltrue([
      for _, t in local.cloudbuild_trigger_requests :
      t.event != "PULL_REQUEST" || t.comment_control == null || contains(["COMMENTS_DISABLED", "COMMENTS_ENABLED", "COMMENTS_ENABLED_FOR_EXTERNAL_CONTRIBUTORS_ONLY"], t.comment_control)
    ])
    error_message = "cloudbuild.triggers[*].comment_control must be a valid Cloud Build PR comment control value."
  }

  assert {
    condition = alltrue([
      for _, t in local.cloudbuild_trigger_requests :
      can(regex("^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$", t.name))
    ])
    error_message = "cloudbuild.triggers[*].name must contain only alphanumeric, hyphen or underscore (max 64 chars)."
  }

  assert {
    condition = alltrue([
      for _, t in local.cloudbuild_trigger_requests :
      can(regex("^.+\\.ya?ml$", t.filename))
    ])
    error_message = "cloudbuild.triggers[*].filename must point to a .yaml/.yml file in the repository."
  }
}

# Create a dedicated service account for Composer DAG sync jobs run by Cloud Build.
resource "google_service_account" "dags_sync_pipeline" {
  count = local.dags_sync_pipeline_enabled ? 1 : 0

  project      = var.project_id
  account_id   = local.dags_sync_pipeline_service_account_id
  display_name = local.dags_sync_pipeline_display_name
}

# Grant the DAG sync pipeline service account object-level write permissions on the Composer DAG bucket.
resource "google_storage_bucket_iam_member" "dags_sync_pipeline_bucket_object_admin" {
  count = local.dags_sync_pipeline_enabled && local.dags_sync_pipeline_grant_storage_object_admin ? 1 : 0

  bucket = var.dags_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.dags_sync_pipeline[0].email}"
}

# Allow the DAG sync pipeline service account to write build logs to Cloud Logging.
resource "google_project_iam_member" "dags_sync_pipeline_logging_writer" {
  count = local.dags_sync_pipeline_enabled && local.dags_sync_pipeline_grant_logging_log_writer ? 1 : 0

  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.dags_sync_pipeline[0].email}"
}

# Allow the Terraform deployer service account to write Cloud Build logs when used by triggers.
resource "google_project_iam_member" "terraform_trigger_logging_writer" {
  count = local.cloudbuild_enabled && local.cloudbuild_grant_tf_sa_logging_writer ? 1 : 0

  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${var.terraform_service_account_email}"
}

# Allow the Cloud Build service agent to impersonate the Terraform deployer service account.
resource "google_service_account_iam_member" "cloudbuild_service_agent_impersonates_terraform" {
  count = local.cloudbuild_enabled && local.cloudbuild_grant_tf_sa_impersonation ? 1 : 0

  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.terraform_service_account_email}"
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = local.cloudbuild_service_agent_member
}

# Allow the Cloud Build service agent to impersonate the DAG sync service account.
resource "google_service_account_iam_member" "cloudbuild_service_agent_impersonates_dags_sync" {
  count = local.dags_sync_pipeline_enabled ? 1 : 0

  service_account_id = google_service_account.dags_sync_pipeline[0].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = local.cloudbuild_service_agent_member
}

# Create Cloud Build triggers for repository events once the GitHub repository is connected in GCP.
resource "google_cloudbuild_trigger" "this" {
  for_each = local.cloudbuild_trigger_resources

  project     = var.project_id
  location    = each.value.location
  name        = each.key
  description = each.value.description
  disabled    = each.value.disabled
  filename    = each.value.filename

  included_files = each.value.included_files
  ignored_files  = each.value.ignored_files
  substitutions  = each.value.substitutions
  tags           = each.value.tags

  service_account = (
    (
      try(each.value.service_account_email, null) != null
      ? each.value.service_account_email
      : lookup(local.cloudbuild_trigger_service_account_email_by_ref, each.value.service_account_ref, null)
    ) != null
    ? "projects/${var.project_id}/serviceAccounts/${(
      try(each.value.service_account_email, null) != null
      ? each.value.service_account_email
      : lookup(local.cloudbuild_trigger_service_account_email_by_ref, each.value.service_account_ref, null)
    )}"
    : null
  )

  repository_event_config {
    repository = each.value.repository_resource_name

    dynamic "push" {
      for_each = each.value.event == "PUSH" ? [1] : []
      content {
        branch       = each.value.branch_regex
        tag          = each.value.tag_regex
        invert_regex = each.value.invert_regex
      }
    }

    dynamic "pull_request" {
      for_each = each.value.event == "PULL_REQUEST" ? [1] : []
      content {
        branch          = each.value.branch_regex
        comment_control = each.value.comment_control
        invert_regex    = each.value.invert_regex
      }
    }
  }

  dynamic "approval_config" {
    for_each = each.value.require_approval ? [1] : []
    content {
      approval_required = true
    }
  }

  depends_on = [
    google_project_iam_member.terraform_trigger_logging_writer,
    google_project_iam_member.dags_sync_pipeline_logging_writer,
    google_service_account_iam_member.cloudbuild_service_agent_impersonates_terraform,
    google_service_account_iam_member.cloudbuild_service_agent_impersonates_dags_sync,
  ]
}
