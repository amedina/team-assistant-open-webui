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
  description = "ID of the VPC network for private network access"
  type        = string
}

variable "private_service_connection_id" {
  description = "ID of the private service connection"
  type        = string
}

variable "redis_memory_size_gb" {
  description = "Memory size in GB for Redis instance"
  type        = number
  default     = 1

  validation {
    condition     = var.redis_memory_size_gb >= 1 && var.redis_memory_size_gb <= 300
    error_message = "Redis memory size must be between 1 and 300 GB."
  }
}

variable "redis_version" {
  description = "Redis version"
  type        = string
  default     = "REDIS_6_X"

  validation {
    condition     = contains(["REDIS_5_0", "REDIS_6_X", "REDIS_7_0"], var.redis_version)
    error_message = "Redis version must be one of: REDIS_5_0, REDIS_6_X, REDIS_7_0."
  }
}

variable "redis_location_id" {
  description = "Zone for Redis instance placement"
  type        = string
  default     = "us-central1-a"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+-[a-z]$", var.redis_location_id))
    error_message = "Redis location ID must be a valid GCP zone format (e.g., us-central1-a)."
  }
}

variable "redis_alternative_location_id" {
  description = "Alternative zone for Redis instance (high availability)"
  type        = string
  default     = "us-central1-b"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+-[a-z]$", var.redis_alternative_location_id))
    error_message = "Redis alternative location ID must be a valid GCP zone format (e.g., us-central1-b)."
  }
}

variable "redis_cmek_key" {
  description = "Customer managed encryption key for Redis"
  type        = string
  default     = null
}

variable "redis_url_secret_id" {
  description = "Secret Manager secret ID for Redis URL"
  type        = string
}

variable "create_sessions_redis" {
  description = "Create separate Redis instance for sessions"
  type        = bool
  default     = false
}

variable "sessions_redis_memory_size_gb" {
  description = "Memory size in GB for sessions Redis instance"
  type        = number
  default     = 1

  validation {
    condition     = var.sessions_redis_memory_size_gb >= 1 && var.sessions_redis_memory_size_gb <= 300
    error_message = "Sessions Redis memory size must be between 1 and 300 GB."
  }
}

variable "enable_monitoring" {
  description = "Enable monitoring and alerting for Redis"
  type        = bool
  default     = true
}

variable "notification_channels" {
  description = "List of notification channels for alerts"
  type        = list(string)
  default     = []
}

variable "redis_maintenance_day" {
  description = "Day of the week for Redis maintenance"
  type        = string
  default     = "SUNDAY"

  validation {
    condition = contains([
      "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"
    ], var.redis_maintenance_day)
    error_message = "Redis maintenance day must be a valid day of the week."
  }
}

variable "redis_maintenance_hour" {
  description = "Hour of the day for Redis maintenance (0-23)"
  type        = number
  default     = 4

  validation {
    condition     = var.redis_maintenance_hour >= 0 && var.redis_maintenance_hour <= 23
    error_message = "Redis maintenance hour must be between 0 and 23."
  }
}

variable "redis_maintenance_minute" {
  description = "Minute of the hour for Redis maintenance (0-59)"
  type        = number
  default     = 0

  validation {
    condition     = var.redis_maintenance_minute >= 0 && var.redis_maintenance_minute <= 59
    error_message = "Redis maintenance minute must be between 0 and 59."
  }
}

variable "redis_tier" {
  description = "Redis tier (BASIC or STANDARD_HA)"
  type        = string
  default     = "BASIC"

  validation {
    condition     = contains(["BASIC", "STANDARD_HA"], var.redis_tier)
    error_message = "Redis tier must be either 'BASIC' or 'STANDARD_HA'."
  }
}

variable "redis_auth_enabled" {
  description = "Enable authentication for Redis"
  type        = bool
  default     = true
}

variable "redis_transit_encryption_mode" {
  description = "Transit encryption mode for Redis"
  type        = string
  default     = "DISABLED"

  validation {
    condition     = contains(["DISABLED", "SERVER_AUTHENTICATION"], var.redis_transit_encryption_mode)
    error_message = "Redis transit encryption mode must be either 'DISABLED' or 'SERVER_AUTHENTICATION'."
  }
} 
