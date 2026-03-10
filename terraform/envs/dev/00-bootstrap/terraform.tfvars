project_id   = "data-buildtrack-dev"
environment  = "dev"
region       = "europe-west1"
service_name = "aldesa-buildtrack"

additional_labels = {}

bootstrap_services = [
  "artifactregistry.googleapis.com",
  "bigquery.googleapis.com",
  "bigquerydatatransfer.googleapis.com",
  "cloudbuild.googleapis.com",
  "cloudfunctions.googleapis.com",
  "cloudkms.googleapis.com",
  "composer.googleapis.com",
  "compute.googleapis.com",
  "dataform.googleapis.com",
  "dataplex.googleapis.com",
  "eventarc.googleapis.com",
  "iam.googleapis.com",
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
  "roles/run.admin",
  "roles/secretmanager.admin",
  "roles/serviceusage.serviceUsageAdmin",
  "roles/storage.admin",
]
