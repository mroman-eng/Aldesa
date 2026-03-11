# Local naming conventions and labels for orchestration resources.
locals {
  project_id_has_environment_suffix = endswith(var.project_id, "-${var.environment}")
  naming_environment_token          = local.project_id_has_environment_suffix ? "" : "-${var.environment}"

  common_labels = merge(
    {
      component    = "30-orchestration"
      environment  = var.environment
      managed_by   = "terraform"
      project_name = var.service_name
    },
    var.additional_labels
  )

  composer_environment_name           = coalesce(try(var.composer.environment_name, null), "${var.project_id}-orchestrator-sap-${var.region}")
  composer_service_account_id         = coalesce(try(var.composer.service_account_id, null), "cmp-${var.environment}-${var.service_name}")
  composer_image_version              = coalesce(try(var.composer.image_version, null), "composer-3-airflow-2")
  composer_environment_size           = coalesce(try(var.composer.environment_size, null), "ENVIRONMENT_SIZE_SMALL")
  composer_worker_min_count           = try(var.composer.worker_min_count, null)
  composer_worker_max_count           = try(var.composer.worker_max_count, null)
  composer_enable_private_environment = coalesce(try(var.composer.enable_private_environment, null), true)
  composer_enable_private_builds_only = coalesce(try(var.composer.enable_private_builds_only, null), false)
  composer_internal_ipv4_cidr_block   = coalesce(try(var.composer.internal_ipv4_cidr_block, null), "100.64.128.0/20")
  composer_airflow_config_overrides   = coalesce(try(var.composer.airflow_config_overrides, null), {})
  composer_env_variables = merge(
    {
      GCP_PROJECT_ID    = var.project_id
      GCP_LOCATION      = var.region
      LANDING_BUCKET    = var.landing_bucket_name
      GCP_REGION        = var.region
      GCP_REPOSITORY_ID = local.dataform_repository_name
    },
    coalesce(try(var.composer.env_variables, null), {})
  )
  composer_pypi_packages           = coalesce(try(var.composer.pypi_packages, null), {})
  composer_grant_bigquery_job_user = coalesce(try(var.composer_bigquery_access.grant_job_user, null), true)
  composer_bigquery_data_editor_dataset_ids = toset(
    coalesce(try(var.composer_bigquery_access.dataset_data_editor_ids, null), [])
  )

  dags_bucket_name                     = coalesce(try(var.dags_bucket.name, null), "${var.project_id}${local.naming_environment_token}-dags-composer-${var.region}")
  dags_bucket_location                 = coalesce(try(var.dags_bucket.location, null), var.region)
  dags_bucket_storage_class            = coalesce(try(var.dags_bucket.storage_class, null), "STANDARD")
  dags_bucket_force_destroy            = coalesce(try(var.dags_bucket.force_destroy, null), false)
  dags_bucket_versioning_enabled       = coalesce(try(var.dags_bucket.versioning_enabled, null), true)
  dags_bucket_public_access_prevention = lower(coalesce(try(var.dags_bucket.public_access_prevention, null), "enforced"))

  dataform_enabled                   = coalesce(try(var.dataform.enabled, null), true)
  dataform_repository_name           = coalesce(try(var.dataform.repository_name, null), "${var.project_id}-dataform-sap-${var.region}")
  dataform_git_remote_url            = try(var.dataform.git_remote_url, null)
  dataform_git_remote_default_branch = coalesce(try(var.dataform.git_remote_default_branch, null), "main")
  dataform_git_token_secret_name     = coalesce(try(var.dataform.git_token_secret_name, null), "sec-${var.service_name}-${var.environment}-dataform-github-pat")
  dataform_git_token_secret_version  = coalesce(try(var.dataform.git_token_secret_version, null), "latest")
  dataform_git_token_secret_version_resource = (
    "projects/${var.project_id}/secrets/${local.dataform_git_token_secret_name}/versions/${local.dataform_git_token_secret_version}"
  )

  dataform_release_config_enabled  = coalesce(try(var.dataform.release_config.enabled, null), true)
  dataform_release_config_name     = coalesce(try(var.dataform.release_config.name, null), "dfrc-${var.service_name}-${var.environment}")
  dataform_release_git_commitish   = try(var.dataform.release_config.git_commitish, null)
  dataform_release_cron_schedule   = try(var.dataform.release_config.cron_schedule, null)
  dataform_release_time_zone       = coalesce(try(var.dataform.release_config.time_zone, null), "UTC")
  dataform_release_compilation_cfg = try(var.dataform.release_config.code_compilation_config, null)

  dataform_workflow_config_enabled = coalesce(try(var.dataform.workflow_config.enabled, null), true)
  dataform_workflow_config_name    = coalesce(try(var.dataform.workflow_config.name, null), "dfwc-${var.service_name}-${var.environment}")
  dataform_workflow_cron_schedule  = try(var.dataform.workflow_config.cron_schedule, null)
  dataform_workflow_time_zone      = coalesce(try(var.dataform.workflow_config.time_zone, null), "UTC")

  landing_to_composer_trigger_enabled = coalesce(try(var.landing_to_composer_trigger.enabled, null), false)
  landing_to_composer_function_name   = coalesce(try(var.landing_to_composer_trigger.function_name, null), "${var.project_id}-clf-ingesta-sap")
  landing_to_composer_runtime_sa_id   = coalesce(try(var.landing_to_composer_trigger.runtime_service_account_id, null), "cf-${var.environment}-${var.service_name}-dag")
  landing_to_composer_trigger_sa_id   = coalesce(try(var.landing_to_composer_trigger.trigger_service_account_id, null), "evt-${var.environment}-${var.service_name}-dag")
  landing_to_composer_pubsub_topic    = coalesce(try(var.landing_to_composer_trigger.pubsub_topic_name, null), "${var.project_id}-ps-ingesta-sap-${var.region}")
  landing_to_composer_source_dir = (
    try(var.landing_to_composer_trigger.source_dir, null) == null ?
    abspath("${path.root}/../../../../functions/clf-ingesta-sap") :
    (
      startswith(var.landing_to_composer_trigger.source_dir, "/") ?
      var.landing_to_composer_trigger.source_dir :
      abspath("${path.root}/${var.landing_to_composer_trigger.source_dir}")
    )
  )
  landing_to_composer_source_object_prefix = coalesce(try(var.landing_to_composer_trigger.source_object_prefix, null), "functions/${local.landing_to_composer_function_name}")
  landing_to_composer_source_bucket_name   = coalesce(try(var.landing_to_composer_trigger.source_archive_bucket_name, null), local.dags_bucket_name)
  landing_to_composer_entry_point          = coalesce(try(var.landing_to_composer_trigger.entry_point, null), "trigger_dag")
  landing_to_composer_runtime              = coalesce(try(var.landing_to_composer_trigger.runtime, null), "python311")
  landing_to_composer_cpu                  = coalesce(try(var.landing_to_composer_trigger.available_cpu, null), "1")
  landing_to_composer_memory               = coalesce(try(var.landing_to_composer_trigger.available_memory, null), "512M")
  landing_to_composer_timeout_seconds      = coalesce(try(var.landing_to_composer_trigger.timeout_seconds, null), 300)
  landing_to_composer_min_instances        = coalesce(try(var.landing_to_composer_trigger.min_instance_count, null), 0)
  landing_to_composer_max_instances        = coalesce(try(var.landing_to_composer_trigger.max_instance_count, null), 100)
  landing_to_composer_max_request_concurrency = coalesce(
    try(var.landing_to_composer_trigger.max_instance_request_concurrency, null),
    80
  )
  landing_to_composer_ingress_settings    = coalesce(try(var.landing_to_composer_trigger.ingress_settings, null), "ALLOW_ALL")
  landing_to_composer_object_name_prefix  = coalesce(try(var.landing_to_composer_trigger.object_name_prefix, null), "raw/sap/")
  landing_to_composer_retry_policy        = coalesce(try(var.landing_to_composer_trigger.retry_policy, null), "RETRY_POLICY_DO_NOT_RETRY")
  landing_to_composer_extra_env           = coalesce(try(var.landing_to_composer_trigger.environment_variables, null), {})
  landing_to_composer_grant_eventarc_role = coalesce(try(var.landing_to_composer_trigger.eventarc_receiver_project_role, null), true)
  landing_to_composer_eventarc_sub_tuning_requested = (
    local.landing_to_composer_trigger_enabled &&
    coalesce(try(var.landing_to_composer_trigger.eventarc_subscription_tuning.enabled, null), false)
  )
  landing_to_composer_eventarc_subscription_name = try(var.landing_to_composer_trigger.eventarc_subscription_tuning.subscription_name, null)
  landing_to_composer_eventarc_sub_tuning_enabled = (
    local.landing_to_composer_eventarc_sub_tuning_requested &&
    try(length(trimspace(local.landing_to_composer_eventarc_subscription_name)) > 0, false)
  )
  landing_to_composer_eventarc_ack_deadline       = coalesce(try(var.landing_to_composer_trigger.eventarc_subscription_tuning.ack_deadline_seconds, null), 600)
  landing_to_composer_eventarc_min_backoff        = coalesce(try(var.landing_to_composer_trigger.eventarc_subscription_tuning.minimum_backoff, null), "10s")
  landing_to_composer_eventarc_max_backoff        = coalesce(try(var.landing_to_composer_trigger.eventarc_subscription_tuning.maximum_backoff, null), "600s")
  landing_to_composer_build_service_account_email = "${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

# Validate generated Composer, bucket and Dataform names.
check "generated_names_are_valid" {
  assert {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", local.composer_environment_name))
    error_message = "Generated composer environment name is invalid. Set composer.environment_name with a valid value."
  }

  assert {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", local.composer_service_account_id))
    error_message = "Generated Composer service account id is invalid. Set composer.service_account_id with a valid value."
  }

  assert {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", local.dags_bucket_name))
    error_message = "Generated DAGs bucket name is invalid. Set dags_bucket.name with a valid bucket name."
  }

  assert {
    condition     = lower(local.dags_bucket_location) == lower(var.region)
    error_message = "dags_bucket.location must match region for Composer custom bucket support."
  }

  assert {
    condition     = can(regex("^[a-z][a-z0-9-]{2,62}$", local.dataform_repository_name))
    error_message = "Generated Dataform repository name is invalid. Set dataform.repository_name with a valid value."
  }

  assert {
    condition     = can(regex("^[A-Za-z0-9_-]{1,255}$", local.dataform_git_token_secret_name))
    error_message = "Generated Dataform Git token secret name is invalid. Set dataform.git_token_secret_name with a valid value."
  }

  assert {
    condition     = can(regex("^[a-z][a-z0-9-]{2,62}$", local.dataform_release_config_name))
    error_message = "Generated Dataform release config name is invalid. Set dataform.release_config.name with a valid value."
  }

  assert {
    condition     = can(regex("^[a-z][a-z0-9-]{2,62}$", local.dataform_workflow_config_name))
    error_message = "Generated Dataform workflow config name is invalid. Set dataform.workflow_config.name with a valid value."
  }
}

# Validate Dataform input requirements before provisioning resources.
check "dataform_inputs_are_valid" {
  assert {
    condition     = !local.dataform_enabled || local.dataform_git_remote_url != null
    error_message = "dataform.git_remote_url is required when dataform.enabled is true."
  }

  assert {
    condition     = !local.dataform_enabled || length(trimspace(local.dataform_git_token_secret_version)) > 0
    error_message = "dataform.git_token_secret_version is required when dataform.enabled is true."
  }

  assert {
    condition     = !local.dataform_enabled || !local.dataform_release_config_enabled || local.dataform_release_git_commitish != null
    error_message = "dataform.release_config.git_commitish is required when dataform.release_config.enabled is true."
  }

  assert {
    condition     = !local.dataform_enabled || !local.dataform_workflow_config_enabled || local.dataform_release_config_enabled
    error_message = "dataform.workflow_config.enabled requires dataform.release_config.enabled."
  }
}

# Validate optional landing->Composer trigger configuration.
check "landing_to_composer_trigger_inputs_are_valid" {
  assert {
    condition     = !local.landing_to_composer_trigger_enabled || length(trimspace(var.landing_bucket_name)) > 0
    error_message = "landing_bucket_name is required when landing_to_composer_trigger.enabled is true."
  }

  assert {
    condition     = !local.landing_to_composer_trigger_enabled || can(fileset(local.landing_to_composer_source_dir, "main.py"))
    error_message = "landing_to_composer_trigger.source_dir must contain main.py."
  }

  assert {
    condition     = !local.landing_to_composer_trigger_enabled || can(fileset(local.landing_to_composer_source_dir, "requirements.txt"))
    error_message = "landing_to_composer_trigger.source_dir must contain requirements.txt."
  }

  assert {
    condition     = !local.landing_to_composer_trigger_enabled || can(regex("^https://", module.composer_environment.airflow_uri))
    error_message = "Composer Airflow URI must be HTTPS when landing_to_composer_trigger is enabled."
  }

  # subscription_name may be discovered later (Eventarc creates it after the first apply)
  # and injected through the env wrapper override auto.tfvars file.
}

# Create custom GCS bucket used by Composer for DAG storage.
module "dags_bucket" {
  source = "../../modules/gcs_bucket"

  force_destroy            = local.dags_bucket_force_destroy
  location                 = local.dags_bucket_location
  name                     = local.dags_bucket_name
  project_id               = var.project_id
  public_access_prevention = local.dags_bucket_public_access_prevention
  storage_class            = local.dags_bucket_storage_class
  versioning_enabled       = local.dags_bucket_versioning_enabled
  labels                   = local.common_labels
}

# Resolve current project metadata (used for managed service-account conventions).
data "google_project" "current" {
  project_id = var.project_id
}

# Ensure Cloud Composer service agent exists in the project.
resource "google_project_service_identity" "composer_service_agent" {
  provider = google-beta

  project = var.project_id
  service = "composer.googleapis.com"
}

# Create user-managed service account for Composer workloads.
resource "google_service_account" "composer" {
  project      = var.project_id
  account_id   = local.composer_service_account_id
  display_name = "Composer Service Account (${var.environment})"
  description  = "Service account used by Composer in ${var.service_name}-${var.environment}."
}

# Grant Composer worker role to the user-managed Composer service account.
resource "google_project_iam_member" "composer_worker" {
  project = var.project_id
  role    = "roles/composer.worker"
  member  = "serviceAccount:${google_service_account.composer.email}"
}

# Grant BigQuery job execution permissions to the Composer service account.
resource "google_project_iam_member" "composer_bigquery_job_user" {
  count = local.composer_grant_bigquery_job_user ? 1 : 0

  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.composer.email}"
}

