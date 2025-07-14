variable "project_id" {
  description = "The GCP project ID where Open WebUI is deployed"
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

variable "agent_engine_secret_id" {
  description = "Secret Manager secret ID for storing Agent Engine resource ID"
  type        = string
}

variable "secrets_ready" {
  description = "Indicates that secrets are ready"
  type        = bool
  default     = true
}

variable "cloud_run_service_account_email" {
  description = "Email address of the Cloud Run service account that will access the Agent Engine"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.cloud_run_service_account_email))
    error_message = "Cloud Run service account email must be a valid email address."
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

variable "enable_agent_engine_monitoring" {
  description = "Enable monitoring dashboard for Agent Engine"
  type        = bool
  default     = true
}

variable "enable_agent_engine_health_check" {
  description = "Enable health check for Agent Engine configuration"
  type        = bool
  default     = true
}

variable "agent_engine_endpoint_id" {
  description = "Endpoint ID for the Agent Engine (if applicable)"
  type        = string
  default     = null
}

variable "agent_engine_model_id" {
  description = "Model ID for the Agent Engine (if applicable)"
  type        = string
  default     = null
}

variable "agent_engine_version" {
  description = "Version of the Agent Engine"
  type        = string
  default     = "latest"
}

variable "agent_engine_timeout_seconds" {
  description = "Timeout for Agent Engine requests in seconds"
  type        = number
  default     = 30

  validation {
    condition     = var.agent_engine_timeout_seconds >= 5 && var.agent_engine_timeout_seconds <= 300
    error_message = "Agent Engine timeout must be between 5 and 300 seconds."
  }
}

variable "agent_engine_retry_count" {
  description = "Number of retries for Agent Engine requests"
  type        = number
  default     = 3

  validation {
    condition     = var.agent_engine_retry_count >= 0 && var.agent_engine_retry_count <= 10
    error_message = "Agent Engine retry count must be between 0 and 10."
  }
}

variable "agent_engine_rate_limit" {
  description = "Rate limit for Agent Engine requests (requests per minute)"
  type        = number
  default     = 60

  validation {
    condition     = var.agent_engine_rate_limit >= 1 && var.agent_engine_rate_limit <= 1000
    error_message = "Agent Engine rate limit must be between 1 and 1000 requests per minute."
  }
}

variable "agent_engine_required_scopes" {
  description = "Required OAuth scopes for Agent Engine access"
  type        = list(string)
  default = [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/aiplatform"
  ]
}

variable "agent_engine_service_account_key_path" {
  description = "Path to service account key file for Agent Engine access (if using key-based auth)"
  type        = string
  default     = null
}

variable "agent_engine_network_config" {
  description = "Network configuration for Agent Engine access"
  type = object({
    use_private_ip     = bool
    vpc_connector_name = string
    allowed_ip_ranges  = list(string)
  })
  default = {
    use_private_ip     = true
    vpc_connector_name = ""
    allowed_ip_ranges  = []
  }
}

variable "agent_engine_labels" {
  description = "Labels to apply to Agent Engine resources"
  type        = map(string)
  default     = {}
}

variable "agent_engine_annotations" {
  description = "Annotations for Agent Engine configuration"
  type        = map(string)
  default     = {}
}

variable "enable_agent_engine_logging" {
  description = "Enable detailed logging for Agent Engine requests"
  type        = bool
  default     = true
}

variable "agent_engine_log_level" {
  description = "Log level for Agent Engine operations"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"], var.agent_engine_log_level)
    error_message = "Agent Engine log level must be one of: DEBUG, INFO, WARNING, ERROR, CRITICAL."
  }
} 
