terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
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

# Generate a random password for the database
resource "random_password" "db_password" {
  length  = 32
  special = true

  # Ensure password meets PostgreSQL requirements
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
}

# Cloud SQL PostgreSQL instance
resource "google_sql_database_instance" "postgresql" {
  name                = "${var.environment}-open-webui-postgresql"
  database_version    = "POSTGRES_15"
  project             = var.project_id
  region              = var.region
  deletion_protection = var.environment == "prod" ? true : false

  settings {
    tier                  = var.database_tier
    availability_type     = var.environment == "prod" ? "REGIONAL" : "ZONAL"
    disk_type             = "PD_SSD"
    disk_size             = var.database_disk_size
    disk_autoresize       = true
    disk_autoresize_limit = var.database_disk_size * 2

    # Enable automatic backups
    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      location                       = var.region
      point_in_time_recovery_enabled = var.environment == "prod" ? true : false
      transaction_log_retention_days = var.environment == "prod" ? 7 : 3
      backup_retention_settings {
        retained_backups = var.environment == "prod" ? 30 : 7
        retention_unit   = "COUNT"
      }
    }

    # IP configuration - Private IP only
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.vpc_network_id
      enable_private_path_for_google_cloud_services = true

      # No authorized networks for private IP since we're using private networking
    }

    # Maintenance window
    maintenance_window {
      day          = 7 # Sunday
      hour         = 4 # 4 AM
      update_track = "stable"
    }

    # Insights configuration
    insights_config {
      query_insights_enabled  = true
      record_application_tags = true
      record_client_address   = true
    }

    # User labels
    user_labels = local.common_labels
  }

  depends_on = [
    var.services_ready,
    var.private_service_connection_id
  ]
}

# Create database user
resource "google_sql_user" "app_user" {
  name     = var.database_username
  instance = google_sql_database_instance.postgresql.name
  password = random_password.db_password.result
  project  = var.project_id
}

# Create application database
resource "google_sql_database" "app_database" {
  name     = var.database_name
  instance = google_sql_database_instance.postgresql.name
  project  = var.project_id

  # UTF-8 encoding for internationalization
  charset   = "UTF8"
  collation = "en_US.UTF8"
}

# SSL Certificate for the database
resource "google_sql_ssl_cert" "client_cert" {
  common_name = "${var.environment}-open-webui-client-cert"
  instance    = google_sql_database_instance.postgresql.name
  project     = var.project_id
}

# Store database password in Secret Manager
resource "google_secret_manager_secret_version" "db_password" {
  secret      = var.database_password_secret_id
  secret_data = random_password.db_password.result

  depends_on = [google_sql_database_instance.postgresql]
}

# Create database URL and store in Secret Manager
locals {
  database_url = "postgresql://${google_sql_user.app_user.name}:${random_password.db_password.result}@${google_sql_database_instance.postgresql.private_ip_address}:5432/${google_sql_database.app_database.name}?sslmode=require"
}

resource "google_secret_manager_secret_version" "database_url" {
  secret      = var.database_url_secret_id
  secret_data = local.database_url

  depends_on = [
    google_sql_database_instance.postgresql,
    google_sql_database.app_database,
    google_sql_user.app_user
  ]
}

# Create read replica for production
resource "google_sql_database_instance" "read_replica" {
  count = var.environment == "prod" && var.enable_read_replica ? 1 : 0

  name                 = "${var.environment}-open-webui-postgresql-replica"
  database_version     = "POSTGRES_15"
  project              = var.project_id
  region               = var.replica_region
  master_instance_name = google_sql_database_instance.postgresql.name

  replica_configuration {
    failover_target = false
  }

  settings {
    tier              = var.replica_tier
    availability_type = "ZONAL"
    disk_type         = "PD_SSD"
    disk_size         = var.database_disk_size
    disk_autoresize   = true

    # IP configuration - same as master
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.vpc_network_id
      enable_private_path_for_google_cloud_services = true
    }

    # User labels
    user_labels = merge(local.common_labels, {
      replica = "true"
    })
  }

  depends_on = [
    google_sql_database_instance.postgresql,
    var.private_service_connection_id
  ]
}

# Create additional databases for different purposes
resource "google_sql_database" "sessions_database" {
  count = var.create_sessions_database ? 1 : 0

  name     = "${var.database_name}_sessions"
  instance = google_sql_database_instance.postgresql.name
  project  = var.project_id

  charset   = "UTF8"
  collation = "en_US.UTF8"
}

resource "google_sql_database" "analytics_database" {
  count = var.create_analytics_database && var.environment == "prod" ? 1 : 0

  name     = "${var.database_name}_analytics"
  instance = google_sql_database_instance.postgresql.name
  project  = var.project_id

  charset   = "UTF8"
  collation = "en_US.UTF8"
}
