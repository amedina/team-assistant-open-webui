# https://registry.terraform.io/modules/terraform-google-modules/gcloud/google/latest
data "local_file" "dockerfile" {
  filename = "${path.module}/../../../../Dockerfile"
}

resource "google_cloudbuild_trigger" "initial_build_trigger" {
  project  = var.project_id
  name     = "${var.image_name}-initial-build"
  filename = var.build_config_path

  substitutions = {
    _ARTIFACT_REGISTRY_URL = var.artifact_repository_url
  }

  source_to_build {
    uri      = var.source_path
    ref      = "refs/heads/main"
    repo_type = "CLOUD_SOURCE_REPOSITORIES"
  }
}

resource "null_resource" "initial_image_build" {
  triggers = {
    dockerfile_sha256 = sha256(data.local_file.dockerfile.content)
  }

  provisioner "local-exec" {
    command = "gcloud builds triggers run ${google_cloudbuild_trigger.initial_build_trigger.name} --project=${var.project_id} --region=${var.region} --branch=${var.branch_name}"
  }
}