# Grant dataset-scoped BigQuery write permissions to the Composer service account.
resource "google_bigquery_dataset_iam_member" "composer_bigquery_data_editor" {
  for_each = local.composer_bigquery_data_editor_dataset_ids

  project    = var.project_id
  dataset_id = each.value
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.composer.email}"
}

# Allow Composer service agent to operate the Composer service account.
resource "google_service_account_iam_member" "composer_service_agent_extension" {
  service_account_id = google_service_account.composer.name
  role               = "roles/composer.ServiceAgentV2Ext"
  member             = google_project_service_identity.composer_service_agent.member
}

# Provision Cloud Composer 3 environment attached to foundation network.
module "composer_environment" {
  source = "../../modules/composer3_env"

  airflow_config_overrides          = local.composer_airflow_config_overrides
  composer_image_version            = local.composer_image_version
  composer_internal_ipv4_cidr_block = local.composer_internal_ipv4_cidr_block
  dags_bucket_name                  = module.dags_bucket.name
  enable_private_builds_only        = local.composer_enable_private_builds_only
  enable_private_environment        = local.composer_enable_private_environment
  env_variables                     = local.composer_env_variables
  environment_size                  = local.composer_environment_size
  labels                            = local.common_labels
  name                              = local.composer_environment_name
  network                           = var.network_self_link
  project_id                        = var.project_id
  pypi_packages                     = local.composer_pypi_packages
  region                            = var.region
  service_account_email             = google_service_account.composer.email
  subnetwork                        = var.subnetwork_self_link
  worker_max_count                  = local.composer_worker_max_count
  worker_min_count                  = local.composer_worker_min_count

