terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
  }
}

locals {
  common_labels = {
    application = "open-webui"
    environment = var.environment
    managed-by  = "terraform"
  }
}

# Main storage bucket for Open WebUI data
resource "google_storage_bucket" "open_webui_data" {
  name          = "${var.project_id}-open-webui-data-${var.environment}"
  location      = var.region
  project       = var.project_id
  force_destroy = var.environment == "staging" ? true : false

  labels = local.common_labels

  # Uniform bucket-level access
  uniform_bucket_level_access = true

  # Versioning configuration
  versioning {
    enabled = var.environment == "prod" ? true : false
  }

  # Lifecycle configuration
  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  # Encryption with Google-managed keys
  encryption {
    default_kms_key_name = null
  }

  # CORS configuration for web access
  cors {
    origin          = ["*"]
    method          = ["GET", "POST", "PUT", "DELETE", "HEAD"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

  # Enable logging for production
  dynamic "logging" {
    for_each = var.environment == "prod" ? [1] : []
    content {
      log_bucket = google_storage_bucket.access_logs[0].name
    }
  }

  depends_on = [var.services_ready]
}

# Access logs bucket (production only)
resource "google_storage_bucket" "access_logs" {
  count = var.environment == "prod" ? 1 : 0

  name          = "${var.project_id}-open-webui-logs-${var.environment}"
  location      = var.region
  project       = var.project_id
  force_destroy = false

  labels = merge(local.common_labels, {
    purpose = "access-logs"
  })

  # Uniform bucket-level access
  uniform_bucket_level_access = true

  # Lifecycle configuration for logs
  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  depends_on = [var.services_ready]
}

# Bucket for temporary files and uploads
resource "google_storage_bucket" "temp_uploads" {
  name          = "${var.project_id}-open-webui-temp-${var.environment}"
  location      = var.region
  project       = var.project_id
  force_destroy = true

  labels = merge(local.common_labels, {
    purpose = "temp-uploads"
  })

  # Uniform bucket-level access
  uniform_bucket_level_access = true

  # Aggressive lifecycle for temp files
  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type = "Delete"
    }
  }

  # CORS configuration for uploads
  cors {
    origin          = ["*"]
    method          = ["GET", "POST", "PUT", "DELETE", "HEAD"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

  depends_on = [var.services_ready]
}

# IAM policy for service account access
resource "google_storage_bucket_iam_member" "cloud_run_data_access" {
  bucket = google_storage_bucket.open_webui_data.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.cloud_run_service_account_email}"
}

resource "google_storage_bucket_iam_member" "cloud_run_temp_access" {
  bucket = google_storage_bucket.temp_uploads.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.cloud_run_service_account_email}"
}

# Cloud Build access to buckets
resource "google_storage_bucket_iam_member" "cloud_build_data_access" {
  bucket = google_storage_bucket.open_webui_data.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.cloud_build_service_account_email}"
}

# Notification for bucket changes (optional)
resource "google_storage_notification" "bucket_notification" {
  count = var.enable_bucket_notifications ? 1 : 0

  bucket         = google_storage_bucket.open_webui_data.name
  payload_format = "JSON_API_V1"
  topic          = var.notification_topic
  event_types    = ["OBJECT_FINALIZE", "OBJECT_DELETE"]

  depends_on = [
    google_storage_bucket.open_webui_data,
    var.notification_topic
  ]
} 
