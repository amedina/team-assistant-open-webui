terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Cloud Run V2 Service
resource "google_cloud_run_v2_service" "openwebui" {
  name     = "${var.environment}-${var.service_name}"
  location = var.region
  project  = var.project_id

  labels = var.labels

  template {
    labels = var.labels

    # Scaling configuration (converted from annotations)
    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    # Service account
    service_account = var.service_account_email

    # Execution environment
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

    # Session affinity 
    session_affinity = false

    # Maximum request timeout
    timeout = "${var.timeout_seconds}s"

    # VPC access configuration
    vpc_access {
      connector = var.vpc_connector_name
      egress    = "PRIVATE_RANGES_ONLY"
    }

    # Cloud SQL instances configuration
    dynamic "volumes" {
      for_each = var.cloudsql_instances != "" ? [1] : []
      content {
        name = "cloudsql"
        cloud_sql_instance {
          instances = [var.cloudsql_instances]
        }
      }
    }

    containers {
      image = var.container_image
      name  = "open-webui"

      ports {
        container_port = var.container_port
        name           = "http1"
      }

      # Resource configuration
      resources {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
        cpu_idle          = false # Equivalent to cpu-throttling = false
        startup_cpu_boost = true
      }

      # Environment variables
      dynamic "env" {
        for_each = var.environment_variables
        content {
          name  = env.key
          value = env.value
        }
      }

      # Cloud SQL socket mounting
      dynamic "volume_mounts" {
        for_each = var.cloudsql_instances != "" ? [1] : []
        content {
          name       = "cloudsql"
          mount_path = "/cloudsql"
        }
      }

      # Startup probe
      startup_probe {
        timeout_seconds   = 240
        period_seconds    = 240
        failure_threshold = 1

        http_get {
          path = "/health"
          port = var.container_port
        }
      }

      # Liveness probe
      liveness_probe {
        timeout_seconds   = 240
        period_seconds    = 240
        failure_threshold = 1

        http_get {
          path = "/health"
          port = var.container_port
        }
      }
    }

    # Max concurrent requests per instance
    max_instance_request_concurrency = var.container_concurrency
  }

  # Traffic configuration
  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }

  lifecycle {
    ignore_changes = [
      # Ignore runtime-managed annotations
      template[0].annotations,
      annotations
    ]
  }
}

# IAM policy for public access (if enabled)
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  count    = var.allow_public_access ? 1 : 0
  name     = google_cloud_run_v2_service.openwebui.name
  location = google_cloud_run_v2_service.openwebui.location
  project  = var.project_id
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# IAM policy for authenticated access (if public access is disabled)
resource "google_cloud_run_v2_service_iam_member" "authenticated_access" {
  count    = var.allow_public_access ? 0 : 1
  name     = google_cloud_run_v2_service.openwebui.name
  location = google_cloud_run_v2_service.openwebui.location
  project  = var.project_id
  role     = "roles/run.invoker"
  member   = "allAuthenticatedUsers"
}
