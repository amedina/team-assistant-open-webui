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

# Artifact Registry repository for container images
resource "google_artifact_registry_repository" "container_images" {
  repository_id = "${var.environment}-open-webui-images"
  location      = var.region
  project       = var.project_id
  format        = "DOCKER"
  description   = "Container images for Open WebUI ${var.environment} environment"

  labels = local.common_labels

  # Docker configuration
  docker_config {
    immutable_tags = var.environment == "prod" ? true : false
  }

  # Cleanup policies for cost optimization
  cleanup_policies {
    id     = "keep-minimum-versions"
    action = "DELETE"

    condition {
      tag_state    = "ANY"
      tag_prefixes = ["latest", "v", "staging", "prod"]
      older_than   = "${var.image_retention_days}d"
    }

    most_recent_versions {
      keep_count = var.keep_recent_versions
    }
  }

  cleanup_policies {
    id     = "cleanup-untagged"
    action = "DELETE"

    condition {
      tag_state  = "UNTAGGED"
      older_than = "${var.untagged_retention_days}d"
    }
  }

  depends_on = [var.services_ready]
}

# IAM policy for Cloud Build to push images
resource "google_artifact_registry_repository_iam_member" "cloud_build_writer" {
  project    = var.project_id
  location   = google_artifact_registry_repository.container_images.location
  repository = google_artifact_registry_repository.container_images.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.cloud_build_service_account_email}"
}

# IAM policy for Cloud Build to read images
resource "google_artifact_registry_repository_iam_member" "cloud_build_reader" {
  project    = var.project_id
  location   = google_artifact_registry_repository.container_images.location
  repository = google_artifact_registry_repository.container_images.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.cloud_build_service_account_email}"
}

# IAM policy for Cloud Run to pull images
resource "google_artifact_registry_repository_iam_member" "cloud_run_reader" {
  project    = var.project_id
  location   = google_artifact_registry_repository.container_images.location
  repository = google_artifact_registry_repository.container_images.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.cloud_run_service_account_email}"
}

# IAM policy for developers to pull images (staging only)
resource "google_artifact_registry_repository_iam_member" "developer_reader" {
  for_each = var.environment == "staging" ? toset(var.developer_emails) : toset([])

  project    = var.project_id
  location   = google_artifact_registry_repository.container_images.location
  repository = google_artifact_registry_repository.container_images.name
  role       = "roles/artifactregistry.reader"
  member     = "user:${each.value}"
}

# Optional: Create a separate repository for base images
resource "google_artifact_registry_repository" "base_images" {
  count = var.create_base_images_repo ? 1 : 0

  repository_id = "${var.environment}-open-webui-base-images"
  location      = var.region
  project       = var.project_id
  format        = "DOCKER"
  description   = "Base container images for Open WebUI ${var.environment} environment"

  labels = merge(local.common_labels, {
    purpose = "base-images"
  })

  # Docker configuration
  docker_config {
    immutable_tags = true
  }

  # Cleanup policies for base images (longer retention)
  cleanup_policies {
    id     = "keep-base-images"
    action = "DELETE"

    condition {
      tag_state    = "ANY"
      tag_prefixes = ["base", "foundation"]
      older_than   = "${var.base_image_retention_days}d"
    }

    most_recent_versions {
      keep_count = var.keep_base_image_versions
    }
  }

  depends_on = [var.services_ready]
}

# IAM for base images repository
resource "google_artifact_registry_repository_iam_member" "base_images_cloud_build_writer" {
  count = var.create_base_images_repo ? 1 : 0

  project    = var.project_id
  location   = google_artifact_registry_repository.base_images[0].location
  repository = google_artifact_registry_repository.base_images[0].name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.cloud_build_service_account_email}"
}

resource "google_artifact_registry_repository_iam_member" "base_images_cloud_build_reader" {
  count = var.create_base_images_repo ? 1 : 0

  project    = var.project_id
  location   = google_artifact_registry_repository.base_images[0].location
  repository = google_artifact_registry_repository.base_images[0].name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.cloud_build_service_account_email}"
}

# Optional: Create notification for new images
resource "google_pubsub_topic" "image_notifications" {
  count = var.enable_image_notifications ? 1 : 0

  name    = "${var.environment}-open-webui-image-notifications"
  project = var.project_id

  labels = local.common_labels

  depends_on = [var.services_ready]
}

# Pub/Sub subscription for image notifications
resource "google_pubsub_subscription" "image_notifications" {
  count = var.enable_image_notifications ? 1 : 0

  name    = "${var.environment}-open-webui-image-notifications-sub"
  project = var.project_id
  topic   = google_pubsub_topic.image_notifications[0].name

  ack_deadline_seconds = 20

  expiration_policy {
    ttl = "86400s" # 24 hours
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  depends_on = [var.services_ready]
}

# Optional: Create a webhook for image scanning results
resource "google_cloud_run_service" "image_scanner_webhook" {
  count = var.enable_image_scanning_webhook ? 1 : 0

  name     = "${var.environment}-open-webui-image-scanner"
  location = var.region
  project  = var.project_id

  template {
    spec {
      containers {
        image = "gcr.io/cloudrun/hello" # Placeholder - replace with actual webhook image

        ports {
          container_port = 8080
        }

        env {
          name  = "ENVIRONMENT"
          value = var.environment
        }

        resources {
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
          }
        }
      }

      service_account_name = var.cloud_run_service_account_email
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale" = "0"
        "autoscaling.knative.dev/maxScale" = "10"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [var.services_ready]
}

# IAM policy for webhook service
resource "google_cloud_run_service_iam_member" "webhook_invoker" {
  count = var.enable_image_scanning_webhook ? 1 : 0

  location = google_cloud_run_service.image_scanner_webhook[0].location
  project  = google_cloud_run_service.image_scanner_webhook[0].project
  service  = google_cloud_run_service.image_scanner_webhook[0].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.cloud_build_service_account_email}"
} 
