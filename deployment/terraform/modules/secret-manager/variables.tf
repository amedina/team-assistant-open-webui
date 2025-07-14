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

variable "backup_region" {
  description = "GCP backup region for multi-region replication"
  type        = string
  default     = "us-east1"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.backup_region))
    error_message = "Backup region must be a valid GCP region format (e.g., us-east1)."
  }
}

variable "services_ready" {
  description = "Indicates that required services are enabled"
  type        = bool
  default     = true
}

variable "cloud_run_service_account_email" {
  description = "Email address of the Cloud Run service account"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.cloud_run_service_account_email))
    error_message = "Cloud Run service account email must be a valid email address."
  }
}

variable "cloud_build_service_account_email" {
  description = "Email address of the Cloud Build service account"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.cloud_build_service_account_email))
    error_message = "Cloud Build service account email must be a valid email address."
  }
}

variable "developer_emails" {
  description = "List of developer email addresses for staging environment secret access"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for email in var.developer_emails : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "All developer emails must be valid email addresses."
  }
}

variable "enable_ssl_secret" {
  description = "Enable SSL certificate secrets for custom domain"
  type        = bool
  default     = false
}

variable "secret_replication_type" {
  description = "Type of replication for secrets (auto, user-managed)"
  type        = string
  default     = "auto"

  validation {
    condition     = contains(["auto", "user-managed"], var.secret_replication_type)
    error_message = "Secret replication type must be either 'auto' or 'user-managed'."
  }
} 
