output "service_name" {
  description = "Name of the Cloud Run service"
  value       = google_cloud_run_service.openwebui.name
}

output "service_url" {
  description = "URL of the Cloud Run service"
  value       = google_cloud_run_service.openwebui.status[0].url
}

output "service_id" {
  description = "ID of the Cloud Run service"
  value       = google_cloud_run_service.openwebui.id
}

output "latest_revision_name" {
  description = "Name of the latest revision"
  value       = google_cloud_run_service.openwebui.status[0].latest_ready_revision_name
} 