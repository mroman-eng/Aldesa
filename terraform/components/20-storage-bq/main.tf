# Local naming and table definitions for storage and BigQuery.
locals {
  project_id_has_environment_suffix = endswith(var.project_id, "-${var.environment}")
  naming_environment_token          = local.project_id_has_environment_suffix ? "" : "-${var.environment}"

  common_labels = merge(
    {
      component    = "20-storage-bq"
      environment  = var.environment
      managed_by   = "terraform"
      project_name = var.service_name
    },
    var.additional_labels
  )

  bigquery_location = coalesce(var.bigquery_location_override, var.region)

  alerts_dataset_id     = try(var.dataset_ids.alerts, null)
  assertions_dataset_id = try(var.dataset_ids.assertions, null)
  logs_dataset_id       = try(var.dataset_ids.logs, null)
  raw_dataset_id        = try(var.dataset_ids.raw, null)
  bronze_dataset_id     = coalesce(try(var.dataset_ids.bronze, null), "bronze")
  silver_dataset_id     = coalesce(try(var.dataset_ids.silver, null), "silver")
  gold_dataset_id       = coalesce(try(var.dataset_ids.gold, null), "gold")

  landing_bucket_name                     = coalesce(try(var.landing_bucket.name, null), "${var.project_id}${local.naming_environment_token}-ingesta-sap-${var.region}")
  landing_bucket_location                 = coalesce(try(var.landing_bucket.location, null), var.region)
  landing_bucket_storage_class            = coalesce(try(var.landing_bucket.storage_class, null), "STANDARD")
  landing_bucket_force_destroy            = coalesce(try(var.landing_bucket.force_destroy, null), false)
  landing_bucket_versioning_enabled       = coalesce(try(var.landing_bucket.versioning_enabled, null), true)
  landing_bucket_public_access_prevention = coalesce(try(var.landing_bucket.public_access_prevention, null), "enforced")

  bronze_parquet_bucket_name = coalesce(
    try(var.bronze_parquet_bucket.name, null),
    "${var.project_id}${local.naming_environment_token}-bronze-parquet-${var.region}"
  )
  bronze_parquet_bucket_location                              = coalesce(try(var.bronze_parquet_bucket.location, null), var.region)
  bronze_parquet_bucket_storage_class                         = coalesce(try(var.bronze_parquet_bucket.storage_class, null), "STANDARD")
  bronze_parquet_bucket_force_destroy                         = coalesce(try(var.bronze_parquet_bucket.force_destroy, null), false)
  bronze_parquet_bucket_versioning_enabled                    = coalesce(try(var.bronze_parquet_bucket.versioning_enabled, null), true)
  bronze_parquet_bucket_public_access_prevention              = coalesce(try(var.bronze_parquet_bucket.public_access_prevention, null), "enforced")
  bronze_parquet_bucket_delete_noncurrent_versions_after_days = try(var.bronze_parquet_bucket.delete_noncurrent_versions_after_days, null)

  datasphere_ingest_sa_id = coalesce(
    var.datasphere_ingest_sa_id_override,
    "dsp-${var.service_name}-${var.environment}"
  )
  datasphere_sa_key_secret_id = coalesce(
    var.datasphere_ingest_sa_key_secret_id_override,
    "dsp-${var.service_name}-${var.environment}-sa-key"
  )
  dataform_git_token_secret_id = coalesce(
    var.dataform_git_token_secret_id_override,
    "sec-${var.service_name}-${var.environment}-dataform-github-pat"
  )

  raw_table_ids    = toset(keys(var.raw_tables))
  bronze_table_ids = toset(keys(var.bronze_tables))
  silver_table_ids = toset(keys(var.silver_tables))
  gold_table_ids   = toset(keys(var.gold_tables))
  alerts_table_ids = toset(keys(var.alerts_tables))
  logs_table_ids   = toset(keys(var.logs_tables))

  raw_table_definitions = local.raw_dataset_id == null ? {} : {
    for table_id, table in var.raw_tables : "raw:${table_id}" => {
      dataset_id               = local.raw_dataset_id
      table_id                 = table_id
      description              = table.description
      time_partitioning        = table.time_partitioning
      clustering_fields        = table.clustering_fields
      require_partition_filter = table.require_partition_filter
      deletion_protection      = var.bq_table_deletion_protection
      labels                   = local.common_labels
      schema_json              = table.schema_json
    }
  }

  bronze_table_definitions = {
    for table_id, table in var.bronze_tables : "bronze:${table_id}" => {
      dataset_id               = local.bronze_dataset_id
      table_id                 = table_id
      description              = table.description
      time_partitioning        = table.time_partitioning
      clustering_fields        = table.clustering_fields
      require_partition_filter = table.require_partition_filter
      deletion_protection      = var.bq_table_deletion_protection
      labels                   = local.common_labels
      schema_json              = table.schema_json
    }
  }

  silver_table_definitions = {
    for table_id, table in var.silver_tables : "silver:${table_id}" => {
      dataset_id               = local.silver_dataset_id
      table_id                 = table_id
      description              = table.description
      time_partitioning        = table.time_partitioning
      clustering_fields        = table.clustering_fields
      require_partition_filter = table.require_partition_filter
      deletion_protection      = var.bq_table_deletion_protection
      labels                   = local.common_labels
      schema_json              = table.schema_json
    }
  }

  gold_table_definitions = {
    for table_id, table in var.gold_tables : "gold:${table_id}" => {
      dataset_id               = local.gold_dataset_id
      table_id                 = table_id
      description              = table.description
      time_partitioning        = table.time_partitioning
      clustering_fields        = table.clustering_fields
      require_partition_filter = table.require_partition_filter
      deletion_protection      = var.bq_table_deletion_protection
      labels                   = local.common_labels
      schema_json              = table.schema_json
    }
  }

  alerts_table_definitions = local.alerts_dataset_id == null ? {} : {
    for table_id, table in var.alerts_tables : "alerts:${table_id}" => {
      dataset_id               = local.alerts_dataset_id
      table_id                 = table_id
      description              = table.description
      time_partitioning        = table.time_partitioning
      clustering_fields        = table.clustering_fields
      require_partition_filter = table.require_partition_filter
      deletion_protection      = var.bq_table_deletion_protection
      labels                   = local.common_labels
      schema_json              = table.schema_json
    }
  }

  logs_table_definitions = local.logs_dataset_id == null ? {} : {
    for table_id, table in var.logs_tables : "logs:${table_id}" => {
      dataset_id               = local.logs_dataset_id
      table_id                 = table_id
      description              = table.description
      time_partitioning        = table.time_partitioning
      clustering_fields        = table.clustering_fields
      require_partition_filter = table.require_partition_filter
      deletion_protection      = var.bq_table_deletion_protection
      labels                   = local.common_labels
      schema_json              = table.schema_json
    }
  }

  raw_view_definitions = local.raw_dataset_id == null ? {} : {
    for table_id, table in var.raw_tables : "raw:v_${table_id}" => {
      dataset_id        = local.raw_dataset_id
      table_id          = "v_${table_id}"
      source_table_id   = table_id
      source_dataset_id = local.raw_dataset_id
    } if table.create_view
  }

  bronze_view_definitions = {
    for table_id, table in var.bronze_tables : "bronze:v_${table_id}" => {
      dataset_id        = local.bronze_dataset_id
      table_id          = "v_${table_id}"
      source_table_id   = table_id
      source_dataset_id = local.bronze_dataset_id
    } if table.create_view
  }

  silver_view_definitions = {
    for table_id, table in var.silver_tables : "silver:v_${table_id}" => {
      dataset_id        = local.silver_dataset_id
      table_id          = "v_${table_id}"
      source_table_id   = table_id
      source_dataset_id = local.silver_dataset_id
    } if table.create_view
  }

  gold_view_definitions = {
    for table_id, table in var.gold_tables : "gold:v_${table_id}" => {
      dataset_id        = local.gold_dataset_id
      table_id          = "v_${table_id}"
      source_table_id   = table_id
      source_dataset_id = local.gold_dataset_id
    } if table.create_view
  }

  alerts_view_definitions = local.alerts_dataset_id == null ? {} : {
    for table_id, table in var.alerts_tables : "alerts:v_${table_id}" => {
      dataset_id        = local.alerts_dataset_id
      table_id          = "v_${table_id}"
      source_table_id   = table_id
      source_dataset_id = local.alerts_dataset_id
    } if table.create_view
  }

  logs_view_definitions = local.logs_dataset_id == null ? {} : {
    for table_id, table in var.logs_tables : "logs:v_${table_id}" => {
      dataset_id        = local.logs_dataset_id
      table_id          = "v_${table_id}"
      source_table_id   = table_id
      source_dataset_id = local.logs_dataset_id
    } if table.create_view
  }

  layered_table_definitions = merge(
    local.alerts_table_definitions,
    local.logs_table_definitions,
    local.raw_table_definitions,
    local.bronze_table_definitions,
    local.silver_table_definitions,
    local.gold_table_definitions,
  )

  medallion_view_definitions = merge(
    local.raw_view_definitions,
    local.bronze_view_definitions,
    local.silver_view_definitions,
    local.gold_view_definitions,
    local.alerts_view_definitions,
    local.logs_view_definitions,
  )

}

