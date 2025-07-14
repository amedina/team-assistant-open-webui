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

variable "vpc_connector_min_throughput" {
  description = "Minimum throughput for VPC Connector"
  type        = number
  default     = 200

  validation {
    condition     = var.vpc_connector_min_throughput >= 200 && var.vpc_connector_min_throughput <= 1000
    error_message = "VPC Connector minimum throughput must be between 200 and 1000."
  }
}

variable "vpc_connector_max_throughput" {
  description = "Maximum throughput for VPC Connector (environment-specific)"
  type        = number
  default     = 300

  validation {
    condition     = var.vpc_connector_max_throughput >= 200 && var.vpc_connector_max_throughput <= 1000
    error_message = "VPC Connector maximum throughput must be between 200 and 1000."
  }
} 
