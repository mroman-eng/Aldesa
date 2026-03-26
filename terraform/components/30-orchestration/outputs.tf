output "project_id" {
  description = "Orchestration target project."
  value       = var.project_id
}

output "composer_config" {
  description = "Effective Composer configuration."
  value = {
    airflow_config_overrides = local.composer_airflow_config_overrides
    bigquery_access = {
      dataset_data_editor_ids = tolist(local.composer_bigquery_data_editor_dataset_ids)
      grant_job_user          = local.composer_grant_bigquery_job_user
    }
    enable_private_builds_only = local.composer_enable_private_builds_only
    enable_private_environment = local.composer_enable_private_environment
    env_variables              = local.composer_env_variables
    environment_name           = local.composer_environment_name
    environment_size           = local.composer_environment_size
    image_version              = local.composer_image_version
    internal_ipv4_cidr_block   = local.composer_internal_ipv4_cidr_block
    pypi_packages              = local.composer_pypi_packages
    scheduler_count            = local.composer_scheduler_count
    scheduler_cpu              = local.composer_scheduler_cpu
    scheduler_memory_gb        = local.composer_scheduler_memory_gb
    scheduler_storage_gb       = local.composer_scheduler_storage_gb
    dag_processor_count        = local.composer_dag_processor_count
    dag_processor_cpu          = local.composer_dag_processor_cpu
    dag_processor_memory_gb    = local.composer_dag_processor_memory_gb
    dag_processor_storage_gb   = local.composer_dag_processor_storage_gb
    service_account_id         = local.composer_service_account_id
    triggerer_count            = local.composer_triggerer_count
    triggerer_cpu              = local.composer_triggerer_cpu
    triggerer_memory_gb        = local.composer_triggerer_memory_gb
    web_server_cpu             = local.composer_web_server_cpu
    web_server_memory_gb       = local.composer_web_server_memory_gb
    web_server_storage_gb      = local.composer_web_server_storage_gb
    worker_cpu                 = local.composer_worker_cpu
    worker_max_count           = local.composer_worker_max_count
    worker_memory_gb           = local.composer_worker_memory_gb
    worker_min_count           = local.composer_worker_min_count
    worker_storage_gb          = local.composer_worker_storage_gb
  }
}

output "composer_bigquery_access" {
  description = "Effective BigQuery IAM grants for the Composer service account."
  value = {
    dataset_data_editor_ids = tolist(local.composer_bigquery_data_editor_dataset_ids)
    grant_job_user          = local.composer_grant_bigquery_job_user
  }
}

output "composer_environment_id" {
  description = "Composer environment resource id."
  value       = module.composer_environment.id
}

output "composer_environment_name" {
  description = "Composer environment name."
  value       = module.composer_environment.name
}

output "composer_airflow_uri" {
  description = "Airflow web server URI."
  value       = module.composer_environment.airflow_uri
}

output "composer_dag_gcs_prefix" {
  description = "DAG GCS prefix exposed by Composer."
  value       = module.composer_environment.dag_gcs_prefix
}

output "composer_gke_cluster" {
  description = "Underlying GKE cluster used by Composer."
  value       = module.composer_environment.gke_cluster
}

output "composer_service_account_email" {
  description = "User-managed Composer service account email."
  value       = google_service_account.composer.email
}

output "composer_service_agent_email" {
  description = "Composer service agent email for this project."
  value       = google_project_service_identity.composer_service_agent.email
}

output "dags_bucket_config" {
  description = "Effective Composer DAG bucket configuration."
  value = {
    force_destroy            = local.dags_bucket_force_destroy
    location                 = local.dags_bucket_location
    name                     = local.dags_bucket_name
    public_access_prevention = local.dags_bucket_public_access_prevention
    storage_class            = local.dags_bucket_storage_class
    versioning_enabled       = local.dags_bucket_versioning_enabled
  }
}

output "dags_bucket_name" {
  description = "Custom DAG bucket name used by Composer."
  value       = module.dags_bucket.name
}