# Validate generated bucket, dataset and service account names.
check "generated_names_are_valid" {
  assert {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", local.landing_bucket_name))
    error_message = "Landing bucket name is invalid. Set landing_bucket.name with a valid bucket name."
  }

  assert {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", local.bronze_parquet_bucket_name))
    error_message = "Bronze parquet bucket name is invalid. Set bronze_parquet_bucket.name with a valid bucket name."
  }

  assert {
    condition     = lower(local.bronze_parquet_bucket_location) == lower(local.bigquery_location)
    error_message = "bronze_parquet_bucket.location must match the BigQuery location used by the medallion datasets."
  }

  assert {
    condition     = local.raw_dataset_id == null || (can(regex("^[A-Za-z_][A-Za-z0-9_]*$", local.raw_dataset_id)) && length(local.raw_dataset_id) <= 1024)
    error_message = "Raw dataset id is invalid. Set dataset_ids.raw with a valid dataset id."
  }

  assert {
    condition     = local.alerts_dataset_id == null || (can(regex("^[A-Za-z_][A-Za-z0-9_]*$", local.alerts_dataset_id)) && length(local.alerts_dataset_id) <= 1024)
    error_message = "Alerts dataset id is invalid. Set dataset_ids.alerts with a valid dataset id."
  }

  assert {
    condition     = local.assertions_dataset_id == null || (can(regex("^[A-Za-z_][A-Za-z0-9_]*$", local.assertions_dataset_id)) && length(local.assertions_dataset_id) <= 1024)
    error_message = "Assertions dataset id is invalid. Set dataset_ids.assertions with a valid dataset id."
  }

  assert {
    condition     = local.logs_dataset_id == null || (can(regex("^[A-Za-z_][A-Za-z0-9_]*$", local.logs_dataset_id)) && length(local.logs_dataset_id) <= 1024)
    error_message = "Logs dataset id is invalid. Set dataset_ids.logs with a valid dataset id."
  }

  assert {
    condition     = can(regex("^[A-Za-z_][A-Za-z0-9_]*$", local.bronze_dataset_id)) && length(local.bronze_dataset_id) <= 1024
    error_message = "Bronze dataset id is invalid. Set dataset_ids.bronze with a valid dataset id."
  }

  assert {
    condition     = can(regex("^[A-Za-z_][A-Za-z0-9_]*$", local.silver_dataset_id)) && length(local.silver_dataset_id) <= 1024
    error_message = "Silver dataset id is invalid. Set dataset_ids.silver with a valid dataset id."
  }

  assert {
    condition     = can(regex("^[A-Za-z_][A-Za-z0-9_]*$", local.gold_dataset_id)) && length(local.gold_dataset_id) <= 1024
    error_message = "Gold dataset id is invalid. Set dataset_ids.gold with a valid dataset id."
  }

  assert {
    condition     = !var.enable_datasphere_ingest_service_account || can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", local.datasphere_ingest_sa_id))
    error_message = "Generated Datasphere ingestion service account id is invalid. Set datasphere_ingest_sa_id_override with a valid id."
  }
}

