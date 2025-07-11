terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Cloud Run Service V2
resource "google_cloud_run_v2_service" "openwebui" {
  name     = "${var.environment}-${var.service_name}"
  location = var.region
  project  = var.project_id

  template {
    labels = var.labels

    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    service_account       = var.service_account_email
    timeout               = "${var.timeout_seconds}s"

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

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
      image = var.container_image

      ports {
        container_port = var.container_port
        name           = "http1"
      }

      # Resource configuration using V2 structure
      resources {
        startup_cpu_boost = true
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
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

      # Environment variables
      dynamic "env" {
        for_each = var.environment_variables
        content {
          name  = env.key
          value = env.value
        }
      }

      # Health check probes
      liveness_probe {
        http_get {
          path = "/health"
          port = var.container_port
        }
        initial_delay_seconds = 1440
        timeout_seconds       = 240
        period_seconds        = 240
        failure_threshold     = 1
      }

      startup_probe {
        http_get {
          path = "/health"
          port = var.container_port
        }
        initial_delay_seconds = 240
        timeout_seconds       = 240
        period_seconds        = 240
        failure_threshold     = 5
      }
    }

    # VPC configuration (when VPC connector is provided)
    dynamic "vpc_access" {
      for_each = var.vpc_connector_name != "" ? [1] : []
      content {
        connector = "projects/${var.project_id}/locations/${var.region}/connectors/${var.vpc_connector_name}"
        egress    = "PRIVATE_RANGES_ONLY"
      }
    }

    # Container concurrency
    max_instance_request_concurrency = var.container_concurrency
  }

  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }

  lifecycle {
    ignore_changes = [
      template[0].annotations["run.googleapis.com/operation-id"]
    ]
  }

  # Lets wait for initial build before creating cloud run container
  depends_on = [null_resource.initial_image_build]

}

# IAM policy for public access (if enabled)
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  count    = var.allow_public_access ? 1 : 0
  name     = google_cloud_run_v2_service.openwebui.name
  location = google_cloud_run_v2_service.openwebui.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# IAM policy for authenticated access (if public access is disabled)
resource "google_cloud_run_v2_service_iam_member" "authenticated_access" {
  count    = var.allow_public_access ? 0 : 1
  name     = google_cloud_run_v2_service.openwebui.name
  location = google_cloud_run_v2_service.openwebui.location
  role     = "roles/run.invoker"
  member   = "allAuthenticatedUsers"
}

data "google_artifact_registry_repository" "openwebui" {
  location      = var.region
  project       = var.project_id
  repository_id = var.artifact_repository_name
}

# Generates initial image and pushes to artifact registry, to be used by cloud run container
# @TODO Skip generating the image if one already exists, except when Dockerfile changes.
resource "null_resource" "initial_image_build" {
  triggers = {
    build_trigger = timestamp()
  }

  provisioner "local-exec" {
    command = "gcloud builds submit --config=${path.module}/../../../cloudbuild-initial.yaml --project=${var.project_id} --region=${var.region} --machine-type=E2_HIGHCPU_8 --substitutions=_ARTIFACT_REGISTRY_URL=${var.artifact_repository_url} ${path.module}/../../../../"
  }
}