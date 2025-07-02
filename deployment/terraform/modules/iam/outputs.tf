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

# Service account key output removed due to organization policy
# Cloud Run will use default service account authentication 