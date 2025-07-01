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

variable "database_version" {
  description = "PostgreSQL database version"
  type        = string
  default     = "POSTGRES_15"
}

variable "database_tier" {
  description = "Database instance tier"
  type        = string
  default     = "db-g1-small"
}

variable "disk_size_gb" {
  description = "Database disk size in GB"
  type        = number
  default     = 20
}

variable "max_disk_size_gb" {
  description = "Maximum database disk size in GB"
  type        = number
  default     = 100
}

variable "database_password" {
  description = "Password for the database user"
  type        = string
  sensitive   = true
}

variable "network_id" {
  description = "VPC network ID for private IP"
  type        = string
}

variable "private_service_connection_id" {
  description = "Private service connection dependency"
  type        = string
}

variable "high_availability" {
  description = "Enable high availability (regional)"
  type        = bool
  default     = false
}

variable "enable_backup" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

variable "backup_location" {
  description = "Backup location"
  type        = string
  default     = "us"
}

variable "backup_retention_count" {
  description = "Number of backups to retain"
  type        = number
  default     = 7
}

variable "transaction_log_retention_days" {
  description = "Transaction log retention in days"
  type        = number
  default     = 7
}

variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "enable_vector_db" {
  description = "Create additional database for vector storage"
  type        = bool
  default     = false
} 