# https://registry.terraform.io/modules/terraform-google-modules/gcloud/google/latest
data "local_file" "dockerfile" {
  filename = "${path.module}/../../../../Dockerfile"
}

resource "google_cloudbuild_trigger" "initial_build_trigger" {
  project  = var.project_id
  name     = "${var.environment}-initial-build"
  location    = var.region
  filename = var.build_config_path
  description = "Initial trigger for Open WebUI ${var.environment} environment"

  substitutions = {
    _ARTIFACT_REGISTRY_URL = var.artifact_repository_url
    _ENVIRONMENT = var.environment
  }

  github {
    owner = var.github_repo_owner
    name  = var.github_repo_name

    push {
      branch = var.trigger_branch
    }
  }

  included_files = ["**/*.tf", "**/*.tfvars", "Dockerfile"]

  service_account = "projects/-/serviceAccounts/${var.cloud_build_service_account_email}"

  tags = [var.environment, "open-webui", "release"]
}

resource "null_resource" "initial_image_build" {
  triggers = {
    # This ensures the build only runs when the Dockerfile changes.
    dockerfile_sha256 = sha256(data.local_file.dockerfile.content)
  }

  provisioner "local-exec" {
    # Using bash -c allows for a more complex, multi-line script.
    # This script triggers the build, polls for its status, and exits
    # with a proper status code, failing the terraform apply on build failure.
    interpreter = ["bash", "-c"]
    command     = <<EOT
      set -e # Exit immediately if a command exits with a non-zero status.

      echo "Triggering initial image build for branch '${var.trigger_branch}'..."
      BUILD_ID=$(gcloud builds triggers run ${google_cloudbuild_trigger.initial_build_trigger.name} \
        --project=${var.project_id} \
        --branch=${var.trigger_branch} \
        --format="value(metadata.build.id)")

      if [ -z "$BUILD_ID" ]; then
        echo "Error: Failed to trigger build or retrieve build ID." >&2
        exit 1
      fi

      echo "Build started with ID: $BUILD_ID. Waiting for completion..."

      while true; do
        STATUS=$(gcloud builds describe "$BUILD_ID" --project=${var.project_id} --format="value(status)")

        case "$STATUS" in
          SUCCESS)
            echo "✅ Build $BUILD_ID completed successfully."
            exit 0
            ;;
          FAILURE|INTERNAL_ERROR|TIMEOUT|CANCELLED)
            echo "❌ Error: Build $BUILD_ID failed with status: $STATUS" >&2
            LOGS_URL=$(gcloud builds describe "$BUILD_ID" --project=${var.project_id} --format="value(logUrl)")
            echo "Logs available at: $LOGS_URL" >&2
            exit 1
            ;;
          *)
            echo "Build status is '$STATUS'. Waiting..."
            sleep 15
            ;;
        esac
      done
    EOT
  }
}