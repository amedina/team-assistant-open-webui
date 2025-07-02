terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Cloud Run Service
resource "google_cloud_run_service" "openwebui" {
  name     = "${var.environment}-${var.service_name}"
  location = var.region
  project  = var.project_id

  template {
    metadata {
      labels = var.labels
      annotations = {
        "autoscaling.knative.dev/minScale"         = var.min_instances
        "autoscaling.knative.dev/maxScale"         = var.max_instances
        "run.googleapis.com/cloudsql-instances"    = var.cloudsql_instances
        "run.googleapis.com/vpc-access-connector"  = var.vpc_connector_name
        "run.googleapis.com/vpc-access-egress"     = "private-ranges-only"
        "run.googleapis.com/cpu-throttling"        = "false"
      }
    }

    spec {
      service_account_name = var.service_account_email
      container_concurrency = var.container_concurrency
      timeout_seconds      = var.timeout_seconds

      containers {
        image = var.container_image

        ports {
          container_port = var.container_port
          name          = "http1"
        }

        resources {
          limits = {
            cpu    = var.cpu_limit
            memory = var.memory_limit
          }
        }

        # Environment variables
        dynamic "env" {
          for_each = var.environment_variables
          content {
            name  = env.key
            value = env.value
          }
        }

        # Health check
        liveness_probe {
          http_get {
            path = "/health"
            port = var.container_port
          }
          initial_delay_seconds = 60
          timeout_seconds      = 10
          period_seconds       = 30
          failure_threshold    = 3
        }

        startup_probe {
          http_get {
            path = "/health"
            port = var.container_port
          }
          initial_delay_seconds = 10
          timeout_seconds      = 3
          period_seconds       = 5
          failure_threshold    = 12
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  autogenerate_revision_name = true

  lifecycle {
    ignore_changes = [
      template[0].metadata[0].annotations["run.googleapis.com/operation-id"],
      template[0].metadata[0].annotations["run.googleapis.com/operation-id"]
    ]
  }
}

# IAM policy for public access (if enabled)
resource "google_cloud_run_service_iam_member" "public_access" {
  count    = var.allow_public_access ? 1 : 0
  service  = google_cloud_run_service.openwebui.name
  location = google_cloud_run_service.openwebui.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# IAM policy for authenticated access (if public access is disabled)
resource "google_cloud_run_service_iam_member" "authenticated_access" {
  count    = var.allow_public_access ? 0 : 1
  service  = google_cloud_run_service.openwebui.name
  location = google_cloud_run_service.openwebui.location
  role     = "roles/run.invoker"
  member   = "allAuthenticatedUsers"
} 