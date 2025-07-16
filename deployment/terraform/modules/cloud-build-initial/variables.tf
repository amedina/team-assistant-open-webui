variable "project_id" {
  description = "The ID of the Google Cloud project."
  type        = string
}

variable "region" {
  description = "The Google Cloud region where the build will be executed."
  type        = string
}

variable "artifact_repository_url" {
  description = "The URL of the Artifact Registry repository."
  type        = string
}

variable "machine_type" {
  description = "The machine type to use for the build."
  type        = string
  default     = "E2_HIGHCPU_8"
}

variable "image_name" {
  description = "The name of the Docker image to be built."
  type        = string
  default     = "open-webui"
}

variable "environment" {
  description = "Environment name (staging, prod)"
  type        = string

  validation {
    condition     = contains(["staging", "prod", "dev"], var.environment)
    error_message = "Environment must be either 'staging' or 'prod'."
  }
}
