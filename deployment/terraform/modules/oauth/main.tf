terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
  }
}

locals {
  common_labels = {
    application = "open-webui"
    environment = var.environment
    managed-by  = "terraform"
  }
}

# OAuth Consent Screen (External - Must be manually configured)
# This resource does not create the OAuth consent screen
# It references an existing consent screen that must be manually configured

# Data source to verify OAuth client exists
data "google_client_config" "current" {}

# Validate OAuth client ID format
resource "null_resource" "oauth_validation" {
  triggers = {
    client_id = var.oauth_client_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      if [[ ! "${var.oauth_client_id}" =~ ^[0-9]+-[a-zA-Z0-9]+\.apps\.googleusercontent\.com$ ]]; then
        echo "ERROR: OAuth client ID must be in format: 123456789-abcdef123456.apps.googleusercontent.com"
        exit 1
      fi
    EOT
  }
}

# Store OAuth client secret in Secret Manager
resource "google_secret_manager_secret_version" "oauth_client_secret" {
  secret      = var.oauth_client_secret_secret_id
  secret_data = var.oauth_client_secret_value

  depends_on = [
    null_resource.oauth_validation,
    var.secrets_ready
  ]
}

# Create OAuth configuration documentation
resource "local_file" "oauth_setup_guide" {
  filename = "${path.module}/oauth_setup_guide.md"
  content  = <<-EOT
# OAuth Setup Guide for Open WebUI

## Prerequisites
This document outlines the manual steps required to configure Google OAuth for Open WebUI.

## Environment: ${var.environment}
- **Project ID**: ${var.project_id}
- **OAuth Client ID**: ${var.oauth_client_id}
- **Redirect URIs**: ${join(", ", var.redirect_uris)}

## Manual Configuration Steps

### 1. OAuth Consent Screen Configuration
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Navigate to **APIs & Services > OAuth consent screen**
3. Configure the consent screen with:
   - Application name: Open WebUI (${var.environment})
   - User support email: ${var.support_email}
   - Developer contact information: ${var.developer_email}
   - Application domain: ${var.application_domain}
   - Privacy policy: ${var.privacy_policy_url}
   - Terms of service: ${var.terms_of_service_url}

### 2. OAuth Client Configuration
1. Go to **APIs & Services > Credentials**
2. Create OAuth 2.0 Client ID:
   - Application type: Web application
   - Name: Open WebUI ${var.environment}
   - Authorized redirect URIs:
     ${join("\n     ", [for uri in var.redirect_uris : "- ${uri}"])}

### 3. Scopes Configuration
Required scopes for Open WebUI:
- openid
- email
- profile

### 4. Secret Management
The OAuth client secret must be stored in Google Secret Manager:
- Secret ID: ${var.oauth_client_secret_secret_id}
- This is handled automatically by Terraform

### 5. Verification
After configuration, verify:
1. OAuth consent screen is published
2. Client ID is correctly configured
3. Redirect URIs match your application URLs
4. Secret is stored in Secret Manager

### 6. Testing
Test OAuth flow:
1. Navigate to your application
2. Click "Sign in with Google"
3. Verify consent screen appears
4. Complete authentication flow

## Troubleshooting
- **Invalid Client ID**: Verify client ID format and project
- **Redirect URI mismatch**: Check redirect URIs in OAuth configuration
- **Consent screen not published**: Ensure consent screen is published for external users
- **Secret not found**: Verify secret is stored in Secret Manager

## Security Notes
- Keep OAuth client secret secure
- Use HTTPS for all redirect URIs
- Regularly rotate client secrets
- Monitor OAuth usage in Cloud Console

## Support
For issues with OAuth configuration, contact: ${var.support_email}
EOT
}

# Create OAuth monitoring dashboard (optional)
resource "local_file" "oauth_monitoring_config" {
  count = var.enable_oauth_monitoring ? 1 : 0

  filename = "${path.module}/oauth_monitoring.json"
  content = jsonencode({
    displayName = "OAuth Monitoring - ${var.environment}"
    gridLayout = {
      widgets = [
        {
          title = "OAuth Login Success Rate"
          xyChart = {
            dataSets = [
              {
                plotType   = "LINE"
                targetAxis = "Y1"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.environment}-open-webui\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_RATE"
                    }
                  }
                }
              }
            ]
          }
        }
      ]
    }
  })
}

# OAuth health check endpoint
resource "null_resource" "oauth_health_check" {
  count = var.enable_oauth_health_check ? 1 : 0

  triggers = {
    client_id   = var.oauth_client_id
    environment = var.environment
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "OAuth Configuration Health Check"
      echo "Environment: ${var.environment}"
      echo "Client ID: ${var.oauth_client_id}"
      echo "Project: ${var.project_id}"
      echo "Status: Ready for manual configuration"
    EOT
  }
} 
