project_id   = "data-buildtrack-pro"
environment  = "pro"
region       = "europe-west1"
service_name = "aldesa-buildtrack"

additional_labels = {}

landing_bucket = {
  name     = "pro-data-buildtrack-pro-ingesta-sap-europe-west1"
  location = "europe-west1"
}

bronze_parquet_bucket = {
  name                                  = "pro-data-buildtrack-pro-bronze-parquet-europe-west1"
  location                              = "europe-west1"
  versioning_enabled                    = true
  delete_noncurrent_versions_after_days = 30
}

datasphere_ingest_sa_id_override            = "dsp-aldesa-buildtrack-pro"
datasphere_ingest_sa_key_secret_id_override = "dsp-aldesa-buildtrack-pro-sa-key"
datasphere_landing_bucket_roles             = ["roles/storage.legacyBucketReader"] # Added on top of the default landing-bucket role: roles/storage.objectUser
dataform_git_token_secret_id_override       = "sec-aldesa-buildtrack-pro-dataform-github-pat"

dataset_ids = {
  assertions = "pro_assertions"
  bronze     = "pro_bronze"
  silver     = "pro_silver"
  gold       = "pro_gold"
}

bigquery_location_override = "europe-west1"
