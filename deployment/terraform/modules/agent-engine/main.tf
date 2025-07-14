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

# Data source to reference external Agent Engine
data "google_project" "current" {
  project_id = var.agent_engine_project_id
}

# Validate Agent Engine configuration
resource "null_resource" "agent_engine_validation" {
  triggers = {
    project_id    = var.agent_engine_project_id
    location      = var.agent_engine_location
    resource_name = var.agent_engine_resource_name
    environment   = var.environment
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Validating Agent Engine configuration..."
      echo "Project: ${var.agent_engine_project_id}"
      echo "Location: ${var.agent_engine_location}"
      echo "Resource: ${var.agent_engine_resource_name}"
      echo "Environment: ${var.environment}"
      
      # Validate project ID format
      if [[ ! "${var.agent_engine_project_id}" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]]; then
        echo "ERROR: Agent Engine project ID format is invalid"
        exit 1
      fi
      
      # Validate location format
      if [[ ! "${var.agent_engine_location}" =~ ^[a-z]+-[a-z]+[0-9]+$ ]]; then
        echo "ERROR: Agent Engine location format is invalid"
        exit 1
      fi
      
      echo "Agent Engine configuration validation passed"
    EOT
  }
}

# Store Agent Engine resource ID in Secret Manager
resource "google_secret_manager_secret_version" "agent_engine_id" {
  secret      = var.agent_engine_secret_id
  secret_data = var.agent_engine_resource_name

  depends_on = [
    null_resource.agent_engine_validation,
    var.secrets_ready
  ]
}

# Create Agent Engine configuration documentation
resource "local_file" "agent_engine_config" {
  filename = "${path.module}/agent_engine_config.md"
  content  = <<-EOT
# Agent Engine Configuration for Open WebUI

## Environment: ${var.environment}
This document describes the external Agent Engine configuration for Open WebUI.

## Agent Engine Details
- **Project ID**: ${var.agent_engine_project_id}
- **Location**: ${var.agent_engine_location}
- **Resource Name**: ${var.agent_engine_resource_name}
- **Custom URL**: ${var.agent_engine_custom_url != "" ? var.agent_engine_custom_url : "Not configured"}

## External Resource Reference
This Terraform configuration references an **external** Agent Engine that must be:
1. Already deployed in the specified project
2. Accessible from the Open WebUI project
3. Properly configured with required permissions

## Required Permissions
The Open WebUI service account needs the following permissions on the Agent Engine:
- `aiplatform.endpoints.predict`
- `aiplatform.endpoints.explain`
- `aiplatform.models.predict`

## Configuration Steps
1. Ensure the Agent Engine is deployed in project: ${var.agent_engine_project_id}
2. Verify the resource exists at location: ${var.agent_engine_location}
3. Grant necessary permissions to Open WebUI service account
4. Test connectivity from Open WebUI to Agent Engine

## Environment Variables
The following environment variables are set in Cloud Run:
- `AGENT_ENGINE_RESOURCE_ID`: Stored in Secret Manager
- `AGENT_ENGINE_PROJECT_ID`: ${var.agent_engine_project_id}
- `AGENT_ENGINE_LOCATION`: ${var.agent_engine_location}

## Custom URL Configuration
%{if var.agent_engine_custom_url != ""}
A custom URL is configured: ${var.agent_engine_custom_url}
This URL will be used for testing and development purposes.
%{else}
No custom URL configured. Using standard Vertex AI endpoint.
%{endif}

## Monitoring and Logging
Monitor Agent Engine usage through:
- Vertex AI console: https://console.cloud.google.com/vertex-ai/models?project=${var.agent_engine_project_id}
- Cloud Logging: Filter by resource.type="aiplatform.googleapis.com/Endpoint"
- Cloud Monitoring: aiplatform.googleapis.com metrics

## Troubleshooting
Common issues and solutions:
1. **Permission denied**: Verify IAM roles for Open WebUI service account
2. **Resource not found**: Confirm Agent Engine is deployed and accessible
3. **Network connectivity**: Check VPC peering and firewall rules
4. **Authentication**: Ensure service account has proper credentials

## Security Considerations
- Agent Engine should be in a private network
- Use least privilege IAM roles
- Enable audit logging for all API calls
- Monitor for unusual usage patterns

## Testing
Test Agent Engine connectivity:
```bash
# Test from Cloud Shell
gcloud ai endpoints predict ENDPOINT_ID \
  --project=${var.agent_engine_project_id} \
  --region=${var.agent_engine_location} \
  --json-request=test_request.json
```

## Support
For Agent Engine issues:
- Check Vertex AI documentation
- Review Cloud Logging for error messages
- Contact your AI/ML team for model-specific issues
EOT
}

