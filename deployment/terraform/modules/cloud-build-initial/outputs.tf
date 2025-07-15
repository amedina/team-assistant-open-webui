output "build_trigger" {
  description = "The Cloud Build trigger resource."
  value       = google_cloudbuild_trigger.initial_build_trigger
}

output "cloud_build_initial_ready" {
  description = "Indicates that initial build of the image was successful and pushed"
  value       = true
  depends_on = [
    null_resource.initial_image_build,
    google_cloudbuild_trigger.initial_build_trigger
  ]
}