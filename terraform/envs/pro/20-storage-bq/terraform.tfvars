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

dataset_ids = {
  assertions = "pro_assertions"
  bronze     = "pro_bronze"
  silver     = "pro_silver"
  gold       = "pro_gold"
}

bigquery_location_override = "europe-west1"
