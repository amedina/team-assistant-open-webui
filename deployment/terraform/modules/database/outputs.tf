output "database_instance_name" {
  description = "Name of the Cloud SQL instance"
  value       = google_sql_database_instance.postgresql.name
}

output "database_instance_id" {
  description = "ID of the Cloud SQL instance"
  value       = google_sql_database_instance.postgresql.id
}

output "database_instance_connection_name" {
  description = "Connection name of the Cloud SQL instance"
  value       = google_sql_database_instance.postgresql.connection_name
}

output "database_private_ip" {
  description = "Private IP address of the database instance"
  value       = google_sql_database_instance.postgresql.private_ip_address
}

output "database_public_ip" {
  description = "Public IP address of the database instance (should be null for private instance)"
  value       = google_sql_database_instance.postgresql.public_ip_address
}

output "database_name" {
  description = "Name of the application database"
  value       = google_sql_database.app_database.name
}

output "database_username" {
  description = "Username for database access"
  value       = google_sql_user.app_user.name
}

output "database_password" {
  description = "Database password (sensitive)"
  value       = random_password.db_password.result
  sensitive   = true
}

output "database_url" {
  description = "Complete database connection URL (sensitive)"
  value       = local.database_url
  sensitive   = true
}

output "database_ssl_cert" {
  description = "SSL certificate for database connection"
  value = {
    cert           = google_sql_ssl_cert.client_cert.cert
    private_key    = google_sql_ssl_cert.client_cert.private_key
    server_ca_cert = google_sql_ssl_cert.client_cert.server_ca_cert
  }
  sensitive = true
}

output "read_replica_instance_name" {
  description = "Name of the read replica instance (if enabled)"
  value       = var.environment == "prod" && var.enable_read_replica ? google_sql_database_instance.read_replica[0].name : null
}

output "read_replica_private_ip" {
  description = "Private IP address of the read replica instance (if enabled)"
  value       = var.environment == "prod" && var.enable_read_replica ? google_sql_database_instance.read_replica[0].private_ip_address : null
}

output "database_ready" {
  description = "Indicates that database resources are ready"
  value       = true
  depends_on = [
    google_sql_database_instance.postgresql,
    google_sql_database.app_database,
    google_sql_user.app_user,
    google_sql_ssl_cert.client_cert,
    google_secret_manager_secret_version.db_password,
    google_secret_manager_secret_version.database_url
  ]
}

output "database_info" {
  description = "Comprehensive database information"
  value = {
    instance = {
      name             = google_sql_database_instance.postgresql.name
      id               = google_sql_database_instance.postgresql.id
      connection_name  = google_sql_database_instance.postgresql.connection_name
      private_ip       = google_sql_database_instance.postgresql.private_ip_address
      public_ip        = google_sql_database_instance.postgresql.public_ip_address
      region           = google_sql_database_instance.postgresql.region
      database_version = google_sql_database_instance.postgresql.database_version
      settings = {
        tier              = google_sql_database_instance.postgresql.settings[0].tier
        availability_type = google_sql_database_instance.postgresql.settings[0].availability_type
        disk_size         = google_sql_database_instance.postgresql.settings[0].disk_size
        disk_type         = google_sql_database_instance.postgresql.settings[0].disk_type
      }
    }
    database = {
      name      = google_sql_database.app_database.name
      charset   = google_sql_database.app_database.charset
      collation = google_sql_database.app_database.collation
    }
    user = {
      name = google_sql_user.app_user.name
    }
    read_replica = var.environment == "prod" && var.enable_read_replica ? {
      name       = google_sql_database_instance.read_replica[0].name
      private_ip = google_sql_database_instance.read_replica[0].private_ip_address
      region     = google_sql_database_instance.read_replica[0].region
    } : null
  }
}

output "additional_databases" {
  description = "Information about additional databases"
  value = {
    sessions = var.create_sessions_database ? {
      name = google_sql_database.sessions_database[0].name
    } : null
    analytics = var.create_analytics_database && var.environment == "prod" ? {
      name = google_sql_database.analytics_database[0].name
    } : null
  }
}

output "backup_configuration" {
  description = "Backup configuration information"
  value = {
    enabled                        = google_sql_database_instance.postgresql.settings[0].backup_configuration[0].enabled
    start_time                     = google_sql_database_instance.postgresql.settings[0].backup_configuration[0].start_time
    location                       = google_sql_database_instance.postgresql.settings[0].backup_configuration[0].location
    point_in_time_recovery_enabled = google_sql_database_instance.postgresql.settings[0].backup_configuration[0].point_in_time_recovery_enabled
    transaction_log_retention_days = google_sql_database_instance.postgresql.settings[0].backup_configuration[0].transaction_log_retention_days
  }
}

output "maintenance_window" {
  description = "Maintenance window configuration"
  value = {
    day          = google_sql_database_instance.postgresql.settings[0].maintenance_window[0].day
    hour         = google_sql_database_instance.postgresql.settings[0].maintenance_window[0].hour
    update_track = google_sql_database_instance.postgresql.settings[0].maintenance_window[0].update_track
  }
} 
