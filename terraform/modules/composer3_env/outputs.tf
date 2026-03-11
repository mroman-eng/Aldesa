output "id" {
  description = "Composer environment resource id."
  value       = google_composer_environment.this.id
}

output "name" {
  description = "Composer environment name."
  value       = google_composer_environment.this.name
}

output "airflow_uri" {
  description = "Airflow web UI URI."
  value       = google_composer_environment.this.config[0].airflow_uri
}

output "dag_gcs_prefix" {
  description = "DAGs prefix path inside the configured bucket."
  value       = google_composer_environment.this.config[0].dag_gcs_prefix
}

output "gke_cluster" {
  description = "Underlying GKE cluster for the Composer environment."
  value       = google_composer_environment.this.config[0].gke_cluster
}