  depends_on = [
    google_project_iam_member.composer_worker,
    google_project_iam_member.composer_bigquery_job_user,
    google_bigquery_dataset_iam_member.composer_bigquery_data_editor,
    google_service_account_iam_member.composer_service_agent_extension,
    module.dags_bucket,
  ]
}

# Package Cloud Function source code to an archive for deployment.
data "archive_file" "landing_to_composer_source" {
  count = local.landing_to_composer_trigger_enabled ? 1 : 0

  type        = "zip"
  source_dir  = local.landing_to_composer_source_dir
  output_path = "${path.root}/.terraform/${local.landing_to_composer_function_name}.zip"
}

# Discover the Google-managed Cloud Storage service account used to publish notifications.
data "google_storage_project_service_account" "landing_notifications" {
  count = local.landing_to_composer_trigger_enabled ? 1 : 0

  project = var.project_id
}

# Create Pub/Sub topic that receives landing bucket object finalize notifications.
resource "google_pubsub_topic" "landing_to_composer" {
  count = local.landing_to_composer_trigger_enabled ? 1 : 0

  project = var.project_id
  name    = local.landing_to_composer_pubsub_topic

  labels = local.common_labels
}

# Allow Cloud Storage notifications to publish messages into the Pub/Sub topic.
resource "google_pubsub_topic_iam_member" "landing_notifications_publisher" {
  count = local.landing_to_composer_trigger_enabled ? 1 : 0

  project = var.project_id
  topic   = google_pubsub_topic.landing_to_composer[0].name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.landing_notifications[0].email_address}"
}

