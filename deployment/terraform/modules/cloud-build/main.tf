terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Cloud Build trigger for automatic builds
resource "google_cloudbuild_trigger" "main" {
  project     = var.project_id
  name        = "${var.environment}-open-webui-trigger"
  description = "Trigger for Open WebUI ${var.environment} environment"
  
  # Trigger on push to specific branch
  github {
    owner = var.github_owner
    name  = var.github_repo
    push {
      branch = var.trigger_branch
    }
  }

  # Build configuration
  build {
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "build",
        "-t", "${var.artifact_registry_url}/open-webui:$COMMIT_SHA",
        "-t", "${var.artifact_registry_url}/open-webui:latest",
        "-f", "Dockerfile",
        "."
      ]
    }

    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push", 
        "${var.artifact_registry_url}/open-webui:$COMMIT_SHA"
      ]
    }

    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push", 
        "${var.artifact_registry_url}/open-webui:latest"
      ]
    }

    # Deploy to Cloud Run (if enabled)
    dynamic "step" {
      for_each = var.auto_deploy ? [1] : []
      content {
        name = "gcr.io/cloud-builders/gcloud"
        args = [
          "run", "deploy", "${var.environment}-${var.cloud_run_service_name}",
          "--image", "${var.artifact_registry_url}/open-webui:$COMMIT_SHA",
          "--region", var.region,
          "--platform", "managed",
          "--quiet"
        ]
      }
    }

    # Available substitutions
    substitutions = {
      _ENVIRONMENT = var.environment
      _REGION      = var.region
    }

    # Build options
    options {
      logging = "CLOUD_LOGGING_ONLY"
      machine_type = var.build_machine_type
    }

    # Build timeout
    timeout = "${var.build_timeout_seconds}s"
  }

  # Include/exclude files
  included_files = var.included_files
  ignored_files  = var.ignored_files

  tags = ["${var.environment}", "open-webui"]
}

# Cloud Build trigger for manual builds (tagged releases)
resource "google_cloudbuild_trigger" "release" {
  count       = var.enable_release_trigger ? 1 : 0
  project     = var.project_id
  name        = "${var.environment}-open-webui-release-trigger"
  description = "Release trigger for Open WebUI ${var.environment} environment"
  
  # Trigger on tag creation
  github {
    owner = var.github_owner
    name  = var.github_repo
    push {
      tag = var.release_tag_pattern
    }
  }

  # Build configuration for releases
  build {
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "build",
        "-t", "${var.artifact_registry_url}/open-webui:$TAG_NAME",
        "-t", "${var.artifact_registry_url}/open-webui:stable",
        "-f", "Dockerfile",
        "."
      ]
    }

    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push", 
        "${var.artifact_registry_url}/open-webui:$TAG_NAME"
      ]
    }

    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push", 
        "${var.artifact_registry_url}/open-webui:stable"
      ]
    }

    # Deploy tagged release to production (if this is prod environment)
    dynamic "step" {
      for_each = var.environment == "prod" && var.auto_deploy ? [1] : []
      content {
        name = "gcr.io/cloud-builders/gcloud"
        args = [
          "run", "deploy", "${var.environment}-${var.cloud_run_service_name}",
          "--image", "${var.artifact_registry_url}/open-webui:$TAG_NAME",
          "--region", var.region,
          "--platform", "managed",
          "--quiet"
        ]
      }
    }

    substitutions = {
      _ENVIRONMENT = var.environment
      _REGION      = var.region
    }

    options {
      logging = "CLOUD_LOGGING_ONLY"
      machine_type = var.build_machine_type
    }

    timeout = "${var.build_timeout_seconds}s"
  }

  tags = ["${var.environment}", "open-webui", "release"]
}

# IAM binding for Cloud Build to deploy to Cloud Run
resource "google_project_iam_member" "cloud_build_run_developer" {
  count   = var.auto_deploy ? 1 : 0
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${var.service_account_email}"
} 