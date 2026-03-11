output "table_ids" {
  description = "Created BigQuery table resource ids."
  value       = { for table_id, table in google_bigquery_table.this : table_id => table.id }
}