# Create user-managed runtime service account for the Cloud Function.
resource "google_service_account" "landing_to_composer_runtime" {
  count = local.landing_to_composer_trigger_enabled ? 1 : 0

  project      = var.project_id
  account_id   = local.landing_to_composer_runtime_sa_id
  display_name = "Landing DAG Trigger Runtime (${var.environment})"
  description  = "Runtime service account for the landing->Composer DAG trigger function."
}

# Grant Composer access to the Cloud Function runtime service account.
resource "google_project_iam_member" "landing_to_composer_runtime_composer_user" {
  count = local.landing_to_composer_trigger_enabled ? 1 : 0

  project = var.project_id
  role    = "roles/composer.user"
  member  = "serviceAccount:${google_service_account.landing_to_composer_runtime[0].email}"
}

# Create user-managed Eventarc trigger service account for invoking the function.
resource "google_service_account" "landing_to_composer_eventarc" {
  count = local.landing_to_composer_trigger_enabled ? 1 : 0

  project      = var.project_id
  account_id   = local.landing_to_composer_trigger_sa_id
  display_name = "Landing DAG Trigger Eventarc (${var.environment})"
  description  = "Service account used by Eventarc to deliver Pub/Sub events to the landing->Composer DAG trigger function."
}

# Grant minimum project roles needed by the Cloud Function Gen2 build service account.
# This avoids build failures when org policies force Cloud Build to run as the Compute default SA.
resource "google_project_iam_member" "landing_to_composer_build_service_account_roles" {
  for_each = local.landing_to_composer_trigger_enabled ? toset([
    "roles/artifactregistry.writer",
    "roles/storage.objectViewer",
    "roles/logging.logWriter",
  ]) : toset([])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${local.landing_to_composer_build_service_account_email}"
}

