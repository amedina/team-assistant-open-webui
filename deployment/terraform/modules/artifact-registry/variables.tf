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

variable "repository_id" {
  description = "Artifact Registry repository ID"
  type        = string
}

variable "labels" {
  description = "Labels to apply to the repository"
  type        = map(string)
  default     = {}
}

variable "keep_image_versions" {
  description = "Number of image versions to keep"
  type        = number
  default     = 10
}

variable "cloud_build_service_account" {
  description = "Cloud Build service account email for push access"
  type        = string
  default     = ""
}

variable "cloud_run_service_account" {
  description = "Cloud Run service account email for pull access"
  type        = string
  default     = ""
} 