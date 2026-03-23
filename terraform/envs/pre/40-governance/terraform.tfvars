project_id   = "data-buildtrack-dev"
environment  = "pre"
region       = "europe-west1"
service_name = "aldesa-buildtrack"

additional_labels = {}

storage_bq_remote_state = {
  bucket            = "data-buildtrack-dev-tfstate-europe-west1"
  storage_bq_prefix = "pre/20-storage-bq"
}

governed_resources = {
  bronze_dataset_id = "pre_bronze"
  silver_dataset_id = "pre_silver"
  gold_dataset_id   = "pre_gold"
}

auto_profile_scans = {
  enabled = false
}

dataplex_datascans = {}
