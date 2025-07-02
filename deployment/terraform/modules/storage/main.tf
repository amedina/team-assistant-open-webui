terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Cloud Storage Bucket
resource "google_storage_bucket" "openwebui_storage" {
  name                        = var.bucket_name
  location                    = var.region
  project                     = var.project_id
  force_destroy               = var.force_destroy
  uniform_bucket_level_access = true
  
  labels = var.labels

  versioning {
    enabled = var.enable_versioning
  }

  lifecycle_rule {
    condition {
      age = var.lifecycle_age_days
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age                = 1
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  cors {
    origin          = var.cors_origins
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
}

# IAM binding for the Cloud Run service account
resource "google_storage_bucket_iam_member" "cloud_run_objectAdmin" {
  bucket = google_storage_bucket.openwebui_storage.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.service_account_email}"
}

# Create directories structure in the bucket (using dummy objects)
resource "google_storage_bucket_object" "app_data_dir" {
  name    = "app-data/.keep"
  content = "# This file ensures the app-data directory exists in the bucket"
  bucket  = google_storage_bucket.openwebui_storage.name
}

resource "google_storage_bucket_object" "uploads_dir" {
  name    = "uploads/.keep" 
  content = "# This file ensures the uploads directory exists in the bucket"
  bucket  = google_storage_bucket.openwebui_storage.name
}

resource "google_storage_bucket_object" "cache_dir" {
  name    = "cache/.keep"
  content = "# This file ensures the cache directory exists in the bucket"
  bucket  = google_storage_bucket.openwebui_storage.name
}

resource "google_storage_bucket_object" "models_dir" {
  name    = "models/.keep"
  content = "# This file ensures the models directory exists in the bucket"
  bucket  = google_storage_bucket.openwebui_storage.name
}

resource "google_storage_bucket_object" "backups_dir" {
  name    = "backups/.keep"
  content = "# This file ensures the backups directory exists in the bucket"
  bucket  = google_storage_bucket.openwebui_storage.name
} 