# Create landing GCS bucket for raw parquet ingestion.
module "landing_bucket" {
  source = "../../modules/gcs_bucket"

  project_id               = var.project_id
  name                     = local.landing_bucket_name
  location                 = local.landing_bucket_location
  storage_class            = local.landing_bucket_storage_class
  force_destroy            = local.landing_bucket_force_destroy
  versioning_enabled       = local.landing_bucket_versioning_enabled
  public_access_prevention = lower(local.landing_bucket_public_access_prevention)
  labels                   = local.common_labels
}

module "bronze_parquet_bucket" {
  source = "../../modules/gcs_bucket"

  project_id                            = var.project_id
  name                                  = local.bronze_parquet_bucket_name
  location                              = local.bronze_parquet_bucket_location
  storage_class                         = local.bronze_parquet_bucket_storage_class
  force_destroy                         = local.bronze_parquet_bucket_force_destroy
  versioning_enabled                    = local.bronze_parquet_bucket_versioning_enabled
  delete_noncurrent_versions_after_days = local.bronze_parquet_bucket_delete_noncurrent_versions_after_days
  public_access_prevention              = lower(local.bronze_parquet_bucket_public_access_prevention)
  labels                                = local.common_labels
}

# Create dedicated service account for SAP Datasphere ingestion.
resource "google_service_account" "datasphere_ingest" {
  count = var.enable_datasphere_ingest_service_account ? 1 : 0

  project      = var.project_id
  account_id   = local.datasphere_ingest_sa_id
  display_name = "SAP Datasphere Ingestion SA (${var.environment})"
  description  = "Service account used by SAP Datasphere to upload parquet files into ${module.landing_bucket.name}."
}

