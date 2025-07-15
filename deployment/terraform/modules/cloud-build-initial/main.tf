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
    command = "BUILD_ID=$(gcloud builds triggers run ${google_cloudbuild_trigger.initial_build_trigger.name} --project=${var.project_id} --region=${var.region} --branch=${var.trigger_branch}) && gcloud builds log --stream $BUILD_ID"
  }
}
