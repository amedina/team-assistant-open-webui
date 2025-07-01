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

# Database Configuration (Production sizing)
variable "database_tier" {
  description = "Cloud SQL instance tier"
  type        = string
  default     = "db-g1-small"  # Production tier
}

variable "database_disk_size" {
  description = "Database disk size in GB"
  type        = number
  default     = 50  # Larger disk for production
}

variable "database_max_disk_size" {
  description = "Maximum database disk size in GB"
  type        = number
  default     = 500  # Allow growth in production
}

variable "enable_high_availability" {
  description = "Enable database high availability"
  type        = bool
  default     = true  # Enable HA in production
}

# Redis Configuration (Production sizing)
variable "redis_memory_size_gb" {
  description = "Redis memory size in GB"
  type        = number
  default     = 4  # Larger memory for production
}

variable "redis_tier" {
  description = "Redis service tier"
  type        = string
  default     = "STANDARD_HA"  # High availability for production
}

# Networking Configuration
variable "vpc_connector_cidr" {
  description = "CIDR range for VPC connector subnet"
  type        = string
  default     = "10.8.0.0/28"
}

variable "database_subnet_cidr" {
  description = "CIDR range for database subnet"
  type        = string
  default     = "10.9.0.0/24"
}

variable "vpc_connector_min_instances" {
  description = "Minimum instances for VPC connector"
  type        = number
  default     = 3  # Higher minimum for production
}

variable "vpc_connector_max_instances" {
  description = "Maximum instances for VPC connector"
  type        = number
  default     = 10  # Higher maximum for production
}

# Cloud Run Configuration (Production sizing)
variable "cloud_run_service_name" {
  description = "Name of the Cloud Run service"
  type        = string
  default     = "open-webui"
}

variable "cloud_run_cpu_limit" {
  description = "CPU limit for Cloud Run instances"
  type        = string
  default     = "4"  # Higher CPU for production
}

variable "cloud_run_memory_limit" {
  description = "Memory limit for Cloud Run instances"
  type        = string
  default     = "8Gi"  # Higher memory for production
}

variable "cloud_run_min_instances" {
  description = "Minimum number of Cloud Run instances"
  type        = number
  default     = 2  # Always keep instances warm in production
}

variable "cloud_run_max_instances" {
  description = "Maximum number of Cloud Run instances"
  type        = number
  default     = 20  # Higher scaling for production
}

variable "container_concurrency" {
  description = "Maximum number of concurrent requests per container"
  type        = number
  default     = 100  # Higher concurrency for production
}

variable "timeout_seconds" {
  description = "Timeout for requests in seconds"
  type        = number
  default     = 900  # Longer timeout for production
}

variable "uvicorn_workers" {
  description = "Number of Uvicorn workers"
  type        = string
  default     = "4"  # Multiple workers for production
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

# Application Configuration
variable "webui_name" {
  description = "Name of the WebUI application"
  type        = string
  default     = "Open WebUI"
}

variable "custom_domain" {
  description = "Custom domain for the application"
  type        = string
  default     = ""
}

# Notification Configuration
variable "notification_email" {
  description = "Email address for monitoring notifications"
  type        = string
}

# Backup Configuration
variable "enable_backup" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30  # Longer retention for production
}

# Labels
variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default = {
    application = "open-webui"
    environment = "production"
    managed-by  = "terraform"
  }
} 