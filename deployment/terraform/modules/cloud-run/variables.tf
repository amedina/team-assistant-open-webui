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

variable "container_image_url" {
  description = "URL of the container image to deploy"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+-docker\\.pkg\\.dev/", var.container_image_url))
    error_message = "Container image URL must be a valid Artifact Registry URL."
  }
}

variable "cloud_run_service_account_email" {
  description = "Email address of the Cloud Run service account"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.cloud_run_service_account_email))
    error_message = "Cloud Run service account email must be a valid email address."
  }
}

variable "vpc_connector_name" {
  description = "Name of the VPC Connector for private access"
  type        = string
}

variable "cpu_limit" {
  description = "CPU limit for Cloud Run service"
  type        = string
  default     = "2000m"

  validation {
    condition     = can(regex("^[0-9]+m?$", var.cpu_limit))
    error_message = "CPU limit must be a valid format (e.g., 2000m or 2)."
  }
}

variable "memory_limit" {
  description = "Memory limit for Cloud Run service"
  type        = string
  default     = "4096Mi"

  validation {
    condition     = can(regex("^[0-9]+[KMG]i?$", var.memory_limit))
    error_message = "Memory limit must be a valid format (e.g., 4096Mi or 4Gi)."
  }
}

variable "min_instances" {
  description = "Minimum number of instances"
  type        = number
  default     = 1

  validation {
    condition     = var.min_instances >= 0 && var.min_instances <= 1000
    error_message = "Minimum instances must be between 0 and 1000."
  }
}

variable "max_instances" {
  description = "Maximum number of instances"
  type        = number
  default     = 10

  validation {
    condition     = var.max_instances >= 1 && var.max_instances <= 1000
    error_message = "Maximum instances must be between 1 and 1000."
  }
}

variable "webui_secret_key_secret_id" {
  description = "Secret Manager secret ID for WebUI secret key"
  type        = string
}

variable "database_url_secret_id" {
  description = "Secret Manager secret ID for database URL"
  type        = string
}

variable "redis_url_secret_id" {
  description = "Secret Manager secret ID for Redis URL"
  type        = string
}

variable "oauth_client_id" {
  description = "Google OAuth client ID"
  type        = string
}

variable "oauth_client_secret_secret_id" {
  description = "Secret Manager secret ID for OAuth client secret"
  type        = string
}

variable "agent_engine_secret_id" {
  description = "Secret Manager secret ID for agent engine resource ID"
  type        = string
  default = ""
}

variable "storage_bucket_name" {
  description = "Name of the storage bucket for Open WebUI data"
  type        = string
}

variable "custom_domain" {
  description = "Custom domain for the Cloud Run service"
  type        = string
  default     = null
}

variable "services_ready" {
  description = "Indicates that required services are enabled"
  type        = bool
  default     = true
}

variable "networking_ready" {
  description = "Indicates that networking resources are ready"
  type        = bool
  default     = true
}

variable "secrets_ready" {
  description = "Indicates that secrets are ready"
  type        = bool
  default     = true
}

variable "storage_ready" {
  description = "Indicates that storage resources are ready"
  type        = bool
  default     = true
}

variable "database_ready" {
  description = "Indicates that database resources are ready"
  type        = bool
  default     = true
}

variable "redis_ready" {
  description = "Indicates that Redis resources are ready"
  type        = bool
  default     = true
}

variable "artifact_registry_ready" {
  description = "Indicates that Artifact Registry resources are ready"
  type        = bool
  default     = true
}

variable "health_check_path" {
  description = "Path for health check endpoint"
  type        = string
  default     = "/health"
}

variable "startup_timeout_seconds" {
  description = "Timeout for startup probe"
  type        = number
  default     = 240

  validation {
    condition     = var.startup_timeout_seconds >= 30 && var.startup_timeout_seconds <= 3600
    error_message = "Startup timeout must be between 30 and 3600 seconds."
  }
}

variable "request_timeout_seconds" {
  description = "Request timeout for Cloud Run service"
  type        = number
  default     = 240

  validation {
    condition     = var.request_timeout_seconds >= 30 && var.request_timeout_seconds <= 3600
    error_message = "Request timeout must be between 30 and 3600 seconds."
  }
}

variable "enable_public_access" {
  description = "Enable public access to the Cloud Run service"
  type        = bool
  default     = true
}

variable "ingress" {
  description = "Ingress settings for Cloud Run service"
  type        = string
  default     = "INGRESS_TRAFFIC_ALL"

  validation {
    condition = contains([
      "INGRESS_TRAFFIC_ALL",
      "INGRESS_TRAFFIC_INTERNAL_ONLY",
      "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
    ], var.ingress)
    error_message = "Ingress must be one of: INGRESS_TRAFFIC_ALL, INGRESS_TRAFFIC_INTERNAL_ONLY, INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER."
  }
}

variable "execution_environment" {
  description = "Execution environment for Cloud Run service"
  type        = string
  default     = "EXECUTION_ENVIRONMENT_GEN2"

  validation {
    condition = contains([
      "EXECUTION_ENVIRONMENT_GEN1",
      "EXECUTION_ENVIRONMENT_GEN2"
    ], var.execution_environment)
    error_message = "Execution environment must be either GEN1 or GEN2."
  }
}

variable "additional_env_vars" {
  description = "Additional environment variables for the service"
  type        = map(string)
  default     = {}
}

variable "port" {
  description = "Port for the Cloud Run service"
  type        = number
  default     = 8080

  validation {
    condition     = var.port >= 1 && var.port <= 65535
    error_message = "Port must be between 1 and 65535."
  }
} 
