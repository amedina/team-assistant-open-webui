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

variable "service_name" {
  description = "Name of the Cloud Run service"
  type        = string
}

variable "container_image" {
  description = "Container image URL"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 8080
}

variable "service_account_email" {
  description = "Service account email for the Cloud Run service"
  type        = string
}

variable "environment_variables" {
  description = "Environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "cpu_limit" {
  description = "CPU limit for the container"
  type        = string
  default     = "1"
}

variable "memory_limit" {
  description = "Memory limit for the container"
  type        = string
  default     = "2Gi"
}

variable "min_instances" {
  description = "Minimum number of instances"
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum number of instances"
  type        = number
  default     = 10
}

variable "container_concurrency" {
  description = "Maximum number of concurrent requests per container"
  type        = number
  default     = 80
}

variable "timeout_seconds" {
  description = "Timeout for requests in seconds"
  type        = number
  default     = 300
}

variable "vpc_connector_name" {
  description = "VPC connector name for private network access"
  type        = string
  default     = ""
}

variable "cloudsql_instances" {
  description = "Cloud SQL instances to connect to"
  type        = string
  default     = ""
}

variable "allow_public_access" {
  description = "Allow public access to the service"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels to apply to the Cloud Run service"
  type        = map(string)
  default     = {}
}

variable "storage_bucket_name" {
  description = "Name of the GCS bucket for persistent storage volumes"
  type        = string
}

variable "artifact_repository_name" {
  description = "Name of the Artifact Registry repository"
  type        = string
}

variable "artifact_repository_url" {
  description = "URL of the Artifact Registry repository"
  type        = string
}