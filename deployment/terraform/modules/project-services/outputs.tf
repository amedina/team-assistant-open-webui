output "enabled_services" {
  description = "List of enabled Google Cloud services"
  value       = [for service in google_project_service.required_apis : service.service]
}

output "api_propagation_complete" {
  description = "Indicates when API propagation is complete"
  value       = time_sleep.api_propagation.id
} 