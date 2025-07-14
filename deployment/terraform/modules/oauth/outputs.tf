output "oauth_client_id" {
  description = "Google OAuth client ID"
  value       = var.oauth_client_id
}

output "oauth_client_secret_secret_id" {
  description = "Secret Manager secret ID for OAuth client secret"
  value       = var.oauth_client_secret_secret_id
}

output "oauth_ready" {
  description = "Indicates that OAuth configuration is ready"
  value       = true
  depends_on = [
    google_secret_manager_secret_version.oauth_client_secret,
    null_resource.oauth_validation
  ]
}

output "oauth_configuration" {
  description = "OAuth configuration details"
  value = {
    client_id           = var.oauth_client_id
    environment         = var.environment
    project_id          = var.project_id
    consent_screen_type = var.oauth_consent_screen_type
    scopes              = var.oauth_scopes
    redirect_uris       = var.redirect_uris
    authorized_domains  = var.authorized_domains
  }
}

output "oauth_urls" {
  description = "OAuth-related URLs"
  value = {
    consent_screen_url = "https://console.cloud.google.com/apis/credentials/consent?project=${var.project_id}"
    credentials_url    = "https://console.cloud.google.com/apis/credentials?project=${var.project_id}"
    oauth_playground   = "https://developers.google.com/oauthplayground"
  }
}

output "oauth_setup_guide_path" {
  description = "Path to the OAuth setup guide"
  value       = local_file.oauth_setup_guide.filename
}

output "oauth_monitoring_config_path" {
  description = "Path to the OAuth monitoring configuration (if enabled)"
  value       = var.enable_oauth_monitoring ? local_file.oauth_monitoring_config[0].filename : null
}

output "oauth_validation_status" {
  description = "OAuth validation status"
  value = {
    client_id_format_valid = true
    secret_stored          = true
    validation_completed   = true
  }
  depends_on = [
    null_resource.oauth_validation,
    google_secret_manager_secret_version.oauth_client_secret
  ]
}

output "required_manual_steps" {
  description = "Manual steps required to complete OAuth setup"
  value = [
    "1. Configure OAuth consent screen in Google Cloud Console",
    "2. Create OAuth 2.0 Client ID with correct redirect URIs",
    "3. Verify consent screen is published for external users",
    "4. Test OAuth flow with your application",
    "5. Monitor OAuth usage in Cloud Console"
  ]
}

output "oauth_security_recommendations" {
  description = "Security recommendations for OAuth implementation"
  value = [
    "Use HTTPS for all redirect URIs",
    "Regularly rotate OAuth client secrets",
    "Monitor OAuth usage and failed attempts",
    "Implement proper session management",
    "Use state parameter to prevent CSRF attacks",
    "Validate redirect URIs on server side"
  ]
}

output "oauth_testing_urls" {
  description = "URLs for testing OAuth configuration"
  value = {
    for uri in var.redirect_uris : uri => {
      test_url     = uri
      curl_command = "curl -I ${uri}"
    }
  }
}

output "oauth_environment_config" {
  description = "Environment-specific OAuth configuration"
  value = {
    environment           = var.environment
    is_production         = var.environment == "prod"
    consent_screen_type   = var.oauth_consent_screen_type
    test_users_configured = length(var.test_users) > 0
    monitoring_enabled    = var.enable_oauth_monitoring
    health_check_enabled  = var.enable_oauth_health_check
  }
}

output "oauth_compliance_info" {
  description = "OAuth compliance and verification information"
  value = {
    privacy_policy_required    = var.privacy_policy_url != null
    terms_of_service_required  = var.terms_of_service_url != null
    support_email_configured   = var.support_email != null
    developer_email_configured = var.developer_email != null
    verification_status        = "Manual verification required"
  }
} 
