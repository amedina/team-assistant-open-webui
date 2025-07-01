variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "storage_bucket_name" {
  description = "Name of the storage bucket for IAM permissions"
  type        = string
  default     = ""
} 