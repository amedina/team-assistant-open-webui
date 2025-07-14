# Project Configuration
variable "project_id" {
  description = "The GCP project ID where resources will be created"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
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

variable "backup_region" {
  description = "GCP backup region for multi-region replication"
  type        = string
  default     = "us-east1"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.backup_region))
    error_message = "Backup region must be a valid GCP region format (e.g., us-east1)."
  }
}

# Developer Configuration
variable "developer_emails" {
  description = "List of developer email addresses for staging environment access"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for email in var.developer_emails : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "All developer emails must be valid email addresses."
  }
}

# OAuth Configuration
variable "oauth_client_id" {
  description = "Google OAuth client ID"
  type        = string

  validation {
    condition     = can(regex("^[0-9]+-[a-zA-Z0-9]+\\.apps\\.googleusercontent\\.com$", var.oauth_client_id))
    error_message = "OAuth client ID must be in format: 123456789-abcdef123456.apps.googleusercontent.com"
  }
}

variable "oauth_client_secret" {
  description = "Google OAuth client secret (sensitive)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.oauth_client_secret) >= 10
    error_message = "OAuth client secret must be at least 10 characters long."
  }
}

variable "oauth_redirect_uris" {
  description = "List of authorized redirect URIs for OAuth"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for uri in var.oauth_redirect_uris : can(regex("^https://", uri))
    ])
    error_message = "All redirect URIs must use HTTPS."
  }
}

variable "oauth_support_email" {
  description = "Support email for OAuth consent screen"
  type        = string
  default     = null

  validation {
    condition     = var.oauth_support_email == null || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.oauth_support_email))
    error_message = "Support email must be a valid email address."
  }
}

variable "oauth_developer_email" {
  description = "Developer email for OAuth consent screen"
  type        = string
  default     = null

  validation {
    condition     = var.oauth_developer_email == null || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.oauth_developer_email))
    error_message = "Developer email must be a valid email address."
  }
}

# Agent Engine Configuration
variable "agent_engine_project_id" {
  description = "The GCP project ID where the external Agent Engine is deployed"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.agent_engine_project_id))
    error_message = "Agent Engine project ID must be 6-30 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "agent_engine_location" {
  description = "Location of the external Agent Engine"
  type        = string
  default     = "us-central1"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.agent_engine_location))
    error_message = "Agent Engine location must be a valid GCP region format (e.g., us-central1)."
  }
}

variable "agent_engine_resource_name" {
  description = "Resource name/ID of the external Agent Engine"
  type        = string

  validation {
    condition     = length(var.agent_engine_resource_name) > 0
    error_message = "Agent Engine resource name cannot be empty."
  }
}

variable "agent_engine_custom_url" {
  description = "Custom URL for Agent Engine (for testing purposes)"
  type        = string
  default     = ""

  validation {
    condition     = var.agent_engine_custom_url == "" || can(regex("^https://", var.agent_engine_custom_url))
    error_message = "Agent Engine custom URL must be empty or use HTTPS."
  }
}

# Cloud Run Configuration
variable "cloud_run_cpu" {
  description = "CPU limit for Cloud Run service"
  type        = string
  default     = "2000m"

  validation {
    condition     = can(regex("^[0-9]+m?$", var.cloud_run_cpu))
    error_message = "CPU limit must be a valid format (e.g., 2000m or 2)."
  }
}

variable "cloud_run_memory" {
  description = "Memory limit for Cloud Run service"
  type        = string
  default     = "4096Mi"

  validation {
    condition     = can(regex("^[0-9]+[KMG]i?$", var.cloud_run_memory))
    error_message = "Memory limit must be a valid format (e.g., 4096Mi or 4Gi)."
  }
}

# Database Configuration
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

# Redis Configuration
variable "redis_memory_size_gb" {
  description = "Memory size in GB for Redis instance"
  type        = number
  default     = 1

  validation {
    condition     = var.redis_memory_size_gb >= 1 && var.redis_memory_size_gb <= 300
    error_message = "Redis memory size must be between 1 and 300 GB."
  }
}

# GitHub Configuration
variable "github_connection_id" {
  description = "GitHub connection ID for Cloud Build"
  type        = string
  default     = null
}

variable "github_repo_owner" {
  description = "GitHub repository owner"
  type        = string
  default     = null
}

variable "github_repo_name" {
  description = "GitHub repository name"
  type        = string
  default     = null
}

# Optional Configuration
variable "custom_domain" {
  description = "Custom domain for the Cloud Run service"
  type        = string
  default     = null
}

variable "enable_monitoring" {
  description = "Enable monitoring and alerting"
  type        = bool
  default     = true
}

variable "enable_logging" {
  description = "Enable detailed logging"
  type        = bool
  default     = true
}

variable "notification_channels" {
  description = "List of notification channels for alerts"
  type        = list(string)
  default     = []
}

variable "additional_labels" {
  description = "Additional labels to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "force_destroy" {
  description = "Allow destruction of resources with data (use with caution)"
  type        = bool
  default     = false
}

variable "environment" {
  description = "Deployment environment (e.g., staging, prod)"
  type        = string
  default     = "staging"
}
