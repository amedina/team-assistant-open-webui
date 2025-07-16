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

  # Cloud Build timeout of 10 minutes as specified
  build_timeout = "600s"
}

# Cloud Build trigger for staging (automatic)
resource "google_cloudbuild_trigger" "staging_trigger" {
  count = var.environment == "staging" ? 1 : 0

  name        = "${var.environment}-open-webui-build"
  project     = var.project_id
  description = "Automated build trigger for Open WebUI staging environment"

  # Trigger on push to main branch
  github {
    owner = var.github_repo_owner
    name  = var.github_repo_name

    push {
      branch = "^${var.trigger_branch}$"
    }
  }

  # Build configuration
  build {
    timeout = local.build_timeout

    # Use e2-standard-2 for faster builds
    options {
      machine_type            = "E2_HIGHCPU_8"
      requested_verify_option = "VERIFIED"
    }

    # Build steps
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "build",
        "-t", "${var.artifact_registry_url}/${var.environment}-open-webui:$SHORT_SHA",
        "-t", "${var.artifact_registry_url}/${var.environment}-open-webui:latest",
        "."
      ]
    }

    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push",
        "${var.artifact_registry_url}/${var.environment}-open-webui:$SHORT_SHA"
      ]
    }

    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push",
        "${var.artifact_registry_url}/${var.environment}-open-webui:latest"
      ]
    }

    # Deploy to Cloud Run
    step {
      name = "gcr.io/cloud-builders/gcloud"
      args = [
        "run", "deploy", "${var.environment}-open-webui",
        "--image", "${var.artifact_registry_url}:${var.environment}-open-webui:$SHORT_SHA",
        "--region", var.region,
        "--platform", "managed",
        "--service-account", "projects/-/serviceAccounts/${var.cloud_build_service_account_email}",
        "--vpc-connector", var.vpc_connector_name,
        "--memory", var.cloud_run_memory,
        "--cpu", var.cloud_run_cpu,
        "--min-instances", tostring(var.cloud_run_min_instances),
        "--max-instances", tostring(var.cloud_run_max_instances),
        "--timeout", tostring(var.cloud_run_timeout),
        "--allow-unauthenticated"
      ]
    }

    # Substitutions
    substitutions = {
      _ENVIRONMENT = var.environment
      _REGION      = var.region
    }
  }

  # Service account for Cloud Build
  service_account = "projects/-/serviceAccounts/${var.cloud_build_service_account_email}"

  # Include/exclude files
  included_files = var.build_included_files
  ignored_files  = var.build_ignored_files

  depends_on = [
    var.services_ready,
    var.artifact_registry_ready
  ]
}

# Cloud Build trigger for production (manual)
resource "google_cloudbuild_trigger" "production_trigger" {
  count = var.environment == "prod" ? 1 : 0

  name        = "${var.environment}-open-webui-build"
  project     = var.project_id
  description = "Manual build trigger for Open WebUI production environment"

  # Manual trigger (requires approval)
  github {
    owner = var.github_repo_owner
    name  = var.github_repo_name

    # Production triggers on version tags
    push {
      tag = "^v[0-9]+\\.[0-9]+\\.[0-9]+$"
    }
  }

  # Build configuration
  build {
    timeout = local.build_timeout

    # Use e2-standard-2 for faster builds
    options {
      machine_type            = "E2_HIGHCPU_8"
      requested_verify_option = "VERIFIED"
    }

    # Build steps for production
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "build",
        "-t", "${var.artifact_registry_url}/${var.environment}-open-webui:$TAG_NAME",
        "-t", "${var.artifact_registry_url}/${var.environment}-open-webui:latest",
        "."
      ]
    }

    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push",
        "${var.artifact_registry_url}/${var.environment}-open-webui:$TAG_NAME"
      ]
    }

    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push",
        "${var.artifact_registry_url}/${var.environment}-open-webui:latest"
      ]
    }

    # Deploy to Cloud Run (production requires manual approval)
    step {
      name = "gcr.io/cloud-builders/gcloud"
      args = [
        "run", "deploy", "${var.environment}-open-webui",
        "--image", "${var.artifact_registry_url}/${var.environment}-open-webui:$TAG_NAME",
        "--region", var.region,
        "--platform", "managed",
        "--service-account", "projects/-/serviceAccounts/${var.cloud_build_service_account_email}",
        "--vpc-connector", var.vpc_connector_name,
        "--memory", var.cloud_run_memory,
        "--cpu", var.cloud_run_cpu,
        "--min-instances", tostring(var.cloud_run_min_instances),
        "--max-instances", tostring(var.cloud_run_max_instances),
        "--timeout", tostring(var.cloud_run_timeout),
        "--allow-unauthenticated"
      ]
    }

    # Substitutions
    substitutions = {
      _ENVIRONMENT = var.environment
      _REGION      = var.region
    }
  }

  # Service account for Cloud Build
  service_account = "projects/-/serviceAccounts/${var.cloud_build_service_account_email}"

  # Include/exclude files
  included_files = var.build_included_files
  ignored_files  = var.build_ignored_files

  depends_on = [
    var.services_ready,
    var.artifact_registry_ready
  ]
}

# Cloud Build notification topic
resource "google_pubsub_topic" "build_notifications" {
  count = var.enable_build_notifications ? 1 : 0

  name    = "${var.environment}-open-webui-build-notifications"
  project = var.project_id

  labels = local.common_labels

  depends_on = [var.services_ready]
}

# Cloud Build notification subscription
resource "google_pubsub_subscription" "build_notifications" {
  count = var.enable_build_notifications ? 1 : 0

  name    = "${var.environment}-open-webui-build-notifications-sub"
  project = var.project_id
  topic   = google_pubsub_topic.build_notifications[0].name

  ack_deadline_seconds = 20

  depends_on = [var.services_ready]
}

# Cloud Build history cleanup
resource "google_cloudbuild_trigger" "cleanup_trigger" {
  count = var.enable_build_cleanup ? 1 : 0

  name        = "${var.environment}-open-webui-cleanup"
  project     = var.project_id
  description = "Cleanup old build artifacts for Open WebUI ${var.environment}"

  # Trigger daily at 2 AM
  pubsub_config {
    topic = google_pubsub_topic.build_notifications[0].id
  }

  build {
    timeout = "300s"

    step {
      name   = "gcr.io/cloud-builders/gcloud"
      script = <<-EOF
        #!/bin/bash
        # Delete builds older than 30 days
        gcloud builds list \
          --filter="createTime<-P30D" \
          --format="value(id)" \
          --project=${var.project_id} | \
        xargs -r gcloud builds cancel --project=${var.project_id}
      EOF
    }
  }

  service_account = "projects/-/serviceAccounts/${var.cloud_build_service_account_email}"

  depends_on = [
    var.services_ready,
    google_pubsub_topic.build_notifications
  ]
} 
