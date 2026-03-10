project_id   = "data-buildtrack-dev"
environment  = "dev"
region       = "europe-west1"
service_name = "aldesa-buildtrack"

additional_labels = {}

landing_bucket = {
  name     = "data-buildtrack-dev-ingesta-sap-europe-west1"
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
  prps = {}
}

bronze_tables = {
  proj = {
    description = "Carga INCREMENTAL de PROJ. Acumula los deltas de SAP."
    time_partitioning = {
      type  = "DAY"
      field = "ingestion_timestamp_bronze"
    }
    clustering_fields = ["PSPNR"]
  }
  prps = {
    description = "Carga INCREMENTAL de PRPS. Acumula los deltas de SAP."
    time_partitioning = {
      type  = "DAY"
      field = "ingestion_timestamp_bronze"
    }
    clustering_fields = ["PSPNR"]
  }
}

silver_tables = {
  proj = {
    description = "Carga INCREMENTAL de PROJ con nombres de campo legibles y reglas de calidad aplicadas."
    time_partitioning = {
      type  = "DAY"
      field = "ingestion_timestamp_silver"
    }
    clustering_fields = ["PSPNR"]
  }
}

gold_tables = {
  proj = {}
  peps = {}
}

alerts_tables = {
  proj_bronze = {}
  proj_silver = {}
}

logs_tables = {
  dag_logs = {}
}
