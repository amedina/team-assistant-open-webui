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

# Cloud Run V2 Service
resource "google_cloud_run_v2_service" "open_webui" {
  name     = "${var.environment}-open-webui"
  location = var.region
  project  = var.project_id
  deletion_protection = false

  labels = local.common_labels

  template {
    labels = local.common_labels

    # Scaling configuration
    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    # VPC Connector (mandatory)
    vpc_access {
      connector = "projects/${var.project_id}/locations/${var.region}/connectors/${var.vpc_connector_name}"
      egress    = "ALL_TRAFFIC"
    }

    # Service account
    service_account = var.cloud_run_service_account_email

    # Cloud Storage FUSE volumes for persistent storage
    volumes {
      name = "app-data-storage"
      gcs {
        bucket = var.storage_bucket_name
      }
    }

    volumes {
      name = "uploads-storage"
      gcs {
        bucket = var.storage_bucket_name
      }
    }

    volumes {
      name = "cache-storage"
      gcs {
        bucket = var.storage_bucket_name
      }
    }

    containers {
      image = var.container_image_url
      name  = "open-webui"

      # Resource allocation (2 CPU, 4GB RAM)
      resources {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
        cpu_idle          = true
        startup_cpu_boost = true
      }

      # Port configuration
      ports {
        name           = "http1"
        container_port = 8080
      }

      # Volume mounts for persistent storage
      volume_mounts {
        name       = "app-data-storage"
        mount_path = "/app/backend/data"
      }

      volume_mounts {
        name       = "uploads-storage"
        mount_path = "/app/backend/uploads"
      }

      volume_mounts {
        name       = "cache-storage"
        mount_path = "/app/backend/cache"
      }

      # Environment variables with secret injection
      env {
        name = "WEBUI_SECRET_KEY"
        value_source {
          secret_key_ref {
            secret  = var.webui_secret_key_secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = var.database_url_secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "REDIS_URL"
        value_source {
          secret_key_ref {
            secret  = var.redis_url_secret_id
            version = "latest"
          }
        }
      }

      env {
        name  = "GOOGLE_CLIENT_ID"
        value = var.oauth_client_id
      }

      env {
        name = "GOOGLE_CLIENT_SECRET"
        value_source {
          secret_key_ref {
            secret  = var.oauth_client_secret_secret_id
            version = "latest"
          }
        }
      }

      /*env {
        name = "AGENT_ENGINE_RESOURCE_ID"
        value_source {
          secret_key_ref {
            secret  = var.agent_engine_secret_id
            version = "latest"
          }
        }
      }*/

      # Storage configuration (API-based)
      env {
        name  = "STORAGE_PROVIDER"
        value = "s3"
      }

      env {
        name  = "S3_BUCKET_NAME"
        value = var.storage_bucket_name
      }

      env {
        name  = "S3_ENDPOINT_URL"
        value = "https://storage.googleapis.com"
      }

      # OAuth configuration
      env {
        name  = "ENABLE_OAUTH_SIGNUP"
        value = "true"
      }

      env {
        name  = "OAUTH_PROVIDER"
        value = "google"
      }

      # Application settings
      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }

      # Health check endpoints
      startup_probe {
        initial_delay_seconds = 240
        timeout_seconds       = 240
        period_seconds        = 240
        failure_threshold     = 5

        http_get {
          path = "/health"
          port = 8080
        }
      }

      liveness_probe {
        initial_delay_seconds = 1440
        timeout_seconds       = 240
        period_seconds        = 240
        failure_threshold     = 1

        http_get {
          path = "/health"
          port = 8080
        }
      }
    }

    # Timeout configuration
    timeout = "240s"

    # Session affinity
    session_affinity = false
  }

  # Traffic configuration
  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }

  depends_on = [
    var.services_ready,
    var.networking_ready,
    var.secrets_ready,
    var.storage_ready,
    var.database_ready,
    var.redis_ready,
    var.artifact_registry_ready,
    var.cloud_build_initial_ready
  ]
}

# IAM policy for unauthenticated access
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  project  = var.project_id
  location = google_cloud_run_v2_service.open_webui.location
  name     = google_cloud_run_v2_service.open_webui.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Create custom domain mapping (optional)
resource "google_cloud_run_domain_mapping" "custom_domain" {
  count = var.custom_domain != null ? 1 : 0

  location = google_cloud_run_v2_service.open_webui.location
  name     = var.custom_domain
  project  = var.project_id

  metadata {
    namespace = var.project_id
    labels    = local.common_labels
  }

  spec {
    route_name = google_cloud_run_v2_service.open_webui.name
  }

  depends_on = [google_cloud_run_v2_service.open_webui]
} 
