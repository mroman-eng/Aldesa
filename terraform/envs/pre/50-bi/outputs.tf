output "project_id" {
  description = "BI target project."
  value       = module.bi.project_id
}

output "looker_studio_access" {
  description = "Effective Looker Studio Pro IAM access applied on BigQuery."
  value       = module.bi.looker_studio_access
}

output "context_aware_access" {
  description = "Context-Aware Access level metadata for Looker Studio network restrictions."
  value       = module.bi.context_aware_access
}
