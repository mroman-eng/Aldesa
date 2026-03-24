project_id   = "data-buildtrack-dev"
environment  = "pre"
region       = "europe-west1"
service_name = "aldesa-buildtrack"

additional_labels = {}

landing_bucket = {
  name     = "pre-data-buildtrack-dev-ingesta-sap-europe-west1"
  location = "europe-west1"
}

bronze_parquet_bucket = {
  name                                  = "pre-data-buildtrack-dev-bronze-parquet-europe-west1"
  location                              = "europe-west1"
  versioning_enabled                    = true
  delete_noncurrent_versions_after_days = 30
}

datasphere_ingest_sa_id_override            = "dsp-aldesa-buildtrack-dev"
datasphere_ingest_sa_key_secret_id_override = "dsp-aldesa-buildtrack-dev-sa-key"
datasphere_landing_bucket_roles             = ["roles/storage.legacyBucketReader"] # Added on top of the default landing-bucket role: roles/storage.objectUser
dataform_git_token_secret_id_override       = "sec-aldesa-buildtrack-dev-dataform-github-pat"

dataset_ids = {
  assertions = "pre_assertions"
  bronze     = "pre_bronze"
  silver     = "pre_silver"
  gold       = "pre_gold"
}

bigquery_location_override = "europe-west1"
