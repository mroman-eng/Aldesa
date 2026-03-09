output "enabled_services" {
  description = "Services enabled by this module."
  value       = sort(keys(google_project_service.this))
}
