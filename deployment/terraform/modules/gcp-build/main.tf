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

  trigger_template {
    branch_name = var.branch_name
    project_id  = var.project_id
    repo_name   = var.github_repo_name
  }

  included_files = ["**/*.tf", "**/*.tfvars", "Dockerfile"]
}

resource "null_resource" "initial_image_build" {
  triggers = {
    dockerfile_sha256 = sha256(data.local_file.dockerfile.content)
  }

  provisioner "local-exec" {
    command = "gcloud builds triggers run ${google_cloudbuild_trigger.initial_build_trigger.name} --project=${var.project_id} --region=${var.region} --branch=${var.branch_name}"
  }
}
