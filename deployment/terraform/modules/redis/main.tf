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

# Redis instance (Memorystore)
resource "google_redis_instance" "cache" {
  name           = "${var.environment}-open-webui-redis"
  project        = var.project_id
  region         = var.region
  tier           = "BASIC"
  memory_size_gb = var.redis_memory_size_gb
  redis_version  = var.redis_version
  display_name   = "Open WebUI Redis Cache (${var.environment})"

  # Network configuration - private network only
  authorized_network = var.vpc_network_id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"

  # Auth configuration
  auth_enabled = true

  # Labels
  labels = local.common_labels

  # Location preference
  location_id = var.redis_location_id

  # Alternative location for high availability (not available in BASIC tier)
  # alternative_location_id = var.environment == "prod" ? var.redis_alternative_location_id : null

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

  # Persistence configuration (not available in BASIC tier)
  # persistence_config {
  #   persistence_mode    = "RDB"
  #   rdb_snapshot_period = "TWENTY_FOUR_HOURS"
  # }

  # Read replicas (not available in BASIC tier)
  replica_count = 0

  # Customer managed encryption key (optional)
  customer_managed_key = var.redis_cmek_key

  depends_on = [
    var.services_ready,
    var.private_service_connection_id
  ]
}

# Create Redis URL with authentication
locals {
  redis_url = "redis://:${google_redis_instance.cache.auth_string}@${google_redis_instance.cache.host}:${google_redis_instance.cache.port}/0"
}

# Store Redis URL in Secret Manager
resource "google_secret_manager_secret_version" "redis_url" {
  secret      = var.redis_url_secret_id
  secret_data = local.redis_url

  depends_on = [google_redis_instance.cache]
}

# Optional: Create additional Redis instance for sessions (production only)
resource "google_redis_instance" "sessions" {
  count = var.create_sessions_redis && var.environment == "prod" ? 1 : 0

  name           = "${var.environment}-open-webui-redis-sessions"
  project        = var.project_id
  region         = var.region
  tier           = "BASIC"
  memory_size_gb = var.sessions_redis_memory_size_gb
  redis_version  = var.redis_version
  display_name   = "Open WebUI Redis Sessions (${var.environment})"

  # Network configuration - private network only
  authorized_network = var.vpc_network_id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"

  # Auth configuration
  auth_enabled = true

  # Labels
  labels = merge(local.common_labels, {
    purpose = "sessions"
  })

  # Location preference
  location_id = var.redis_location_id

  # Maintenance policy
  maintenance_policy {
    weekly_maintenance_window {
      day = "SUNDAY"
      start_time {
        hours   = 4
        minutes = 30
      }
    }
  }

  replica_count = 0

  depends_on = [
    var.services_ready,
    var.private_service_connection_id,
    google_redis_instance.cache
  ]
}

# Create monitoring alerts for Redis
resource "google_monitoring_alert_policy" "redis_memory" {
  count = var.enable_monitoring ? 1 : 0

  display_name = "Redis Memory Usage High - ${var.environment}"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Redis memory usage > 80%"

    condition_threshold {
      filter          = "resource.type=\"redis_instance\" AND resource.labels.instance_id=\"${google_redis_instance.cache.id}\""
      comparison      = "COMPARISON_GREATER_THAN"
      threshold_value = 0.8
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = var.notification_channels

  alert_strategy {
    notification_rate_limit {
      period = "300s"
    }
    auto_close = "1800s"
  }

  depends_on = [google_redis_instance.cache]
}

# Monitoring alert for Redis connections
resource "google_monitoring_alert_policy" "redis_connections" {
  count = var.enable_monitoring ? 1 : 0

  display_name = "Redis Connection Count High - ${var.environment}"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Redis connection count > 90% of limit"

    condition_threshold {
      filter          = "resource.type=\"redis_instance\" AND resource.labels.instance_id=\"${google_redis_instance.cache.id}\""
      comparison      = "COMPARISON_GREATER_THAN"
      threshold_value = 900 # 90% of 1000 default connections
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = var.notification_channels

  alert_strategy {
    notification_rate_limit {
      period = "300s"
    }
    auto_close = "1800s"
  }

  depends_on = [google_redis_instance.cache]
}
