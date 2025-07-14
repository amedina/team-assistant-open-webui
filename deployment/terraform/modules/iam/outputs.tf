output "cloud_run_service_account_email" {
  description = "Email address of the Cloud Run service account"
  value       = google_service_account.cloud_run.email
}

output "cloud_run_service_account_name" {
  description = "Name of the Cloud Run service account"
  value       = google_service_account.cloud_run.name
}

output "cloud_build_service_account_email" {
  description = "Email address of the Cloud Build service account"
  value       = google_service_account.cloud_build.email
}

output "cloud_build_service_account_name" {
  description = "Name of the Cloud Build service account"
  value       = google_service_account.cloud_build.name
}

output "service_accounts" {
  description = "Map of service account names to email addresses"
  value = {
    cloud_run   = google_service_account.cloud_run.email
    cloud_build = google_service_account.cloud_build.email
  }
}

output "custom_roles" {
  description = "Map of custom roles created"
  value = {
    storage_bucket_admin = google_project_iam_custom_role.storage_bucket_admin.id
  }
}

output "iam_ready" {
  description = "Indicates that IAM resources are ready"
  value       = true
  depends_on = [
    google_service_account.cloud_run,
    google_service_account.cloud_build,
    google_project_iam_member.cloud_run_roles,
    google_project_iam_member.cloud_build_roles,
    google_service_account_iam_member.cloud_build_impersonate_cloud_run
  ]
} 
