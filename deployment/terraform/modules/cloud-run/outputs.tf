output "service_name" {
  description = "Name of the Cloud Run service"
  value       = google_cloud_run_v2_service.openwebui.name
}

output "service_url" {
  description = "URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.openwebui.uri
}

output "service_id" {
  description = "ID of the Cloud Run service"
  value       = google_cloud_run_v2_service.openwebui.id
}

output "latest_revision_name" {
  description = "Name of the latest revision"
  value       = google_cloud_run_v2_service.openwebui.latest_ready_revision
}
