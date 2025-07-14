output "data_bucket_name" {
  description = "Name of the main data storage bucket"
  value       = google_storage_bucket.open_webui_data.name
}

output "data_bucket_url" {
  description = "URL of the main data storage bucket"
  value       = google_storage_bucket.open_webui_data.url
}

output "data_bucket_self_link" {
  description = "Self link of the main data storage bucket"
  value       = google_storage_bucket.open_webui_data.self_link
}

output "temp_bucket_name" {
  description = "Name of the temporary uploads bucket"
  value       = google_storage_bucket.temp_uploads.name
}

output "temp_bucket_url" {
  description = "URL of the temporary uploads bucket"
  value       = google_storage_bucket.temp_uploads.url
}

output "logs_bucket_name" {
  description = "Name of the access logs bucket (production only)"
  value       = var.environment == "prod" ? google_storage_bucket.access_logs[0].name : null
}

output "logs_bucket_url" {
  description = "URL of the access logs bucket (production only)"
  value       = var.environment == "prod" ? google_storage_bucket.access_logs[0].url : null
}

output "buckets" {
  description = "Map of all bucket information"
  value = {
    data = {
      name      = google_storage_bucket.open_webui_data.name
      url       = google_storage_bucket.open_webui_data.url
      self_link = google_storage_bucket.open_webui_data.self_link
    }
    temp = {
      name      = google_storage_bucket.temp_uploads.name
      url       = google_storage_bucket.temp_uploads.url
      self_link = google_storage_bucket.temp_uploads.self_link
    }
    logs = var.environment == "prod" ? {
      name      = google_storage_bucket.access_logs[0].name
      url       = google_storage_bucket.access_logs[0].url
      self_link = google_storage_bucket.access_logs[0].self_link
    } : null
  }
}

output "storage_ready" {
  description = "Indicates that storage resources are ready"
  value       = true
  depends_on = [
    google_storage_bucket.open_webui_data,
    google_storage_bucket.temp_uploads,
    google_storage_bucket_iam_member.cloud_run_data_access,
    google_storage_bucket_iam_member.cloud_run_temp_access,
    google_storage_bucket_iam_member.cloud_build_data_access
  ]
}

output "bucket_endpoints" {
  description = "S3-compatible API endpoints for buckets"
  value = {
    data_bucket = "https://storage.googleapis.com/${google_storage_bucket.open_webui_data.name}"
    temp_bucket = "https://storage.googleapis.com/${google_storage_bucket.temp_uploads.name}"
  }
}

output "bucket_locations" {
  description = "Locations of storage buckets"
  value = {
    data_bucket = google_storage_bucket.open_webui_data.location
    temp_bucket = google_storage_bucket.temp_uploads.location
    logs_bucket = var.environment == "prod" ? google_storage_bucket.access_logs[0].location : null
  }
} 
