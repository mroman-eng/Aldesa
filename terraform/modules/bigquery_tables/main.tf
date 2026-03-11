resource "google_bigquery_table" "this" {
  for_each = var.tables

  project                  = var.project_id
  dataset_id               = each.value.dataset_id
  table_id                 = each.value.table_id
  schema                   = each.value.schema_json
  description              = each.value.description
  clustering               = length(each.value.clustering_fields) > 0 ? each.value.clustering_fields : null
  require_partition_filter = each.value.time_partitioning == null ? null : each.value.require_partition_filter
  deletion_protection      = each.value.deletion_protection
  labels                   = each.value.labels

  dynamic "time_partitioning" {
    for_each = each.value.time_partitioning == null ? [] : [each.value.time_partitioning]
    content {
      type          = upper(time_partitioning.value.type)
      field         = time_partitioning.value.field
      expiration_ms = time_partitioning.value.expiration_ms
    }
  }
}
