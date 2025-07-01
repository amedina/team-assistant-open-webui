output "trigger_id" {
  description = "ID of the Cloud Build trigger"
  value       = google_cloudbuild_trigger.main.trigger_id
}

output "trigger_name" {
  description = "Name of the Cloud Build trigger"
  value       = google_cloudbuild_trigger.main.name
}

output "release_trigger_id" {
  description = "ID of the release Cloud Build trigger"
  value       = var.enable_release_trigger ? google_cloudbuild_trigger.release[0].trigger_id : null
}

output "release_trigger_name" {
  description = "Name of the release Cloud Build trigger"
  value       = var.enable_release_trigger ? google_cloudbuild_trigger.release[0].name : null
} 