# Allow Eventarc trigger service account to invoke Cloud Run-backed Gen2 functions.
resource "google_project_iam_member" "landing_to_composer_eventarc_run_invoker" {
  count = local.landing_to_composer_trigger_enabled ? 1 : 0

  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.landing_to_composer_eventarc[0].email}"
}

# Optionally grant Eventarc event receiver role to the Eventarc trigger service account.
resource "google_project_iam_member" "landing_to_composer_eventarc_event_receiver" {
  count = local.landing_to_composer_trigger_enabled && local.landing_to_composer_grant_eventarc_role ? 1 : 0

  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.landing_to_composer_eventarc[0].email}"
}

# Upload the Cloud Function source archive to the configured source bucket.
resource "google_storage_bucket_object" "landing_to_composer_source_archive" {
  count = local.landing_to_composer_trigger_enabled ? 1 : 0

  bucket = local.landing_to_composer_source_bucket_name
  name   = "${trim(local.landing_to_composer_source_object_prefix, "/")}/${data.archive_file.landing_to_composer_source[0].output_sha}.zip"
  source = data.archive_file.landing_to_composer_source[0].output_path

  # The bucket name is a string local, so Terraform cannot infer dependency on the managed DAGs bucket.
  depends_on = [module.dags_bucket]
}

