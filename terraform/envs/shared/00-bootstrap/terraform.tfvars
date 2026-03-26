project_id   = "data-buildtrack-dev"
environment  = "shared"
region       = "europe-west1"
service_name = "aldesa-buildtrack"

additional_labels = {}

state_bucket_name_override   = "data-buildtrack-dev-tfstate-europe-west1"
kms_key_ring_name_override   = "kr-aldesa-buildtrack-dev-sops"
kms_crypto_key_name_override = "ck-aldesa-buildtrack-dev-sops"

bootstrap_services = [
  "artifactregistry.googleapis.com",
  "bigquery.googleapis.com",
  "cloudbuild.googleapis.com",
  "cloudfunctions.googleapis.com",
  "cloudkms.googleapis.com",
  "composer.googleapis.com",
  "compute.googleapis.com",
  "dataform.googleapis.com",
  "dataplex.googleapis.com",
  "eventarc.googleapis.com",
  "iam.googleapis.com",
  "monitoring.googleapis.com",
  "pubsub.googleapis.com",
  "run.googleapis.com",
  "secretmanager.googleapis.com",
  "serviceusage.googleapis.com",
  "storage.googleapis.com",
]

terraform_admin_roles = [
  "roles/artifactregistry.admin",
  "roles/bigquery.admin",
  "roles/cloudbuild.builds.editor",
  "roles/cloudfunctions.admin",
  "roles/composer.admin",
  "roles/compute.networkAdmin",
  "roles/compute.securityAdmin",
  "roles/dataform.admin",
  "roles/dataplex.admin",
  "roles/eventarc.admin",
  "roles/iam.serviceAccountAdmin",
  "roles/iam.serviceAccountUser",
  "roles/pubsub.admin",
  "roles/monitoring.editor",
  "roles/run.admin",
  "roles/secretmanager.admin",
  "roles/serviceusage.serviceUsageAdmin",
  "roles/storage.admin",
]
