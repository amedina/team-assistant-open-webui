output "enabled_services" {
  description = "List of enabled APIs/services"
  value = {
    for service in google_project_service.services :
    service.service => service.id
  }
}

output "project_id" {
  description = "The GCP project ID"
  value       = var.project_id
}

output "services_ready" {
  description = "Indicates that all required services are enabled"
  value       = true
  depends_on = [
    google_project_service.services,
    google_project_service.serviceusage,
    google_project_service.cloudresourcemanager,
    google_project_service.compute,
    google_project_service.vpcaccess
  ]
}

output "critical_services" {
  description = "Critical services that other modules depend on"
  value = {
    compute       = google_project_service.compute.id
    vpcaccess     = google_project_service.vpcaccess.id
    run           = google_project_service.services["run.googleapis.com"].id
    sql           = google_project_service.services["sqladmin.googleapis.com"].id
    redis         = google_project_service.services["redis.googleapis.com"].id
    storage       = google_project_service.services["storage.googleapis.com"].id
    secretmanager = google_project_service.services["secretmanager.googleapis.com"].id
  }
} 
