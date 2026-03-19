output "project_id" {
  description = "Governance target project."
  value       = module.governance.project_id
}

output "dataplex_profile_scan_ids" {
  description = "Dataplex data profile scan ids keyed by scan id."
  value       = module.governance.dataplex_profile_scan_ids
}

output "dataplex_profile_scan_names" {
  description = "Dataplex data profile scan names keyed by scan id."
  value       = module.governance.dataplex_profile_scan_names
}

output "dataplex_quality_scan_ids" {
  description = "Dataplex data quality scan ids keyed by scan id."
  value       = module.governance.dataplex_quality_scan_ids
}

output "dataplex_quality_scan_names" {
  description = "Dataplex data quality scan names keyed by scan id."
  value       = module.governance.dataplex_quality_scan_names
}
