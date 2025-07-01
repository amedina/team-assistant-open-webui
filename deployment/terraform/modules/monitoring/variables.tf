variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "notification_email" {
  description = "Email address for monitoring notifications"
  type        = string
  default     = ""
}

variable "cloud_run_service_name" {
  description = "Cloud Run service name for monitoring"
  type        = string
}

variable "cloud_run_service_url" {
  description = "Cloud Run service URL for uptime checks"
  type        = string
  default     = ""
}

variable "database_instance_id" {
  description = "Database instance ID for monitoring"
  type        = string
}

variable "redis_instance_id" {
  description = "Redis instance ID for monitoring"
  type        = string
}

variable "enable_uptime_checks" {
  description = "Enable uptime monitoring checks"
  type        = bool
  default     = true
}

variable "enable_error_reporting" {
  description = "Enable error reporting"
  type        = bool
  default     = true
}

variable "enable_performance_monitoring" {
  description = "Enable performance monitoring"
  type        = bool
  default     = true
} 