variable "project_id" {
  description = "The GCP project ID where resources will be created"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (staging, prod)"
  type        = string

  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "Environment must be either 'staging' or 'prod'."
  }
}

variable "oauth_client_id" {
  description = "Google OAuth client ID"
  type        = string

  validation {
    condition     = can(regex("^[0-9]+-[a-zA-Z0-9]+\\.apps\\.googleusercontent\\.com$", var.oauth_client_id))
    error_message = "OAuth client ID must be in format: 123456789-abcdef123456.apps.googleusercontent.com"
  }
}

variable "oauth_client_secret_value" {
  description = "Google OAuth client secret value"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.oauth_client_secret_value) >= 10
    error_message = "OAuth client secret must be at least 10 characters long."
  }
}

variable "oauth_client_secret_secret_id" {
  description = "Secret Manager secret ID for OAuth client secret"
  type        = string
}

variable "secrets_ready" {
  description = "Indicates that secrets are ready"
  type        = bool
  default     = true
}

variable "redirect_uris" {
  description = "List of authorized redirect URIs for OAuth"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for uri in var.redirect_uris : can(regex("^https://", uri))
    ])
    error_message = "All redirect URIs must use HTTPS."
  }
}

variable "application_domain" {
  description = "Application domain for OAuth consent screen"
  type        = string
  default     = null
}

variable "support_email" {
  description = "Support email for OAuth consent screen"
  type        = string
  default     = null

  validation {
    condition     = var.support_email == null || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.support_email))
    error_message = "Support email must be a valid email address."
  }
}

variable "developer_email" {
  description = "Developer email for OAuth consent screen"
  type        = string
  default     = null

  validation {
    condition     = var.developer_email == null || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.developer_email))
    error_message = "Developer email must be a valid email address."
  }
}

variable "privacy_policy_url" {
  description = "Privacy policy URL for OAuth consent screen"
  type        = string
  default     = null

  validation {
    condition     = var.privacy_policy_url == null || can(regex("^https://", var.privacy_policy_url))
    error_message = "Privacy policy URL must use HTTPS."
  }
}

variable "terms_of_service_url" {
  description = "Terms of service URL for OAuth consent screen"
  type        = string
  default     = null

  validation {
    condition     = var.terms_of_service_url == null || can(regex("^https://", var.terms_of_service_url))
    error_message = "Terms of service URL must use HTTPS."
  }
}

variable "enable_oauth_monitoring" {
  description = "Enable OAuth monitoring dashboard"
  type        = bool
  default     = false
}

variable "enable_oauth_health_check" {
  description = "Enable OAuth health check"
  type        = bool
  default     = true
}

variable "oauth_scopes" {
  description = "OAuth scopes required by the application"
  type        = list(string)
  default     = ["openid", "email", "profile"]

  validation {
    condition = alltrue([
      for scope in var.oauth_scopes : contains(["openid", "email", "profile"], scope)
    ])
    error_message = "OAuth scopes must be one of: openid, email, profile."
  }
}

variable "oauth_brand_id" {
  description = "OAuth brand ID (for programmatic configuration)"
  type        = string
  default     = null
}

variable "oauth_consent_screen_type" {
  description = "OAuth consent screen type (INTERNAL or EXTERNAL)"
  type        = string
  default     = "EXTERNAL"

  validation {
    condition     = contains(["INTERNAL", "EXTERNAL"], var.oauth_consent_screen_type)
    error_message = "OAuth consent screen type must be either 'INTERNAL' or 'EXTERNAL'."
  }
}

variable "authorized_domains" {
  description = "List of authorized domains for OAuth"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for domain in var.authorized_domains : can(regex("^[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", domain))
    ])
    error_message = "All authorized domains must be valid domain names."
  }
}

variable "test_users" {
  description = "List of test users for OAuth (for testing before publishing)"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for email in var.test_users : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "All test users must be valid email addresses."
  }
}
