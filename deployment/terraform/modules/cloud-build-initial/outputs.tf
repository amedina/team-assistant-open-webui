output "cloud_build_initial_ready" {
  description = "Indicates that initial build of the image was successful and pushed"
  value       = true
  depends_on = [
    null_resource.initial_image_build
  ]
}