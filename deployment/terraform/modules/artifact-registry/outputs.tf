output "repository_id" {
  description = "ID of the Artifact Registry repository"
  value       = google_artifact_registry_repository.container_images.repository_id
}

output "repository_name" {
  description = "Name of the Artifact Registry repository"
  value       = google_artifact_registry_repository.container_images.name
}

output "repository_location" {
  description = "Location of the Artifact Registry repository"
  value       = google_artifact_registry_repository.container_images.location
}

output "repository_format" {
  description = "Format of the Artifact Registry repository"
  value       = google_artifact_registry_repository.container_images.format
}

output "repository_url" {
  description = "URL of the Artifact Registry repository"
  value       = "${google_artifact_registry_repository.container_images.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.container_images.repository_id}"
}

output "base_images_repository_id" {
  description = "ID of the base images repository (if created)"
  value       = var.create_base_images_repo ? google_artifact_registry_repository.base_images[0].repository_id : null
}

output "base_images_repository_url" {
  description = "URL of the base images repository (if created)"
  value       = var.create_base_images_repo ? "${google_artifact_registry_repository.base_images[0].location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.base_images[0].repository_id}" : null
}

output "image_notification_topic" {
  description = "Pub/Sub topic for image notifications (if enabled)"
  value       = var.enable_image_notifications ? google_pubsub_topic.image_notifications[0].name : null
}

output "image_notification_subscription" {
  description = "Pub/Sub subscription for image notifications (if enabled)"
  value       = var.enable_image_notifications ? google_pubsub_subscription.image_notifications[0].name : null
}

output "image_scanner_webhook_url" {
  description = "URL of the image scanner webhook (if enabled)"
  value       = var.enable_image_scanning_webhook ? google_cloud_run_service.image_scanner_webhook[0].status[0].url : null
}

output "artifact_registry_ready" {
  description = "Indicates that Artifact Registry resources are ready"
  value       = true
  depends_on = [
    google_artifact_registry_repository.container_images,
    google_artifact_registry_repository_iam_member.cloud_build_writer,
    google_artifact_registry_repository_iam_member.cloud_build_reader,
    google_artifact_registry_repository_iam_member.cloud_run_reader
  ]
}

output "repository_info" {
  description = "Comprehensive repository information"
  value = {
    main_repository = {
      id          = google_artifact_registry_repository.container_images.repository_id
      name        = google_artifact_registry_repository.container_images.name
      location    = google_artifact_registry_repository.container_images.location
      format      = google_artifact_registry_repository.container_images.format
      url         = "${google_artifact_registry_repository.container_images.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.container_images.repository_id}"
      labels      = google_artifact_registry_repository.container_images.labels
      create_time = google_artifact_registry_repository.container_images.create_time
      update_time = google_artifact_registry_repository.container_images.update_time
    }
    base_images_repository = var.create_base_images_repo ? {
      id          = google_artifact_registry_repository.base_images[0].repository_id
      name        = google_artifact_registry_repository.base_images[0].name
      location    = google_artifact_registry_repository.base_images[0].location
      format      = google_artifact_registry_repository.base_images[0].format
      url         = "${google_artifact_registry_repository.base_images[0].location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.base_images[0].repository_id}"
      labels      = google_artifact_registry_repository.base_images[0].labels
      create_time = google_artifact_registry_repository.base_images[0].create_time
      update_time = google_artifact_registry_repository.base_images[0].update_time
    } : null
  }
}

output "cleanup_policies" {
  description = "Information about cleanup policies"
  value = {
    main_repository = {
      keep_minimum_versions = {
        keep_count = var.keep_recent_versions
        older_than = "${var.image_retention_days}d"
      }
      cleanup_untagged = {
        older_than = "${var.untagged_retention_days}d"
      }
    }
    base_images_repository = var.create_base_images_repo ? {
      keep_base_images = {
        keep_count = var.keep_base_image_versions
        older_than = "${var.base_image_retention_days}d"
      }
    } : null
  }
}

output "docker_commands" {
  description = "Useful Docker commands for working with the repository"
  value = {
    configure_auth = "gcloud auth configure-docker ${google_artifact_registry_repository.container_images.location}-docker.pkg.dev"
    push_command   = "docker push ${google_artifact_registry_repository.container_images.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.container_images.repository_id}/IMAGE_NAME:TAG"
    pull_command   = "docker pull ${google_artifact_registry_repository.container_images.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.container_images.repository_id}/IMAGE_NAME:TAG"
  }
} 
