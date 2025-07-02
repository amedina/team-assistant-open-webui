terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Cloud SQL PostgreSQL Instance
resource "google_sql_database_instance" "postgres" {
  name             = "${var.environment}-open-webui-db"
  database_version = var.database_version
  region           = var.region
  project          = var.project_id

  settings {
    tier                        = var.database_tier
    availability_type          = var.high_availability ? "REGIONAL" : "ZONAL"
    disk_type                  = "PD_SSD"
    disk_size                  = var.disk_size_gb
    disk_autoresize            = true
    disk_autoresize_limit      = var.max_disk_size_gb
    
    backup_configuration {
      enabled                        = var.enable_backup
      start_time                     = "03:00"
      location                       = var.backup_location
      point_in_time_recovery_enabled = var.enable_point_in_time_recovery
      backup_retention_settings {
        retained_backups = var.backup_retention_count
        retention_unit   = "COUNT"
      }
      transaction_log_retention_days = var.transaction_log_retention_days
    }

    maintenance_window {
      day          = 7  # Sunday
      hour         = 4  # 4 AM
      update_track = "stable"
    }

    database_flags {
      name  = "log_statement"
      value = "all"
    }

    database_flags {
      name  = "log_min_duration_statement"
      value = "1000"  # Log queries taking more than 1s
    }

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.network_id
      enable_private_path_for_google_cloud_services = true
    }

    insights_config {
      query_insights_enabled  = true
      record_application_tags = true
      record_client_address   = true
    }
  }

  deletion_protection = var.deletion_protection

  depends_on = [var.private_service_connection_id]
}

# Database
resource "google_sql_database" "openwebui" {
  name     = "openwebui"
  instance = google_sql_database_instance.postgres.name
  project  = var.project_id
}

# Database User
resource "google_sql_user" "openwebui" {
  name     = "openwebui"
  instance = google_sql_database_instance.postgres.name
  password = var.database_password
  project  = var.project_id
}

# Additional database for vector storage (if using pgvector)
resource "google_sql_database" "vector_db" {
  count    = var.enable_vector_db ? 1 : 0
  name     = "vector_db"
  instance = google_sql_database_instance.postgres.name
  project  = var.project_id
} 