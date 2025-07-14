terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
  }
}

locals {
  apis = [
    "serviceusage.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "vpcaccess.googleapis.com",
    "storage.googleapis.com",
    "secretmanager.googleapis.com",
    "sqladmin.googleapis.com",
    "redis.googleapis.com",
    "run.googleapis.com",
    "aiplatform.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudtrace.googleapis.com",
    "container.googleapis.com"
  ]
}

# Enable APIs in dependency order
resource "google_project_service" "services" {
  for_each = toset(local.apis)

  project = var.project_id
  service = each.value

  disable_dependent_services = false
  disable_on_destroy         = false

  timeouts {
    create = "10m"
    update = "10m"
  }
}

# Add explicit dependencies for critical services
resource "google_project_service" "serviceusage" {
  project = var.project_id
  service = "serviceusage.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
}

resource "google_project_service" "cloudresourcemanager" {
  project = var.project_id
  service = "cloudresourcemanager.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false

  depends_on = [google_project_service.serviceusage]
}

resource "google_project_service" "compute" {
  project = var.project_id
  service = "compute.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false

  depends_on = [google_project_service.cloudresourcemanager]
}

resource "google_project_service" "vpcaccess" {
  project = var.project_id
  service = "vpcaccess.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false

  depends_on = [google_project_service.compute]
} 
