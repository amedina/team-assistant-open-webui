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

variable "cloud_build_service_account_email" {
  description = "Email address of the Cloud Build service account"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.cloud_build_service_account_email))
    error_message = "Cloud Build service account email must be a valid email address."
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

variable "image_retention_days" {
  description = "Number of days to retain container images"
  type        = number
  default     = 30

  validation {
    condition     = var.image_retention_days >= 1 && var.image_retention_days <= 365
    error_message = "Image retention days must be between 1 and 365."
  }
}

variable "keep_recent_versions" {
  description = "Number of recent image versions to keep"
  type        = number
  default     = 10

  validation {
    condition     = var.keep_recent_versions >= 1 && var.keep_recent_versions <= 100
    error_message = "Keep recent versions must be between 1 and 100."
  }
}

variable "untagged_retention_days" {
  description = "Number of days to retain untagged images"
  type        = number
  default     = 7

  validation {
    condition     = var.untagged_retention_days >= 1 && var.untagged_retention_days <= 90
    error_message = "Untagged retention days must be between 1 and 90."
  }
}

variable "create_base_images_repo" {
  description = "Create separate repository for base images"
  type        = bool
  default     = false
}

variable "base_image_retention_days" {
  description = "Number of days to retain base images"
  type        = number
  default     = 90

  validation {
    condition     = var.base_image_retention_days >= 1 && var.base_image_retention_days <= 365
    error_message = "Base image retention days must be between 1 and 365."
  }
}

variable "keep_base_image_versions" {
  description = "Number of recent base image versions to keep"
  type        = number
  default     = 5

  validation {
    condition     = var.keep_base_image_versions >= 1 && var.keep_base_image_versions <= 50
    error_message = "Keep base image versions must be between 1 and 50."
  }
}

variable "enable_image_notifications" {
  description = "Enable Pub/Sub notifications for image events"
  type        = bool
  default     = false
}

variable "enable_image_scanning_webhook" {
  description = "Enable webhook for image scanning results"
  type        = bool
  default     = false
}

variable "repository_format" {
  description = "Format of the Artifact Registry repository"
  type        = string
  default     = "DOCKER"

  validation {
    condition     = contains(["DOCKER", "MAVEN", "NPM", "PYTHON", "APT", "YUM"], var.repository_format)
    error_message = "Repository format must be one of: DOCKER, MAVEN, NPM, PYTHON, APT, YUM."
  }
}

variable "immutable_tags" {
  description = "Enable immutable tags for production"
  type        = bool
  default     = null
}

variable "cleanup_policy_dry_run" {
  description = "Enable dry run mode for cleanup policies"
  type        = bool
  default     = false
}

variable "enable_vulnerability_scanning" {
  description = "Enable vulnerability scanning for images"
  type        = bool
  default     = false
}

variable "scanning_policy" {
  description = "Configuration for vulnerability scanning"
  type = object({
    enabled               = bool
    severity_levels       = list(string)
    max_fixes_per_version = number
  })
  default = {
    enabled               = false
    severity_levels       = ["HIGH", "CRITICAL"]
    max_fixes_per_version = 100
  }
}

variable "repository_description" {
  description = "Description for the Artifact Registry repository"
  type        = string
  default     = null
}

variable "kms_key_name" {
  description = "KMS key name for encryption"
  type        = string
  default     = null
}

variable "docker_config_immutable_tags" {
  description = "Enable immutable tags in Docker configuration"
  type        = bool
  default     = null
} 
