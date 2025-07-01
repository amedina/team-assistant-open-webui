output "bucket_name" {
  description = "Name of the Cloud Storage bucket"
  value       = google_storage_bucket.openwebui_storage.name
}

output "bucket_url" {
  description = "URL of the Cloud Storage bucket"
  value       = google_storage_bucket.openwebui_storage.url
}

output "bucket_self_link" {
  description = "Self link of the Cloud Storage bucket"
  value       = google_storage_bucket.openwebui_storage.self_link
}

output "bucket_location" {
  description = "Location of the Cloud Storage bucket"
  value       = google_storage_bucket.openwebui_storage.location
} 