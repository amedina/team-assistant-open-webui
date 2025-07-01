variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "Google Cloud region"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "repository_url" {
  description = "Git repository URL"
  type        = string
}

variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = ""
}

variable "trigger_branch" {
  description = "Git branch to trigger builds"
  type        = string
  default     = "main"
}

variable "artifact_registry_url" {
  description = "Artifact Registry repository URL"
  type        = string
}

variable "service_account_email" {
  description = "Service account email for Cloud Build"
  type        = string
}

variable "cloud_run_service_name" {
  description = "Cloud Run service name for deployment"
  type        = string
  default     = "open-webui"
}

variable "auto_deploy" {
  description = "Automatically deploy after successful build"
  type        = bool
  default     = false
}

variable "build_machine_type" {
  description = "Machine type for Cloud Build"
  type        = string
  default     = "E2_HIGHCPU_8"
}

variable "build_timeout_seconds" {
  description = "Build timeout in seconds"
  type        = number
  default     = 1200  # 20 minutes
}

variable "included_files" {
  description = "Files to include in the build trigger"
  type        = list(string)
  default     = ["**"]
}

variable "ignored_files" {
  description = "Files to ignore in the build trigger"
  type        = list(string)
  default     = [
    "README.md",
    "docs/**",
    "terraform/**",
    ".gitignore"
  ]
}

variable "enable_release_trigger" {
  description = "Enable release trigger for tagged builds"
  type        = bool
  default     = true
}

variable "release_tag_pattern" {
  description = "Tag pattern for release builds"
  type        = string
  default     = "v*"
} 