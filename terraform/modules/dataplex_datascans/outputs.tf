output "profile_scan_ids" {
  description = "Dataplex data profile scan ids keyed by configured scan id."
  value       = { for scan_id, scan in google_dataplex_datascan.profile : scan_id => scan.id }
}

output "profile_scan_names" {
  description = "Dataplex data profile scan names keyed by configured scan id."
  value       = { for scan_id, scan in google_dataplex_datascan.profile : scan_id => scan.name }
}

output "quality_scan_ids" {
  description = "Dataplex data quality scan ids keyed by configured scan id."
  value       = { for scan_id, scan in google_dataplex_datascan.quality : scan_id => scan.id }
}

output "quality_scan_names" {
  description = "Dataplex data quality scan names keyed by configured scan id."
  value       = { for scan_id, scan in google_dataplex_datascan.quality : scan_id => scan.name }
}
