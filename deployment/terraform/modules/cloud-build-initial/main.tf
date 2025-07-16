terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
  }
}

data "local_file" "dockerfile" {
  filename = "${path.module}/../../../../Dockerfile"
}

resource "null_resource" "initial_image_build" {
  triggers = {
    # This ensures the build only runs when the Dockerfile changes.
    dockerfile_sha256 = sha256(data.local_file.dockerfile.content)
  }

  provisioner "local-exec" {
    # This command builds the image remotely on Google Cloud Build.
    command = "gcloud builds submit --config=${path.module}/../../../cloudbuild-initial.yaml --project=${var.project_id} --region=${var.region} --machine-type=E2_HIGHCPU_8 --substitutions=_ARTIFACT_REGISTRY_URL=${var.artifact_repository_url} ${path.module}/../../../../"
  }
}