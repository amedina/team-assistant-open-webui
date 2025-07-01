output "cloud_run_service_account_email" {
  description = "Email address of the Cloud Run service account"
  value       = google_service_account.cloud_run.email
}

output "cloud_run_service_account_id" {
  description = "ID of the Cloud Run service account"
  value       = google_service_account.cloud_run.id
}

output "cloud_build_service_account_email" {
  description = "Email address of the Cloud Build service account"
  value       = google_service_account.cloud_build.email
}

output "cloud_build_service_account_id" {
  description = "ID of the Cloud Build service account"
  value       = google_service_account.cloud_build.id
}

output "cloud_run_service_account_key" {
  description = "Private key for the Cloud Run service account"
  value       = google_service_account_key.cloud_run_key.private_key
  sensitive   = true
} 