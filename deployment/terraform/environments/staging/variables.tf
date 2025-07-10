variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "Google Cloud region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Google Cloud zone"
  type        = string
  default     = "us-central1-a"
}

# Storage Configuration
variable "storage_bucket_name" {
  description = "Name of the Cloud Storage bucket"
  type        = string
}

# Database Configuration (Staging sizing - between dev and prod)
variable "database_tier" {
  description = "Cloud SQL instance tier"
  type        = string
  default     = "db-g1-small"  # Production-like tier for staging
}

variable "database_disk_size" {
  description = "Database disk size in GB"
  type        = number
  default     = 20  # Moderate size for staging
}

# Redis Configuration (Staging sizing)
variable "redis_memory_size_gb" {
  description = "Redis memory size in GB"
  type        = number
  default     = 2  # Moderate memory for staging
}

variable "redis_tier" {
  description = "Redis service tier"
  type        = string
  default     = "STANDARD_HA"  # Test HA features in staging
}

# Networking Configuration
variable "vpc_connector_cidr" {
  description = "CIDR range for VPC connector subnet"
  type        = string
  default     = "10.18.0.0/28"  # Different CIDR for staging
}

variable "database_subnet_cidr" {
  description = "CIDR range for database subnet"
  type        = string
  default     = "10.19.0.0/24"  # Different CIDR for staging
}

variable "vpc_connector_min_instances" {
  description = "Minimum instances for VPC connector"
  type        = number
  default     = 2
}

variable "vpc_connector_max_instances" {
  description = "Maximum instances for VPC connector"
  type        = number
  default     = 3  # Moderate scaling for staging
}

# Cloud Run Configuration (Staging sizing)
variable "cloud_run_service_name" {
  description = "Name of the Cloud Run service"
  type        = string
  default     = "open-webui"
}

variable "cloud_run_cpu_limit" {
  description = "CPU limit for Cloud Run instances"
  type        = string
  default     = "2"  # Moderate CPU for staging
}

variable "cloud_run_memory_limit" {
  description = "Memory limit for Cloud Run instances"
  type        = string
  default     = "4Gi"  # Moderate memory for staging
}

variable "cloud_run_min_instances" {
  description = "Minimum number of Cloud Run instances"
  type        = number
  default     = 1  # Keep one instance warm in staging
}

variable "cloud_run_max_instances" {
  description = "Maximum number of Cloud Run instances"
  type        = number
  default     = 5  # Moderate scaling for staging
}

variable "uvicorn_workers" {
  description = "Number of Uvicorn workers"
  type        = string
  default     = "2"  # Multiple workers for staging
}

# Artifact Registry
variable "artifact_repository_name" {
  description = "Name of the Artifact Registry repository"
  type        = string
  default     = "open-webui"
}

# Source Code
variable "repository_url" {
  description = "Git repository URL for the application code"
  type        = string
}

variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

# OAuth Configuration
variable "google_oauth_client_id" {
  description = "Google OAuth client ID"
  type        = string
  sensitive   = true
}

variable "google_oauth_client_secret" {
  description = "Google OAuth client secret"
  type        = string
  sensitive   = true
}

# Notification Configuration
variable "notification_email" {
  description = "Email address for monitoring notifications"
  type        = string
  default     = ""
}

# Feature Flags
variable "enable_monitoring" {
  description = "Enable monitoring and alerting"
  type        = bool
  default     = true  # Enable monitoring in staging to test alerts
}

# Labels
variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default = {
    application = "open-webui"
    environment = "staging"
    managed-by  = "terraform"
  }
} 