# Deploy a Gen2 Cloud Function that maps landing files to Composer DAG triggers.
resource "google_cloudfunctions2_function" "landing_to_composer" {
  provider = google-beta
  count    = local.landing_to_composer_trigger_enabled ? 1 : 0

  project     = var.project_id
  location    = var.region
  name        = local.landing_to_composer_function_name
  description = "Triggers Composer DAGs when new landing files arrive in GCS."

  build_config {
    runtime     = local.landing_to_composer_runtime
    entry_point = local.landing_to_composer_entry_point

    source {
      storage_source {
        bucket     = google_storage_bucket_object.landing_to_composer_source_archive[0].bucket
        object     = google_storage_bucket_object.landing_to_composer_source_archive[0].name
        generation = google_storage_bucket_object.landing_to_composer_source_archive[0].generation
      }
    }
  }

  service_config {
    available_cpu                    = local.landing_to_composer_cpu
    available_memory                 = local.landing_to_composer_memory
    timeout_seconds                  = local.landing_to_composer_timeout_seconds
    min_instance_count               = local.landing_to_composer_min_instances
    max_instance_count               = local.landing_to_composer_max_instances
    max_instance_request_concurrency = local.landing_to_composer_max_request_concurrency
    ingress_settings                 = local.landing_to_composer_ingress_settings
    service_account_email            = google_service_account.landing_to_composer_runtime[0].email

    environment_variables = merge(
      {
        AIRFLOW_URL = module.composer_environment.airflow_uri
      },
      local.landing_to_composer_extra_env
    )
  }

  event_trigger {
    trigger_region        = var.region
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = google_pubsub_topic.landing_to_composer[0].id
    retry_policy          = local.landing_to_composer_retry_policy
    service_account_email = google_service_account.landing_to_composer_eventarc[0].email
  }

  depends_on = [
    google_project_iam_member.landing_to_composer_runtime_composer_user,
    google_project_iam_member.landing_to_composer_eventarc_run_invoker,
    google_project_iam_member.landing_to_composer_build_service_account_roles,
    google_pubsub_topic_iam_member.landing_notifications_publisher,
  ]
}

# Configure landing bucket notifications to publish object finalize events to Pub/Sub.
resource "google_storage_notification" "landing_to_composer" {
  count = local.landing_to_composer_trigger_enabled ? 1 : 0

  bucket             = var.landing_bucket_name
  topic              = google_pubsub_topic.landing_to_composer[0].id
  payload_format     = "JSON_API_V1"
  event_types        = ["OBJECT_FINALIZE"]
  object_name_prefix = local.landing_to_composer_object_name_prefix

  depends_on = [google_pubsub_topic_iam_member.landing_notifications_publisher]
}

# Optionally tune the Eventarc-managed Pub/Sub subscription after importing it into Terraform state.
resource "google_pubsub_subscription" "landing_to_composer_eventarc_delivery" {
  count = local.landing_to_composer_eventarc_sub_tuning_enabled ? 1 : 0

  project = var.project_id
  name    = local.landing_to_composer_eventarc_subscription_name
  topic   = google_pubsub_topic.landing_to_composer[0].id

  ack_deadline_seconds = local.landing_to_composer_eventarc_ack_deadline

  retry_policy {
    minimum_backoff = local.landing_to_composer_eventarc_min_backoff
    maximum_backoff = local.landing_to_composer_eventarc_max_backoff
  }

  lifecycle {
    ignore_changes = [push_config]
  }

  depends_on = [google_cloudfunctions2_function.landing_to_composer]
}

# Ensure Dataform service agent exists in the project.
resource "google_project_service_identity" "dataform_service_agent" {
  provider = google-beta
  count    = local.dataform_enabled ? 1 : 0

  project = var.project_id
  service = "dataform.googleapis.com"
}

