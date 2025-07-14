variable "project_id" {
  description = "The GCP project ID where resources will be created"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (staging, prod)"
  type        = string

  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "Environment must be either 'staging' or 'prod'."
  }
}

variable "region" {
  description = "GCP region for regional resources"
  type        = string
  default     = "us-central1"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.region))
    error_message = "Region must be a valid GCP region format (e.g., us-central1)."
  }
}

variable "services_ready" {
  description = "Indicates that required services are enabled"
  type        = bool
  default     = true
}

variable "vpc_network_id" {
  description = "ID of the VPC network for private IP"
  type        = string
}

variable "private_service_connection_id" {
  description = "ID of the private service connection"
  type        = string
}

variable "database_tier" {
  description = "Database tier for Cloud SQL instance"
  type        = string
  default     = "db-f1-micro"

  validation {
    condition = contains([
      "db-f1-micro", "db-g1-small", "db-n1-standard-1", "db-n1-standard-2",
      "db-n1-standard-4", "db-n1-standard-8", "db-n1-standard-16",
      "db-n1-standard-32", "db-n1-standard-64", "db-n1-standard-96",
      "db-custom-1-3840", "db-custom-2-7680", "db-custom-4-15360"
    ], var.database_tier)
    error_message = "Database tier must be a valid Cloud SQL tier."
  }
}

variable "database_disk_size" {
  description = "Disk size in GB for the database"
  type        = number
  default     = 20

  validation {
    condition     = var.database_disk_size >= 10 && var.database_disk_size <= 64000
    error_message = "Database disk size must be between 10 and 64000 GB."
  }
}

variable "database_name" {
  description = "Name of the application database"
  type        = string
  default     = "open_webui"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{2,62}$", var.database_name))
    error_message = "Database name must be 3-63 characters, start with a letter, and contain only lowercase letters, numbers, and underscores."
  }
}

variable "database_username" {
  description = "Username for the database user"
  type        = string
  default     = "open_webui_user"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{2,62}$", var.database_username))
    error_message = "Database username must be 3-63 characters, start with a letter, and contain only lowercase letters, numbers, and underscores."
  }
}

variable "database_password_secret_id" {
  description = "Secret Manager secret ID for database password"
  type        = string
}

variable "database_url_secret_id" {
  description = "Secret Manager secret ID for database URL"
  type        = string
}

variable "max_connections" {
  description = "Maximum number of connections to the database"
  type        = string
  default     = "100"

  validation {
    condition     = can(regex("^[0-9]+$", var.max_connections))
    error_message = "Max connections must be a numeric string."
  }
}

variable "enable_read_replica" {
  description = "Enable read replica for production"
  type        = bool
  default     = false
}

variable "replica_region" {
  description = "Region for read replica"
  type        = string
  default     = "us-east1"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.replica_region))
    error_message = "Replica region must be a valid GCP region format (e.g., us-east1)."
  }
}

variable "replica_tier" {
  description = "Database tier for read replica"
  type        = string
  default     = "db-f1-micro"

  validation {
    condition = contains([
      "db-f1-micro", "db-g1-small", "db-n1-standard-1", "db-n1-standard-2",
      "db-n1-standard-4", "db-n1-standard-8", "db-n1-standard-16",
      "db-n1-standard-32", "db-n1-standard-64", "db-n1-standard-96",
      "db-custom-1-3840", "db-custom-2-7680", "db-custom-4-15360"
    ], var.replica_tier)
    error_message = "Replica tier must be a valid Cloud SQL tier."
  }
}

variable "create_sessions_database" {
  description = "Create separate database for sessions"
  type        = bool
  default     = false
}

variable "create_analytics_database" {
  description = "Create separate database for analytics"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 365
    error_message = "Backup retention days must be between 1 and 365."
  }
}

variable "maintenance_window_day" {
  description = "Day of the week for maintenance window (1-7, Sunday = 7)"
  type        = number
  default     = 7

  validation {
    condition     = var.maintenance_window_day >= 1 && var.maintenance_window_day <= 7
    error_message = "Maintenance window day must be between 1 and 7."
  }
}

variable "maintenance_window_hour" {
  description = "Hour of the day for maintenance window (0-23)"
  type        = number
  default     = 4

  validation {
    condition     = var.maintenance_window_hour >= 0 && var.maintenance_window_hour <= 23
    error_message = "Maintenance window hour must be between 0 and 23."
  }
} 