# Grant SAP Datasphere ingestion service account access on landing bucket.
resource "google_storage_bucket_iam_member" "datasphere_ingest_bucket_access" {
  for_each = var.enable_datasphere_ingest_service_account ? toset(concat(["roles/storage.objectUser"], var.datasphere_landing_bucket_roles)) : []

  bucket = module.landing_bucket.name
  role   = each.value
  member = "serviceAccount:${google_service_account.datasphere_ingest[0].email}"
}

# Secret container for SAP Datasphere service account key JSON.
resource "google_secret_manager_secret" "datasphere_ingest_sa_key" {
  count = var.enable_datasphere_ingest_service_account ? 1 : 0

  project   = var.project_id
  secret_id = local.datasphere_sa_key_secret_id
  labels    = local.common_labels

  replication {
    auto {}
  }
}

# Secret container for Dataform Git token (PAT). Value is uploaded outside Terraform.
resource "google_secret_manager_secret" "dataform_git_token" {
  count = var.enable_dataform_git_token_secret ? 1 : 0

  project   = var.project_id
  secret_id = local.dataform_git_token_secret_id
  labels    = local.common_labels

  replication {
    auto {}
  }
}

# Create layered datasets in BigQuery.
module "medallion_datasets" {
  source = "../../modules/bigquery_datasets"

  project_id                  = var.project_id
  location                    = local.bigquery_location
  dataset_ids                 = compact([local.alerts_dataset_id, local.assertions_dataset_id, local.logs_dataset_id, local.raw_dataset_id, local.bronze_dataset_id, local.silver_dataset_id, local.gold_dataset_id])
  delete_contents_on_destroy  = var.bq_dataset_delete_contents_on_destroy
  default_table_expiration_ms = var.bq_default_table_expiration_ms
  labels                      = local.common_labels
}

# Create managed tables in BigQuery for all data layers.
module "medallion_tables" {
  source = "../../modules/bigquery_tables"

  project_id = var.project_id
  tables     = local.layered_table_definitions

  depends_on = [module.medallion_datasets]
}

# Create managed views in medallion datasets (raw, bronze, silver, gold).
resource "google_bigquery_table" "medallion_views" {
  for_each = local.medallion_view_definitions

  project             = var.project_id
  dataset_id          = each.value.dataset_id
  table_id            = each.value.table_id
  deletion_protection = var.bq_table_deletion_protection
  labels              = local.common_labels

  view {
    query          = format("SELECT * FROM `%s.%s.%s`", var.project_id, each.value.source_dataset_id, each.value.source_table_id)
    use_legacy_sql = false
  }

  depends_on = [module.medallion_tables]
}