# Wait for Dataform service-agent propagation before applying IAM bindings.
resource "time_sleep" "dataform_service_agent_propagation" {
  count = local.dataform_enabled ? 1 : 0

  create_duration = "60s"

  depends_on = [google_project_service_identity.dataform_service_agent]
}

# Allow Dataform service agent to run BigQuery jobs.
resource "google_project_iam_member" "dataform_bigquery_job_user" {
  count = local.dataform_enabled ? 1 : 0

  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = google_project_service_identity.dataform_service_agent[0].member

  depends_on = [time_sleep.dataform_service_agent_propagation]
}

# Allow Dataform service agent to read/write BigQuery datasets and tables.
resource "google_project_iam_member" "dataform_bigquery_data_editor" {
  count = local.dataform_enabled ? 1 : 0

  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = google_project_service_identity.dataform_service_agent[0].member

  depends_on = [time_sleep.dataform_service_agent_propagation]
}

# Grant Dataform service agent access to the Git PAT secret.
resource "google_secret_manager_secret_iam_member" "dataform_gitlab_pat_accessor" {
  count = local.dataform_enabled ? 1 : 0

  project   = var.project_id
  secret_id = local.dataform_git_token_secret_name
  role      = "roles/secretmanager.secretAccessor"
  member    = google_project_service_identity.dataform_service_agent[0].member

  depends_on = [time_sleep.dataform_service_agent_propagation]
}

# Create Dataform repository connected to external Git over HTTPS.
resource "google_dataform_repository" "this" {
  provider = google-beta
  count    = local.dataform_enabled ? 1 : 0

  project         = var.project_id
  region          = var.region
  name            = local.dataform_repository_name
  deletion_policy = "FORCE"

  git_remote_settings {
    url                                 = local.dataform_git_remote_url
    default_branch                      = local.dataform_git_remote_default_branch
    authentication_token_secret_version = local.dataform_git_token_secret_version_resource
  }

  depends_on = [google_secret_manager_secret_iam_member.dataform_gitlab_pat_accessor]
}

# Create Dataform release config to pin compilation to an environment branch.
resource "google_dataform_repository_release_config" "this" {
  provider = google-beta
  count    = local.dataform_enabled && local.dataform_release_config_enabled ? 1 : 0

  name          = local.dataform_release_config_name
  project       = var.project_id
  region        = var.region
  repository    = google_dataform_repository.this[0].name
  git_commitish = local.dataform_release_git_commitish
  cron_schedule = local.dataform_release_cron_schedule
  time_zone     = local.dataform_release_cron_schedule == null ? null : local.dataform_release_time_zone

  dynamic "code_compilation_config" {
    for_each = local.dataform_release_compilation_cfg == null ? [] : [local.dataform_release_compilation_cfg]

    content {
      assertion_schema = try(code_compilation_config.value.assertion_schema, null)
      database_suffix  = try(code_compilation_config.value.database_suffix, null)
      default_database = try(code_compilation_config.value.default_database, null)
      default_location = try(code_compilation_config.value.default_location, null)
      default_schema   = try(code_compilation_config.value.default_schema, null)
      schema_suffix    = try(code_compilation_config.value.schema_suffix, null)
      table_prefix     = try(code_compilation_config.value.table_prefix, null)
      vars             = try(code_compilation_config.value.vars, null)
    }
  }

  depends_on = [google_dataform_repository.this]
}

# Create Dataform workflow config to schedule executions from the release config.
resource "google_dataform_repository_workflow_config" "this" {
  provider = google-beta
  count    = local.dataform_enabled && local.dataform_workflow_config_enabled ? 1 : 0

  name           = local.dataform_workflow_config_name
  project        = var.project_id
  region         = var.region
  repository     = google_dataform_repository.this[0].name
  release_config = google_dataform_repository_release_config.this[0].id
  cron_schedule  = local.dataform_workflow_cron_schedule
  time_zone      = local.dataform_workflow_cron_schedule == null ? null : local.dataform_workflow_time_zone

  depends_on = [google_dataform_repository_release_config.this]
}
