project_id   = "data-buildtrack-pro"
environment  = "pro"
region       = "europe-west1"
service_name = "aldesa-buildtrack"

additional_labels = {}

landing_bucket = {
  name     = "data-buildtrack-pro-ingesta-sap-europe-west1"
  location = "europe-west1"
}

dataset_ids = {
  alerts = "alerts"
  logs   = "logs"
  raw    = "raw"
  bronze = "bronze"
  silver = "silver"
  gold   = "gold"
}

bigquery_location_override = "europe-west1"

raw_tables = {
  proj = {}
  peps = {}
  bkps = {}
  vibe = {}
}

bronze_tables = {
  proj = {}
  peps = {}
  bkps = {}
}

silver_tables = {
  proj = {}
  peps = {}
  bkps = {}
}

gold_tables = {
  proj = {}
  peps = {}
  bkps = {}
}

alerts_tables = {
  proj_bronze = {}
  proj_silver = {}
}

logs_tables = {
  dag_logs = {}
}
