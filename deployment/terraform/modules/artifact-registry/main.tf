terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Artifact Registry Repository for Docker images
resource "google_artifact_registry_repository" "main" {
  location      = var.region
  project       = var.project_id
  repository_id = "${var.environment}-${var.repository_id}"
  description   = "Docker repository for Open WebUI (${var.environment})"
  format        = "DOCKER"
  
  labels = var.labels

  cleanup_policies {
    id     = "keep-minimum-versions"
    action = "KEEP"
    
    condition {
      tag_state             = "TAGGED"
      tag_prefixes          = ["v", "release"]
      older_than            = "2592000s"  # 30 days
    }
    
    most_recent_versions {
      keep_count = var.keep_image_versions
    }
  }

  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"
    
    condition {
      tag_state  = "UNTAGGED"
      older_than = "604800s"  # 7 days
    }
  }
}

# IAM binding for Cloud Build to push images
resource "google_artifact_registry_repository_iam_member" "cloud_build_writer" {
  count      = var.cloud_build_service_account != "" ? 1 : 0
  project    = var.project_id
  location   = google_artifact_registry_repository.main.location
  repository = google_artifact_registry_repository.main.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.cloud_build_service_account}"
}

# IAM binding for Cloud Run to pull images
resource "google_artifact_registry_repository_iam_member" "cloud_run_reader" {
  count      = var.cloud_run_service_account != "" ? 1 : 0
  project    = var.project_id
  location   = google_artifact_registry_repository.main.location
  repository = google_artifact_registry_repository.main.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.cloud_run_service_account}"
} 