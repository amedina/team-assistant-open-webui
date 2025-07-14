variable "environment" {
  description = "Environment name (staging, prod)"
  type        = string
  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "Environment must be either 'staging' or 'prod'."
  }
}

variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "Google Cloud region"
  type        = string
  default     = "us-central1"
}

variable "github_repo_owner" {
  description = "GitHub repository owner"
  type        = string
}

variable "github_repo_name" {
  description = "GitHub repository name"
  type        = string
}

variable "trigger_branch" {
  description = "Git branch to trigger builds on"
  type        = string
  default     = "main"
}

variable "artifact_registry_url" {
  description = "Artifact Registry URL for container images"
  type        = string
}

variable "cloud_run_service_account_email" {
  description = "Service account email for Cloud Run"
  type        = string
}

variable "vpc_connector_name" {
  description = "VPC connector name for Cloud Run"
  type        = string
}

variable "cloud_run_memory" {
  description = "Memory allocation for Cloud Run"
  type        = string
  default     = "2Gi"
}

variable "cloud_run_cpu" {
  description = "CPU allocation for Cloud Run"
  type        = string
  default     = "1"
}

variable "cloud_run_min_instances" {
  description = "Minimum number of Cloud Run instances"
  type        = number
  default     = 0
}

variable "cloud_run_max_instances" {
  description = "Maximum number of Cloud Run instances"
  type        = number
  default     = 10
}

variable "cloud_run_timeout" {
  description = "Cloud Run request timeout in seconds"
  type        = number
  default     = 300
}

variable "cloud_build_service_account_email" {
  description = "Service account email for Cloud Build"
  type        = string
}

variable "build_included_files" {
  description = "List of files to include in build triggers"
  type        = list(string)
  default     = []
}

variable "build_ignored_files" {
  description = "List of files to ignore in build triggers"
  type        = list(string)
  default     = [".gitignore", "README.md", "*.md"]
}

variable "services_ready" {
  description = "Dependency to ensure required services are enabled"
  type        = any
  default     = null
}

variable "artifact_registry_ready" {
  description = "Dependency to ensure artifact registry is ready"
  type        = any
  default     = null
}

variable "enable_build_notifications" {
  description = "Enable Cloud Build notifications"
  type        = bool
  default     = true
}

variable "enable_build_cleanup" {
  description = "Enable automatic cleanup of old builds"
  type        = bool
  default     = true
} 
