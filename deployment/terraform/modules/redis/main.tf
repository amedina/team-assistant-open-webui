terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Memorystore Redis Instance
resource "google_redis_instance" "main" {
  name           = "${var.environment}-openwebui-redis"
  project        = var.project_id
  region         = var.region
  memory_size_gb = var.memory_size_gb
  tier           = var.tier
  
  # Redis configuration
  redis_version     = var.redis_version
  display_name      = "Open WebUI Redis (${var.environment})"
  reserved_ip_range = var.reserved_ip_range
  
  # Network configuration
  authorized_network = var.network_id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"
  
  # Redis configuration parameters
  redis_configs = var.redis_configs
  
  # Labels
  labels = var.labels
  
  # Maintenance policy
  maintenance_policy {
    weekly_maintenance_window {
      day = "SUNDAY"
      start_time {
        hours   = 4
        minutes = 0
      }
    }
  }
  
  # Authentication
  auth_enabled = var.auth_enabled
} 