# Agent Engine Configuration for Open WebUI

## Environment: staging
This document describes the external Agent Engine configuration for Open WebUI.

## Agent Engine Details
- **Project ID**: ps-agent-sandbox
- **Location**: us-central1
- **Resource Name**: projects/ps-agent-sandbox/locations/us-central1/reasoningEngines/4039843214960623616
- **Custom URL**: Not configured

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
1. Ensure the Agent Engine is deployed in project: ps-agent-sandbox
2. Verify the resource exists at location: us-central1
3. Grant necessary permissions to Open WebUI service account
4. Test connectivity from Open WebUI to Agent Engine

## Environment Variables
The following environment variables are set in Cloud Run:
- `AGENT_ENGINE_RESOURCE_ID`: Stored in Secret Manager
- `AGENT_ENGINE_PROJECT_ID`: ps-agent-sandbox
- `AGENT_ENGINE_LOCATION`: us-central1

## Custom URL Configuration

No custom URL configured. Using standard Vertex AI endpoint.


## Monitoring and Logging
Monitor Agent Engine usage through:
- Vertex AI console: https://console.cloud.google.com/vertex-ai/models?project=ps-agent-sandbox
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
  --project=ps-agent-sandbox \
  --region=us-central1 \
  --json-request=test_request.json
```

## Support
For Agent Engine issues:
- Check Vertex AI documentation
- Review Cloud Logging for error messages
- Contact your AI/ML team for model-specific issues
