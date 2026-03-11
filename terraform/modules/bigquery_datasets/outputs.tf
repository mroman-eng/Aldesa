output "dataset_ids" {
  description = "Created BigQuery dataset ids."
  value       = sort(keys(google_bigquery_dataset.this))
}

output "dataset_self_links" {
  description = "Self links for created BigQuery datasets."
  value       = { for dataset_id, dataset in google_bigquery_dataset.this : dataset_id => dataset.self_link }
}