output "landing_to_composer_trigger_config" {
  description = "Effective config for the optional landing->Composer DAG trigger function."
  value = {
    enabled                          = local.landing_to_composer_trigger_enabled
    function_name                    = local.landing_to_composer_function_name
    runtime_service_account_id       = local.landing_to_composer_runtime_sa_id
    trigger_service_account_id       = local.landing_to_composer_trigger_sa_id
    pubsub_topic_name                = local.landing_to_composer_pubsub_topic
    source_dir                       = local.landing_to_composer_source_dir
    source_object_prefix             = local.landing_to_composer_source_object_prefix
    source_archive_bucket_name       = local.landing_to_composer_source_bucket_name
    object_name_prefix               = local.landing_to_composer_object_name_prefix
    airflow_url                      = module.composer_environment.airflow_uri
    available_cpu                    = local.landing_to_composer_cpu
    available_memory                 = local.landing_to_composer_memory
    timeout_seconds                  = local.landing_to_composer_timeout_seconds
    min_instance_count               = local.landing_to_composer_min_instances
    max_instance_count               = local.landing_to_composer_max_instances
    max_instance_request_concurrency = local.landing_to_composer_max_request_concurrency
    ingress_settings                 = local.landing_to_composer_ingress_settings
    retry_policy                     = local.landing_to_composer_retry_policy
    eventarc_receiver_project_role   = local.landing_to_composer_grant_eventarc_role
    eventarc_subscription_tuning = {
      enabled                                 = local.landing_to_composer_eventarc_sub_tuning_requested
      subscription_name                       = local.landing_to_composer_eventarc_subscription_name
      ack_deadline_seconds                    = local.landing_to_composer_eventarc_ack_deadline
      minimum_backoff                         = local.landing_to_composer_eventarc_min_backoff
      maximum_backoff                         = local.landing_to_composer_eventarc_max_backoff
      dead_letter_enabled                     = local.landing_to_composer_eventarc_dead_letter_requested
      dead_letter_topic_name                  = local.landing_to_composer_eventarc_dead_letter_topic_name
      dead_letter_subscription_name           = local.landing_to_composer_eventarc_dead_letter_subscription_name
      dead_letter_max_delivery_attempts       = local.landing_to_composer_eventarc_dead_letter_max_delivery_attempts
      dead_letter_alert_enabled               = local.landing_to_composer_eventarc_dead_letter_alert_requested
      dead_letter_alert_notification_channels = local.landing_to_composer_eventarc_dead_letter_alert_notification_channels
      dead_letter_managed_by_terraform        = local.landing_to_composer_eventarc_dead_letter_enabled
      managed_by_terraform                    = local.landing_to_composer_eventarc_sub_tuning_enabled
      import_required                         = local.landing_to_composer_eventarc_sub_tuning_requested && !local.landing_to_composer_eventarc_sub_tuning_enabled
    }
  }
}

output "landing_to_composer_function_id" {
  description = "Cloud Function Gen2 resource id for the landing->Composer DAG trigger."
  value       = try(google_cloudfunctions2_function.landing_to_composer[0].id, null)
}

output "landing_to_composer_function_service_config_uri" {
  description = "Cloud Function Gen2 service URI (Cloud Run backend) for the landing->Composer DAG trigger."
  value       = try(google_cloudfunctions2_function.landing_to_composer[0].service_config[0].uri, null)
}

output "landing_to_composer_eventarc_trigger_id" {
  description = "Eventarc trigger resource id created by Cloud Functions Gen2 (output-only from the function)."
  value       = try(google_cloudfunctions2_function.landing_to_composer[0].event_trigger[0].trigger, null)
}

output "landing_to_composer_pubsub_topic_id" {
  description = "Pub/Sub topic id used for landing bucket notifications."
  value       = try(google_pubsub_topic.landing_to_composer[0].id, null)
}

output "landing_to_composer_eventarc_subscription_tuning_resource_id" {
  description = "Imported Eventarc-managed Pub/Sub subscription resource id when subscription tuning is enabled and imported."
  value       = try(google_pubsub_subscription.landing_to_composer_eventarc_delivery[0].id, null)
}

output "landing_to_composer_eventarc_dead_letter_topic_id" {
  description = "Pub/Sub topic id used as dead-letter topic for Eventarc delivery subscription."
  value       = try(google_pubsub_topic.landing_to_composer_eventarc_dead_letter[0].id, null)
}

