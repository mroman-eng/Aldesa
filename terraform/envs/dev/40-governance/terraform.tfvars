project_id   = "data-buildtrack-dev"
environment  = "dev"
region       = "europe-west1"
service_name = "aldesa-buildtrack"

additional_labels = {}

storage_bq_remote_state = {
  bucket            = "data-buildtrack-dev-tfstate-europe-west1"
  storage_bq_prefix = "dev/20-storage-bq"
}

governed_resources = {
  raw_dataset_id    = "raw"
  bronze_dataset_id = "bronze"
  silver_dataset_id = "silver"
  gold_dataset_id   = "gold"
}

auto_profile_scans = {
  enabled        = true
  include_layers = ["raw", "bronze", "silver"]
}

dataplex_datascans = {
  # Optional custom profile scan definitions.
  # If a key matches an auto-generated scan id, this block overrides that scan.
  #
  # profile_scans = {
  #   dps-proj-raw = {
  #     display_name = "dps_proj_raw_custom"
  #     layer        = "raw"
  #     table_id     = "proj"
  #     execution = {
  #       trigger_mode  = "SCHEDULE"
  #       schedule_cron = "0 */6 * * *"
  #     }
  #     sampling_percent = 20
  #     row_filter       = "MANDT IS NOT NULL"
  #   }
  # }

  quality_scans = {
    dqs-proj-raw = {
      display_name = "dqs_proj_raw"
      layer        = "raw"
      table_id     = "proj"
      execution = {
        trigger_mode = "ON_DEMAND"
      }
      rules = [
        {
          name        = "non-empty-table"
          description = "Basic table condition placeholder."
          dimension   = "VALIDITY"
          table_condition_expectation = {
            sql_expression = "TRUE"
          }
        }
      ]
    }
  }
}
