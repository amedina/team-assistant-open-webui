output "project_id" {
  description = "Google Cloud Project ID"
  value       = var.project_id
}

output "region" {
  description = "Google Cloud region"
  value       = var.region
}

output "environment" {
  description = "Environment name"
  value       = "staging"
}

# Cloud Run Outputs
output "cloud_run_service_url" {
  description = "URL of the Cloud Run service"
  value       = module.cloud_run.service_url
}

output "cloud_run_service_name" {
  description = "Name of the Cloud Run service"
  value       = module.cloud_run.service_name
}

# Database Outputs
output "database_connection_name" {
  description = "Cloud SQL connection name"
  value       = module.database.connection_name
}

output "database_private_ip" {
  description = "Database private IP address"
  value       = module.database.private_ip_address
  sensitive   = true
}

# Storage Outputs
output "storage_bucket_name" {
  description = "Name of the storage bucket"
  value       = module.storage.bucket_name
}

output "storage_bucket_url" {
  description = "URL of the storage bucket"
  value       = module.storage.bucket_url
}

# Redis Outputs
output "redis_host" {
  description = "Redis host address"
  value       = module.redis.host
  sensitive   = true
}

output "redis_port" {
  description = "Redis port"
  value       = module.redis.port
}

# Artifact Registry Outputs
output "artifact_registry_url" {
  description = "Artifact Registry repository URL"
  value       = module.artifact_registry.repository_url
}

# Network Outputs
output "vpc_network_name" {
  description = "VPC network name"
  value       = module.networking.vpc_network_name
}

output "vpc_connector_name" {
  description = "VPC connector name (if enabled)"
  value       = try(module.networking.vpc_connector_name, "vpc-connector-disabled")
}

# Service Account Outputs
output "cloud_run_service_account_email" {
  description = "Cloud Run service account email"
  value       = module.iam.cloud_run_service_account_email
}

output "cloud_build_service_account_email" {
  description = "Cloud Build service account email"
  value       = module.iam.cloud_build_service_account_email
}

# Application Configuration
output "application_url" {
  description = "Application URL (same as Cloud Run service URL)"
  value       = module.cloud_run.service_url
}

output "oauth_redirect_uri" {
  description = "OAuth redirect URI to configure in Google Cloud Console"
  value       = "${module.cloud_run.service_url}/oauth/google/callback"
}

# Staging Deployment Information
output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    environment    = "staging"
    cloud_run_url  = module.cloud_run.service_url
    database_tier  = var.database_tier
    redis_tier     = var.redis_tier
    storage_bucket = module.storage.bucket_name
    min_instances  = var.cloud_run_min_instances
    max_instances  = var.cloud_run_max_instances
    project_id     = var.project_id
    region         = var.region
  }
}

# Security Information
output "security_summary" {
  description = "Security configuration summary"
  value = {
    database_deletion_protection = false # Disabled for staging
    high_availability_enabled    = false # Disabled for staging
    backup_enabled               = true
    vpc_egress_control           = "private-ranges-only"
    oauth_enabled                = true
    signup_enabled               = true # Enabled for staging testing
  }
}