output "landing_to_composer_eventarc_dead_letter_subscription_id" {
  description = "Pub/Sub subscription id attached to the dead-letter topic."
  value       = try(google_pubsub_subscription.landing_to_composer_eventarc_dead_letter[0].id, null)
}

output "landing_to_composer_eventarc_dead_letter_alert_policy_id" {
  description = "Monitoring alert policy id for dead-letter messages in Eventarc delivery subscription."
  value       = try(google_monitoring_alert_policy.landing_to_composer_eventarc_dead_letter_detected[0].id, null)
}

output "landing_to_composer_runtime_service_account_email" {
  description = "Runtime service account email used by the landing->Composer DAG trigger function."
  value       = try(google_service_account.landing_to_composer_runtime[0].email, null)
}

output "landing_to_composer_eventarc_service_account_email" {
  description = "Eventarc trigger service account email used by the landing->Composer DAG trigger function."
  value       = try(google_service_account.landing_to_composer_eventarc[0].email, null)
}

output "dataform_config" {
  description = "Effective Dataform configuration."
  value = {
    enabled                      = local.dataform_enabled
    execution_service_account_id = local.dataform_execution_service_account_id
    git_remote_default_branch    = local.dataform_git_remote_default_branch
    git_remote_url               = local.dataform_git_remote_url
    git_token_secret_name        = local.dataform_git_token_secret_name
    git_token_secret_version     = local.dataform_git_token_secret_version
    release_config = {
      code_compilation_config = local.dataform_release_compilation_cfg
      cron_schedule           = local.dataform_release_cron_schedule
      enabled                 = local.dataform_release_config_enabled
      git_commitish           = local.dataform_release_git_commitish
      name                    = local.dataform_release_config_name
      time_zone               = local.dataform_release_time_zone
    }
    repository_name = local.dataform_repository_name
    workflow_config = {
      cron_schedule = local.dataform_workflow_cron_schedule
      enabled       = local.dataform_workflow_config_enabled
      name          = local.dataform_workflow_config_name
      time_zone     = local.dataform_workflow_time_zone
    }
  }
}

output "dataform_repository_id" {
  description = "Dataform repository resource id."
  value       = try(google_dataform_repository.this[0].id, null)
}

output "dataform_repository_name" {
  description = "Dataform repository name."
  value       = try(google_dataform_repository.this[0].name, null)
}

output "dataform_service_agent_email" {
  description = "Dataform service agent email for this project."
  value       = try(google_project_service_identity.dataform_service_agent[0].email, null)
}

output "dataform_execution_service_account_email" {
  description = "User-managed Dataform execution service account email."
  value       = try(google_service_account.dataform_execution[0].email, null)
}

output "dataform_git_remote_url" {
  description = "Configured external Git remote URL for Dataform."
  value       = local.dataform_git_remote_url
}

output "dataform_git_pat_secret_id" {
  description = "Secret Manager secret id used for Dataform Git PAT."
  value       = local.dataform_enabled ? "projects/${var.project_id}/secrets/${local.dataform_git_token_secret_name}" : null
}

output "dataform_git_token_secret_version_resource" {
  description = "Secret Manager secret version resource used by Dataform Git auth."
  value       = local.dataform_git_token_secret_version_resource
}

output "dataform_release_config_id" {
  description = "Dataform release config resource id."
  value       = try(google_dataform_repository_release_config.this[0].id, null)
}

output "dataform_release_config_name" {
  description = "Dataform release config name."
  value       = try(google_dataform_repository_release_config.this[0].name, null)
}

output "dataform_release_git_commitish" {
  description = "Git branch/tag/commit bound to the Dataform release config."
  value       = local.dataform_release_git_commitish
}

output "dataform_workflow_config_id" {
  description = "Dataform workflow config resource id."
  value       = try(google_dataform_repository_workflow_config.this[0].id, null)
}

output "dataform_workflow_config_name" {
  description = "Dataform workflow config name."
  value       = try(google_dataform_repository_workflow_config.this[0].name, null)
}
