output "project_id" {
  description = "Orchestration target project."
  value       = module.orchestration.project_id
}

output "composer_config" {
  description = "Effective Composer configuration."
  value       = module.orchestration.composer_config
}

output "composer_environment_id" {
  description = "Composer environment resource id."
  value       = module.orchestration.composer_environment_id
}

output "composer_environment_name" {
  description = "Composer environment name."
  value       = module.orchestration.composer_environment_name
}

output "composer_airflow_uri" {
  description = "Airflow web server URI."
  value       = module.orchestration.composer_airflow_uri
}

output "composer_dag_gcs_prefix" {
  description = "DAG GCS prefix exposed by Composer."
  value       = module.orchestration.composer_dag_gcs_prefix
}

output "composer_gke_cluster" {
  description = "Underlying GKE cluster used by Composer."
  value       = module.orchestration.composer_gke_cluster
}

output "composer_service_account_email" {
  description = "User-managed Composer service account email."
  value       = module.orchestration.composer_service_account_email
}

output "composer_service_agent_email" {
  description = "Composer service agent email for this project."
  value       = module.orchestration.composer_service_agent_email
}

output "composer_bigquery_access" {
  description = "Effective BigQuery IAM grants for the Composer service account."
  value       = module.orchestration.composer_bigquery_access
}

output "dags_bucket_config" {
  description = "Effective DAG bucket configuration."
  value       = module.orchestration.dags_bucket_config
}

output "dags_bucket_name" {
  description = "Custom DAG bucket name used by Composer."
  value       = module.orchestration.dags_bucket_name
}

output "landing_to_composer_trigger_config" {
  description = "Effective config for the optional landing->Composer DAG trigger function."
  value       = module.orchestration.landing_to_composer_trigger_config
}

output "landing_to_composer_function_id" {
  description = "Cloud Function Gen2 resource id for the landing->Composer DAG trigger."
  value       = module.orchestration.landing_to_composer_function_id
}

output "landing_to_composer_function_service_config_uri" {
  description = "Cloud Function Gen2 service URI (Cloud Run backend) for the landing->Composer DAG trigger."
  value       = module.orchestration.landing_to_composer_function_service_config_uri
}

output "landing_to_composer_eventarc_trigger_id" {
  description = "Eventarc trigger resource id created by Cloud Functions Gen2 (output-only from the function)."
  value       = module.orchestration.landing_to_composer_eventarc_trigger_id
}

output "landing_to_composer_pubsub_topic_id" {
  description = "Pub/Sub topic id used for landing bucket notifications."
  value       = module.orchestration.landing_to_composer_pubsub_topic_id
}

output "landing_to_composer_eventarc_subscription_tuning_resource_id" {
  description = "Imported Eventarc-managed Pub/Sub subscription resource id when subscription tuning is enabled and imported."
  value       = module.orchestration.landing_to_composer_eventarc_subscription_tuning_resource_id
}

output "landing_to_composer_runtime_service_account_email" {
  description = "Runtime service account email used by the landing->Composer DAG trigger function."
  value       = module.orchestration.landing_to_composer_runtime_service_account_email
}

output "landing_to_composer_eventarc_service_account_email" {
  description = "Eventarc trigger service account email used by the landing->Composer DAG trigger function."
  value       = module.orchestration.landing_to_composer_eventarc_service_account_email
}

output "dataform_config" {
  description = "Effective Dataform configuration."
  value       = module.orchestration.dataform_config
}

output "dataform_repository_id" {
  description = "Dataform repository resource id."
  value       = module.orchestration.dataform_repository_id
}

output "dataform_repository_name" {
  description = "Dataform repository name."
  value       = module.orchestration.dataform_repository_name
}

output "dataform_service_agent_email" {
  description = "Dataform service agent email for this project."
  value       = module.orchestration.dataform_service_agent_email
}

output "dataform_git_remote_url" {
  description = "Configured external Git remote URL for Dataform."
  value       = module.orchestration.dataform_git_remote_url
}

output "dataform_git_pat_secret_id" {
  description = "Secret Manager secret id used for Dataform Git PAT."
  value       = module.orchestration.dataform_git_pat_secret_id
}

output "dataform_release_config_id" {
  description = "Dataform release config resource id."
  value       = module.orchestration.dataform_release_config_id
}

output "dataform_release_config_name" {
  description = "Dataform release config name."
  value       = module.orchestration.dataform_release_config_name
}

output "dataform_release_git_commitish" {
  description = "Git branch/tag/commit bound to the Dataform release config."
  value       = module.orchestration.dataform_release_git_commitish
}

output "dataform_workflow_config_id" {
  description = "Dataform workflow config resource id."
  value       = module.orchestration.dataform_workflow_config_id
}

output "dataform_workflow_config_name" {
  description = "Dataform workflow config name."
  value       = module.orchestration.dataform_workflow_config_name
}
