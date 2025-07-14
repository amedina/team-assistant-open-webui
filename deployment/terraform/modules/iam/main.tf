terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
  }
}

locals {
  common_labels = {
    application = "open-webui"
    environment = var.environment
    managed-by  = "terraform"
  }
}

# Cloud Run Service Account
resource "google_service_account" "cloud_run" {
  account_id   = "${var.environment}-webui-run-sa"
  display_name = "Open WebUI Cloud Run Service Account (${var.environment})"
  description  = "Service account for Open WebUI Cloud Run service in ${var.environment} environment"
  project      = var.project_id
}

# Cloud Build Service Account
resource "google_service_account" "cloud_build" {
  account_id   = "${var.environment}-webui-build-sa"
  display_name = "Open WebUI Cloud Build Service Account (${var.environment})"
  description  = "Service account for Open WebUI Cloud Build operations in ${var.environment} environment"
  project      = var.project_id
}

# Cloud Run Service Account IAM Roles
resource "google_project_iam_member" "cloud_run_roles" {
  for_each = toset([
    "roles/cloudsql.client",
    "roles/redis.editor",
    "roles/storage.objectAdmin",
    "roles/secretmanager.secretAccessor",
    "roles/aiplatform.user",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter",
    "roles/cloudtrace.agent"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

# Cloud Build Service Account IAM Roles
resource "google_project_iam_member" "cloud_build_roles" {
  for_each = toset([
    "roles/cloudbuild.builds.builder",
    "roles/run.admin",
    "roles/storage.admin",
    "roles/artifactregistry.writer",
    "roles/secretmanager.secretAccessor",
    "roles/iam.serviceAccountUser"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_build.email}"
}

# Allow Cloud Build to act as Cloud Run service account
resource "google_service_account_iam_member" "cloud_build_impersonate_cloud_run" {
  service_account_id = google_service_account.cloud_run.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cloud_build.email}"
}

# Custom role for Cloud Storage bucket access (more restrictive)
resource "google_project_iam_custom_role" "storage_bucket_admin" {
  role_id     = "${var.environment}_open_webui_storage_admin"
  title       = "Open WebUI Storage Admin (${var.environment})"
  description = "Custom role for Open WebUI storage bucket access"

  permissions = [
    "storage.buckets.get",
    "storage.buckets.list",
    "storage.objects.create",
    "storage.objects.delete",
    "storage.objects.get",
    "storage.objects.list",
    "storage.objects.update"
  ]
}

# Assign custom storage role to Cloud Run service account
resource "google_project_iam_member" "cloud_run_storage_custom" {
  project = var.project_id
  role    = google_project_iam_custom_role.storage_bucket_admin.id
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

# Specific bucket IAM binding for Cloud Run service account
resource "google_storage_bucket_iam_member" "cloud_run_bucket_access" {
  count = var.storage_bucket_name != null ? 1 : 0

  bucket = var.storage_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cloud_run.email}"
}