# Create Agent Engine monitoring configuration
resource "local_file" "agent_engine_monitoring" {
  count = var.enable_agent_engine_monitoring ? 1 : 0

  filename = "${path.module}/agent_engine_monitoring.json"
  content = jsonencode({
    displayName = "Agent Engine Monitoring - ${var.environment}"
    description = "Monitoring dashboard for external Agent Engine usage"

    # Dashboard configuration for Agent Engine metrics
    dashboardFilters = [{
      filterType = "RESOURCE_LABEL"
      labelKey   = "project_id"
      labelValue = var.agent_engine_project_id
    }]

    gridLayout = {
      columns = 12
      widgets = [
        {
          title = "Agent Engine Prediction Requests"
          xyChart = {
            dataSets = [{
              plotType   = "LINE"
              targetAxis = "Y1"
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"aiplatform.googleapis.com/Endpoint\" AND resource.labels.project_id=\"${var.agent_engine_project_id}\""
                  aggregation = {
                    alignmentPeriod  = "60s"
                    perSeriesAligner = "ALIGN_RATE"
                  }
                }
              }
            }]
          }
        },
        {
          title = "Agent Engine Error Rate"
          xyChart = {
            dataSets = [{
              plotType   = "LINE"
              targetAxis = "Y1"
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"aiplatform.googleapis.com/Endpoint\" AND resource.labels.project_id=\"${var.agent_engine_project_id}\" AND metric.type=\"aiplatform.googleapis.com/prediction/error_count\""
                  aggregation = {
                    alignmentPeriod  = "60s"
                    perSeriesAligner = "ALIGN_RATE"
                  }
                }
              }
            }]
          }
        },
        {
          title = "Agent Engine Latency"
          xyChart = {
            dataSets = [{
              plotType   = "LINE"
              targetAxis = "Y1"
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"aiplatform.googleapis.com/Endpoint\" AND resource.labels.project_id=\"${var.agent_engine_project_id}\" AND metric.type=\"aiplatform.googleapis.com/prediction/latency\""
                  aggregation = {
                    alignmentPeriod  = "60s"
                    perSeriesAligner = "ALIGN_MEAN"
                  }
                }
              }
            }]
          }
        }
      ]
    }
  })
}

# Agent Engine health check
resource "null_resource" "agent_engine_health_check" {
  count = var.enable_agent_engine_health_check ? 1 : 0

  triggers = {
    project_id    = var.agent_engine_project_id
    location      = var.agent_engine_location
    resource_name = var.agent_engine_resource_name
    environment   = var.environment
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Agent Engine Health Check"
      echo "========================="
      echo "Environment: ${var.environment}"
      echo "Project: ${var.agent_engine_project_id}"
      echo "Location: ${var.agent_engine_location}"
      echo "Resource: ${var.agent_engine_resource_name}"
      echo "Status: Configuration validated"
      echo ""
      echo "Note: This is an external resource reference."
      echo "Actual health check should be performed against the live endpoint."
    EOT
  }
}

# Create IAM policy document for Agent Engine access
resource "local_file" "agent_engine_iam_policy" {
  filename = "${path.module}/agent_engine_iam_policy.json"
  content = jsonencode({
    bindings = [
      {
        role = "roles/aiplatform.user"
        members = [
          "serviceAccount:${var.cloud_run_service_account_email}"
        ]
      },
      {
        role = "roles/aiplatform.predictor"
        members = [
          "serviceAccount:${var.cloud_run_service_account_email}"
        ]
      }
    ]
  })
} 
