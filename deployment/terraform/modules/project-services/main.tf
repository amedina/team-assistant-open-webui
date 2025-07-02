terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

locals {
  required_services = [
    "run.googleapis.com",                    # Cloud Run
    "sqladmin.googleapis.com",              # Cloud SQL
    "storage.googleapis.com",               # Cloud Storage
    "redis.googleapis.com",                 # Memorystore Redis
    "cloudbuild.googleapis.com",            # Cloud Build
    "artifactregistry.googleapis.com",      # Artifact Registry
    "vpcaccess.googleapis.com",             # VPC Access Connector
    "aiplatform.googleapis.com",            # Vertex AI
    "monitoring.googleapis.com",            # Cloud Monitoring
    "logging.googleapis.com",               # Cloud Logging
    "iam.googleapis.com",                   # Identity and Access Management
    "compute.googleapis.com",               # Compute Engine (for networking)
    "servicenetworking.googleapis.com",     # Service Networking
    "secretmanager.googleapis.com",         # Secret Manager
  ]
}

resource "google_project_service" "required_apis" {
  for_each = toset(local.required_services)
  
  project                    = var.project_id
  service                   = each.value
  disable_on_destroy        = false
  disable_dependent_services = false
}

# Wait for APIs to be enabled before other resources
resource "time_sleep" "api_propagation" {
  depends_on = [google_project_service.required_apis]
  
  create_duration = "60s"
} 