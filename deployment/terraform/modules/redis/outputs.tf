output "redis_instance_name" {
  description = "Name of the Redis instance"
  value       = google_redis_instance.cache.name
}

output "redis_instance_id" {
  description = "ID of the Redis instance"
  value       = google_redis_instance.cache.id
}

output "redis_host" {
  description = "Host address of the Redis instance"
  value       = google_redis_instance.cache.host
}

output "redis_port" {
  description = "Port of the Redis instance"
  value       = google_redis_instance.cache.port
}

output "redis_auth_string" {
  description = "Authentication string for Redis (sensitive)"
  value       = random_password.redis_auth.result
  sensitive   = true
}

output "redis_url" {
  description = "Complete Redis connection URL (sensitive)"
  value       = local.redis_url
  sensitive   = true
}

output "redis_memory_size_gb" {
  description = "Memory size of the Redis instance in GB"
  value       = google_redis_instance.cache.memory_size_gb
}

output "redis_tier" {
  description = "Tier of the Redis instance"
  value       = google_redis_instance.cache.tier
}

output "redis_version" {
  description = "Version of the Redis instance"
  value       = google_redis_instance.cache.redis_version
}

output "redis_location_id" {
  description = "Location ID of the Redis instance"
  value       = google_redis_instance.cache.location_id
}

output "redis_current_location_id" {
  description = "Current location ID of the Redis instance"
  value       = google_redis_instance.cache.current_location_id
}

output "redis_create_time" {
  description = "Creation time of the Redis instance"
  value       = google_redis_instance.cache.create_time
}

output "redis_maintenance_policy" {
  description = "Maintenance policy of the Redis instance"
  value = {
    weekly_maintenance_window = {
      day = google_redis_instance.cache.maintenance_policy[0].weekly_maintenance_window[0].day
      start_time = {
        hours   = google_redis_instance.cache.maintenance_policy[0].weekly_maintenance_window[0].start_time[0].hours
        minutes = google_redis_instance.cache.maintenance_policy[0].weekly_maintenance_window[0].start_time[0].minutes
      }
    }
  }
}

output "sessions_redis_instance_name" {
  description = "Name of the sessions Redis instance (if created)"
  value       = var.create_sessions_redis && var.environment == "prod" ? google_redis_instance.sessions[0].name : null
}

output "sessions_redis_host" {
  description = "Host address of the sessions Redis instance (if created)"
  value       = var.create_sessions_redis && var.environment == "prod" ? google_redis_instance.sessions[0].host : null
}

output "sessions_redis_port" {
  description = "Port of the sessions Redis instance (if created)"
  value       = var.create_sessions_redis && var.environment == "prod" ? google_redis_instance.sessions[0].port : null
}

output "redis_ready" {
  description = "Indicates that Redis resources are ready"
  value       = true
  depends_on = [
    google_redis_instance.cache,
    google_secret_manager_secret_version.redis_url
  ]
}

output "redis_info" {
  description = "Comprehensive Redis instance information"
  value = {
    main_instance = {
      name                = google_redis_instance.cache.name
      id                  = google_redis_instance.cache.id
      host                = google_redis_instance.cache.host
      port                = google_redis_instance.cache.port
      memory_size_gb      = google_redis_instance.cache.memory_size_gb
      tier                = google_redis_instance.cache.tier
      redis_version       = google_redis_instance.cache.redis_version
      location_id         = google_redis_instance.cache.location_id
      current_location_id = google_redis_instance.cache.current_location_id
      authorized_network  = google_redis_instance.cache.authorized_network
      connect_mode        = google_redis_instance.cache.connect_mode
      auth_enabled        = google_redis_instance.cache.auth_enabled
      create_time         = google_redis_instance.cache.create_time
      replica_count       = google_redis_instance.cache.replica_count
      labels              = google_redis_instance.cache.labels
    }
    sessions_instance = var.create_sessions_redis && var.environment == "prod" ? {
      name                = google_redis_instance.sessions[0].name
      id                  = google_redis_instance.sessions[0].id
      host                = google_redis_instance.sessions[0].host
      port                = google_redis_instance.sessions[0].port
      memory_size_gb      = google_redis_instance.sessions[0].memory_size_gb
      tier                = google_redis_instance.sessions[0].tier
      redis_version       = google_redis_instance.sessions[0].redis_version
      location_id         = google_redis_instance.sessions[0].location_id
      current_location_id = google_redis_instance.sessions[0].current_location_id
      create_time         = google_redis_instance.sessions[0].create_time
    } : null
  }
}

output "redis_monitoring_alerts" {
  description = "Information about Redis monitoring alerts"
  value = var.enable_monitoring ? {
    memory_alert = {
      name         = google_monitoring_alert_policy.redis_memory[0].name
      display_name = google_monitoring_alert_policy.redis_memory[0].display_name
      enabled      = google_monitoring_alert_policy.redis_memory[0].enabled
    }
    connections_alert = {
      name         = google_monitoring_alert_policy.redis_connections[0].name
      display_name = google_monitoring_alert_policy.redis_connections[0].display_name
      enabled      = google_monitoring_alert_policy.redis_connections[0].enabled
    }
  } : null
}

output "redis_connection_info" {
  description = "Connection information for applications"
  value = {
    main_cache = {
      host     = google_redis_instance.cache.host
      port     = google_redis_instance.cache.port
      database = 0
      url      = local.redis_url
    }
    sessions_cache = var.create_sessions_redis && var.environment == "prod" ? {
      host     = google_redis_instance.sessions[0].host
      port     = google_redis_instance.sessions[0].port
      database = 0
    } : null
  }
  sensitive = true
}

output "redis_network_info" {
  description = "Network configuration information"
  value = {
    authorized_network = google_redis_instance.cache.authorized_network
    connect_mode       = google_redis_instance.cache.connect_mode
    auth_enabled       = google_redis_instance.cache.auth_enabled
    region             = google_redis_instance.cache.region
    location_id        = google_redis_instance.cache.location_id
  }
} 
