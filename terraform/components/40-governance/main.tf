# Resolve labels and dataset ids used by Dataplex DataScans.
locals {
  common_labels = merge(
    {
      component    = "40-governance"
      environment  = var.environment
      managed_by   = "terraform"
      project_name = var.service_name
    },
    var.additional_labels
  )

  dataset_ids_by_layer = {
    raw    = var.source_resources.raw_dataset_id
    bronze = var.source_resources.bronze_dataset_id
    silver = var.source_resources.silver_dataset_id
    gold   = var.source_resources.gold_dataset_id
  }

  auto_profile_scans_enabled = coalesce(try(var.auto_profile_scans.enabled, null), true)
  auto_profile_scan_layers = toset(
    coalesce(try(var.auto_profile_scans.include_layers, null), ["raw", "bronze", "silver"])
  )

  auto_profile_scan_table_ids_by_layer = {
    raw    = coalesce(try(var.auto_profile_scan_table_ids_by_layer.raw, null), [])
    bronze = coalesce(try(var.auto_profile_scan_table_ids_by_layer.bronze, null), [])
    silver = coalesce(try(var.auto_profile_scan_table_ids_by_layer.silver, null), [])
    gold   = coalesce(try(var.auto_profile_scan_table_ids_by_layer.gold, null), [])
  }

  # Build one profile scan per discovered table in selected layers.
  auto_profile_scan_entries = flatten([
    for layer in local.auto_profile_scan_layers : [
      for table_id in local.auto_profile_scan_table_ids_by_layer[layer] : {
        layer    = layer
        table_id = table_id
        table_slug = (
          trim(replace(lower(replace(table_id, "_", "-")), "/[^a-z0-9-]/", "-"), "-") == "" ?
          "table" :
          trim(replace(lower(replace(table_id, "_", "-")), "/[^a-z0-9-]/", "-"), "-")
        )
      }
    ]
  ])

  auto_profile_scans = local.auto_profile_scans_enabled ? {
    for entry in local.auto_profile_scan_entries :
    (
      length("dps-${entry.table_slug}-${entry.layer}") <= 63 ?
      "dps-${entry.table_slug}-${entry.layer}" :
      "dps-${substr(entry.table_slug, 0, 48)}-${substr(md5("${entry.layer}:${entry.table_id}"), 0, 8)}"
      ) => {
      display_name = "dps_${entry.table_id}_${entry.layer}"
      layer        = entry.layer
      table_id     = entry.table_id
      execution = {
        trigger_mode = "ON_DEMAND"
      }
    }
  } : {}

  effective_profile_scans = merge(
    local.auto_profile_scans,
    coalesce(try(var.dataplex_datascans.profile_scans, null), {})
  )
  effective_quality_scans = coalesce(try(var.dataplex_datascans.quality_scans, null), {})

  effective_dataplex_datascans = {
    profile_scans = local.effective_profile_scans
    quality_scans = local.effective_quality_scans
  }
}

# Provision Dataplex data profile and data quality scans for selected tables.
module "dataplex_datascans" {
  source = "../../modules/dataplex_datascans"

  project_id = var.project_id
  location   = var.region

  labels               = local.common_labels
  dataset_ids_by_layer = local.dataset_ids_by_layer
  datascans            = local.effective_dataplex_datascans
}
