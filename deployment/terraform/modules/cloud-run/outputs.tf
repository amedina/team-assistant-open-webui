output "service_name" {
  description = "Name of the Cloud Run service"
  value       = google_cloud_run_v2_service.open_webui.name
}

output "service_id" {
  description = "ID of the Cloud Run service"
  value       = google_cloud_run_v2_service.open_webui.id
}

output "service_url" {
  description = "URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.open_webui.uri
}

output "service_location" {
  description = "Location of the Cloud Run service"
  value       = google_cloud_run_v2_service.open_webui.location
}

output "service_project" {
  description = "Project of the Cloud Run service"
  value       = google_cloud_run_v2_service.open_webui.project
}

output "custom_domain_url" {
  description = "URL of the custom domain (if configured)"
  value       = var.custom_domain != null ? "https://${var.custom_domain}" : null
}

output "custom_domain_mapping" {
  description = "Custom domain mapping information"
  value = var.custom_domain != null ? {
    name     = google_cloud_run_domain_mapping.custom_domain[0].name
    location = google_cloud_run_domain_mapping.custom_domain[0].location
    project  = google_cloud_run_domain_mapping.custom_domain[0].project
  } : null
}

output "cloud_run_ready" {
  description = "Indicates that Cloud Run service is ready"
  value       = true
  depends_on = [
    google_cloud_run_v2_service.open_webui,
    google_cloud_run_v2_service_iam_member.public_access
  ]
}

output "service_info" {
  description = "Comprehensive Cloud Run service information"
  value = {
    name                    = google_cloud_run_v2_service.open_webui.name
    id                      = google_cloud_run_v2_service.open_webui.id
    uri                     = google_cloud_run_v2_service.open_webui.uri
    location                = google_cloud_run_v2_service.open_webui.location
    project                 = google_cloud_run_v2_service.open_webui.project
    labels                  = google_cloud_run_v2_service.open_webui.labels
    create_time             = google_cloud_run_v2_service.open_webui.create_time
    update_time             = google_cloud_run_v2_service.open_webui.update_time
    generation              = google_cloud_run_v2_service.open_webui.generation
    observed_generation     = google_cloud_run_v2_service.open_webui.observed_generation
    terminal_condition      = google_cloud_run_v2_service.open_webui.terminal_condition
    conditions              = google_cloud_run_v2_service.open_webui.conditions
    latest_ready_revision   = google_cloud_run_v2_service.open_webui.latest_ready_revision
    latest_created_revision = google_cloud_run_v2_service.open_webui.latest_created_revision
    traffic_statuses        = google_cloud_run_v2_service.open_webui.traffic_statuses
    ingress                 = google_cloud_run_v2_service.open_webui.ingress
    launch_stage            = google_cloud_run_v2_service.open_webui.launch_stage
  }
}

output "service_configuration" {
  description = "Service configuration details"
  value = {
    container_image = var.container_image_url
    service_account = var.cloud_run_service_account_email
    cpu_limit       = var.cpu_limit
    memory_limit    = var.memory_limit
    min_instances   = var.min_instances
    max_instances   = var.max_instances
    vpc_connector   = var.vpc_connector_name
    port            = var.port
    timeout         = var.request_timeout_seconds
    environment     = var.environment
  }
}

output "environment_variables" {
  description = "Environment variables configuration (non-sensitive)"
  value = {
    STORAGE_PROVIDER    = "s3"
    S3_BUCKET_NAME      = var.storage_bucket_name
    S3_ENDPOINT_URL     = "https://storage.googleapis.com"
    ENABLE_OAUTH_SIGNUP = "true"
    OAUTH_PROVIDER      = "google"
    ENVIRONMENT         = var.environment
    PORT                = tostring(var.port)
  }
}

output "secret_environment_variables" {
  description = "Secret environment variables configuration"
  value = {
    WEBUI_SECRET_KEY         = var.webui_secret_key_secret_id
    DATABASE_URL             = var.database_url_secret_id
    REDIS_URL                = var.redis_url_secret_id
    GOOGLE_CLIENT_SECRET     = var.oauth_client_secret_secret_id
    AGENT_ENGINE_RESOURCE_ID = var.agent_engine_secret_id
  }
}

output "health_check_configuration" {
  description = "Health check configuration"
  value = {
    path                       = var.health_check_path
    port                       = var.port
    startup_timeout_seconds    = var.startup_timeout_seconds
    startup_initial_delay      = 30
    startup_period_seconds     = 10
    startup_failure_threshold  = 5
    liveness_initial_delay     = 30
    liveness_period_seconds    = 30
    liveness_failure_threshold = 3
  }
}

output "scaling_configuration" {
  description = "Scaling configuration"
  value = {
    min_instances     = var.min_instances
    max_instances     = var.max_instances
    cpu_idle          = true
    startup_cpu_boost = true
  }
}

output "networking_configuration" {
  description = "Networking configuration"
  value = {
    vpc_connector = var.vpc_connector_name
    egress        = "ALL_TRAFFIC"
    ingress       = var.ingress
  }
}

output "iam_configuration" {
  description = "IAM configuration"
  value = {
    service_account = var.cloud_run_service_account_email
    public_access   = var.enable_public_access
    invoker_members = var.enable_public_access ? ["allUsers"] : []
  }
}

output "deployment_commands" {
  description = "Useful deployment commands"
  value = {
    deploy_new_revision = "gcloud run deploy ${google_cloud_run_v2_service.open_webui.name} --image=${var.container_image_url} --region=${var.region} --project=${var.project_id}"
    get_service_info    = "gcloud run services describe ${google_cloud_run_v2_service.open_webui.name} --region=${var.region} --project=${var.project_id}"
    get_service_logs    = "gcloud logs read 'resource.type=cloud_run_revision AND resource.labels.service_name=${google_cloud_run_v2_service.open_webui.name}' --project=${var.project_id}"
    test_service        = "curl -H 'Authorization: Bearer $(gcloud auth print-identity-token)' ${google_cloud_run_v2_service.open_webui.uri}${var.health_check_path}"
  }
} 
