project_id   = "data-buildtrack-pro"
environment  = "pro"
region       = "europe-west1"
service_name = "aldesa-buildtrack"

additional_labels = {}

storage_bq_remote_state = {
  bucket            = "data-buildtrack-pro-tfstate-europe-west1"
  storage_bq_prefix = "pro/20-storage-bq"
}

governed_resources = {
  bronze_dataset_id = "pro_bronze"
  silver_dataset_id = "pro_silver"
  gold_dataset_id   = "pro_gold"
}

auto_profile_scans = {
  enabled = false
}

dataplex_datascans = {}
