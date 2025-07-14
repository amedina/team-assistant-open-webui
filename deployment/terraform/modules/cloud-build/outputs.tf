output "staging_trigger_id" {
  description = "ID of the staging Cloud Build trigger"
  value       = var.environment == "staging" ? google_cloudbuild_trigger.staging_trigger[0].id : null
}

output "production_trigger_id" {
  description = "ID of the production Cloud Build trigger"
  value       = var.environment == "prod" ? google_cloudbuild_trigger.production_trigger[0].id : null
}

output "build_notifications_topic" {
  description = "Pub/Sub topic for build notifications"
  value       = var.enable_build_notifications ? google_pubsub_topic.build_notifications[0].id : null
}

output "build_notifications_subscription" {
  description = "Pub/Sub subscription for build notifications"
  value       = var.enable_build_notifications ? google_pubsub_subscription.build_notifications[0].id : null
}

output "cleanup_trigger_id" {
  description = "ID of the cleanup Cloud Build trigger"
  value       = var.enable_build_cleanup ? google_cloudbuild_trigger.cleanup_trigger[0].id : null
} 
