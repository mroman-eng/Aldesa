resource "google_bigquery_dataset" "this" {
  for_each = toset(var.dataset_ids)

  project                     = var.project_id
  dataset_id                  = each.value
  location                    = var.location
  delete_contents_on_destroy  = var.delete_contents_on_destroy
  default_table_expiration_ms = var.default_table_expiration_ms
  labels                      = var.labels
}
