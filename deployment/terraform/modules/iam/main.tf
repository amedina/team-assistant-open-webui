terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Cloud Run Service Account
resource "google_service_account" "cloud_run" {
  account_id   = "${var.environment}-openwebui-cloudrun"
  display_name = "Open WebUI Cloud Run Service Account (${var.environment})"
  description  = "Service account for Open WebUI Cloud Run service in ${var.environment}"
  project      = var.project_id
}

# Cloud Build Service Account
resource "google_service_account" "cloud_build" {
  account_id   = "${var.environment}-openwebui-cloudbuild"
  display_name = "Open WebUI Cloud Build Service Account (${var.environment})"
  description  = "Service account for Open WebUI Cloud Build in ${var.environment}"
  project      = var.project_id
}

# Cloud Run Service Account IAM Roles
resource "google_project_iam_member" "cloud_run_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

resource "google_project_iam_member" "cloud_run_storage_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

resource "google_project_iam_member" "cloud_run_vertex_ai_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

resource "google_project_iam_member" "cloud_run_monitoring_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

resource "google_project_iam_member" "cloud_run_logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

resource "google_project_iam_member" "cloud_run_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

# Cloud Build Service Account IAM Roles
resource "google_project_iam_member" "cloud_build_editor" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.editor"
  member  = "serviceAccount:${google_service_account.cloud_build.email}"
}

resource "google_project_iam_member" "cloud_build_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cloud_build.email}"
}

resource "google_project_iam_member" "cloud_build_run_developer" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.cloud_build.email}"
}

resource "google_project_iam_member" "cloud_build_iam_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cloud_build.email}"
}

# Service Account Keys (for applications that need JSON key files)
resource "google_service_account_key" "cloud_run_key" {
  service_account_id = google_service_account.cloud_run.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

# Storage bucket IAM for Cloud Run service account
resource "google_storage_bucket_iam_member" "cloud_run_bucket_admin" {
  count  = var.storage_bucket_name != "" ? 1 : 0
  bucket = var.storage_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cloud_run.email}"
} 