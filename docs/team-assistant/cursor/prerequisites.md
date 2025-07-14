# Prerequisites for Open WebUI Terraform Configuration

This document outlines all the prerequisites required before deploying the Open WebUI Terraform configuration on Google Cloud Platform.

## Google Cloud Platform Requirements

### 1. Google Cloud Project

**Required**:
- A Google Cloud Project with billing enabled
- Project ID must be globally unique
- Billing account linked to the project
- Sufficient quota for required resources

**Recommended Project Structure**:
- Separate projects for staging and production environments
- Consistent naming convention (e.g., `company-openwebui-staging`, `company-openwebui-prod`)

### 2. Required APIs

The following APIs must be enabled in your Google Cloud Project before starting the Terraform deployment:

**Core APIs**:
- Service Usage API (`serviceusage.googleapis.com`)
- Cloud Resource Manager API (`cloudresourcemanager.googleapis.com`)
- IAM Service Account Credentials API (`iamcredentials.googleapis.com`)

**Compute and Networking APIs**:
- Compute Engine API (`compute.googleapis.com`) - Required for VPC Connector
- VPC Access API (`vpcaccess.googleapis.com`) - Required for Cloud Run VPC connectivity
- Cloud Run API (`run.googleapis.com`) - Must use v2

**Storage and Database APIs**:
- Cloud Storage API (`storage.googleapis.com`)
- Cloud SQL Admin API (`sqladmin.googleapis.com`)
- Memorystore for Redis API (`redis.googleapis.com`)

**Security and Secrets APIs**:
- Secret Manager API (`secretmanager.googleapis.com`)
- IAM API (`iam.googleapis.com`)

**CI/CD and Container APIs**:
- Artifact Registry API (`artifactregistry.googleapis.com`)
- Cloud Build API (`cloudbuild.googleapis.com`)

**AI and Monitoring APIs**:
- Vertex AI API (`aiplatform.googleapis.com`) - For external agent engine reference only
- Cloud Monitoring API (`monitoring.googleapis.com`)
- Cloud Logging API (`logging.googleapis.com`)

**Important Notes about APIs**:
- Vertex AI API is enabled only to reference external agent engine resources from another Terraform configuration
- We do NOT deploy agent engine in this configuration - only reference existing resource IDs
- Cloud Run V2 API must be used for enhanced features and VPC connectivity
- Some services may take time to propagate after enablement, allow 2-3 minutes

### 3. IAM Permissions

**Required Roles for Deployment User/Service Account**:
- `roles/owner` OR the following granular roles:
    - `roles/compute.admin`
    - `roles/run.admin`
    - `roles/cloudsql.admin`
    - `roles/redis.admin`
    - `roles/storage.admin`
    - `roles/secretmanager.admin`
    - `roles/iam.admin`
    - `roles/artifactregistry.admin`
    - `roles/cloudbuild.builds.editor`
    - `roles/monitoring.admin`
    - `roles/serviceusage.serviceUsageAdmin`

**Service Account Requirements**:
- Ability to create and manage service accounts
- Ability to grant IAM roles to service accounts
- Ability to create and manage IAM policies

**Deployment Permissions Verification**:
- Verify required permissions for deployment before starting
- Test authentication setup with `gcloud auth list`
- Confirm project access with `gcloud config get-value project`

## Local Development Environment

### 1. Required Tools

**Google Cloud CLI**:
- Version: >= 400.0.0
- Installation: [Google Cloud CLI Installation Guide](https://cloud.google.com/sdk/docs/install)
- Authentication configured (`gcloud auth login` or service account key)

**Terraform**:
- Version: >= 1.5.0
- Installation: [Terraform Installation Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- Google Cloud Provider: >= 4.0.0

**Git**:
- Version: >= 2.0.0
- Access to the Open WebUI repository
- SSH keys configured for GitHub access

**Optional but Recommended**:
- Docker (for local testing)
- kubectl (for Kubernetes debugging if needed)
- jq (for JSON processing in scripts)

### 2. Authentication Setup

**Option 1: User Account (Development)**:
```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
gcloud auth application-default login
```

**Option 2: Service Account (Production)**:
```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS
gcloud config set project YOUR_PROJECT_ID
```

### 3. Environment Variables

**Required Environment Variables**:
```bash
export PROJECT_ID="your-gcp-project-id"
export REGION="us-central1"  # or your preferred region
export ENVIRONMENT="staging"  # or "production"
```

## External Dependencies

### 1. Vertex AI Agent Engine (External)

**Important**: This Terraform configuration does NOT deploy the Vertex AI Agent Engine. It only references an existing agent engine from another Terraform configuration.

**Prerequisites**:
- Vertex AI Agent Engine must be deployed separately
- Agent Engine resource ID must be available
- Agent Engine must be in the same project or accessible from the current project
- Proper IAM permissions to access the external agent engine

**Detailed Agent Engine Configuration Requirements**:

**Required Information Checklist**:
- [ ] Agent Engine Resource ID (Reasoning Engine ID)
- [ ] Agent Engine Project ID
- [ ] Agent Engine Location/Region (e.g., "us-central1")
- [ ] Service account credentials or workload identity setup

**Authentication Setup for Agent Engine Access**:

**Option 1: Service Account JSON (Development/Testing)**:
- Create a service account with `roles/aiplatform.user` permission
- Download the service account JSON key file
- Store the JSON content securely in Secret Manager
- Configure `AGENT_ENGINE_SERVICE_ACCOUNT_JSON` environment variable

**Option 2: Workload Identity Federation (Production - Recommended)**:
- Set up Workload Identity Federation for external authentication
- Configure workload identity provider
- Create service account with appropriate permissions
- Configure `AGENT_ENGINE_WORKLOAD_IDENTITY_PROVIDER` and `AGENT_ENGINE_WORKLOAD_IDENTITY_SERVICE_ACCOUNT`

**Option 3: Default Credentials (GCP Environment)**:
- Ensure the Cloud Run service account has `roles/aiplatform.user` permission
- No additional authentication configuration needed when running on GCP

**Agent Engine Resource Format**:
The Agent Engine resource ID should follow this format:
```
projects/{project-id}/locations/{location}/reasoningEngines/{reasoning-engine-id}
```

**Example Configuration**:
```bash
# Required
AGENT_ENGINE_PROJECT_ID="your-gcp-project-id"
AGENT_ENGINE_LOCATION="us-central1"
AGENT_ENGINE_REASONING_ENGINE_ID="your-reasoning-engine-id"

# Authentication (choose one method)
AGENT_ENGINE_SERVICE_ACCOUNT_JSON='{"type": "service_account", "project_id": "...", ...}'

# Optional for testing
AGENT_ENGINE_CUSTOM_URL="http://localhost:8000"
```

**IAM Permissions Required**:
- `roles/aiplatform.user` - Access to Vertex AI services
- `roles/secretmanager.secretAccessor` - Access to stored credentials (if using service account JSON)

**Validation Commands**:
```bash
# Test Agent Engine access
gcloud ai operations list --region=us-central1

# Verify service account permissions
gcloud projects get-iam-policy YOUR_PROJECT_ID
```

### 2. OAuth Consent Screen (Manual Setup)

**Manual Configuration Required**:
1. Go to [Google Cloud Console OAuth Consent Screen](https://console.cloud.google.com/apis/credentials/consent)
2. Configure OAuth consent screen:
    - Application name: "Open WebUI"
    - User support email
    - Developer contact information
    - Privacy policy URL (if required)
    - Terms of service URL (if required)

**OAuth Scopes Required**:
- `email` - Access to user's email address
- `profile` - Access to user's basic profile information
- `openid` - OpenID Connect authentication

**Authorized Domains**:
- Add your Cloud Run domain (will be configured after deployment)
- Add any custom domains you plan to use

**OAuth Client Configuration**:
- **Provider**: Google OAuth 2.0
- **Client Type**: Web application
- **Redirect URI**: `{cloud-run-url}/auth/callback` (configured after Cloud Run deployment)

**Important Notes**:
- OAuth consent screen setup is a manual prerequisite that must be completed before OAuth module deployment
- OAuth client credentials will be configured manually in Google Cloud Console
- OAuth client secret will be stored in Secret Manager for security

### 3. GitHub Repository Access (2nd Generation Connection)

**Required for CI/CD**:
- A GitHub repository with the Open WebUI source code.
- A **2nd Generation** Cloud Build connection to your GitHub repository.

**Manual Setup Steps**:

1.  **Navigate to Cloud Build Repositories:**
    *   In the Google Cloud Console, go to **Cloud Build > Repositories**.

2.  **Connect Host:**
    *   Click the **"Connect host"** button on the top right.

3.  **Configure the Connection:**
    *   **Provider:** Select **GitHub**.
    *   **Region:** Choose your desired region (e.g., `us-central1`).
    *   **Connection name:** Provide a name for the connection (e.g., `github-connection`). This name will be used as the `connection_id` in your Terraform variables.
    *   Click **"Connect"**.

4.  **Authorize on GitHub:**
    *   A pop-up window will guide you through installing the **Google Cloud Build** GitHub App.
    *   Select the correct GitHub account or organization.
    *   Under "Repository access," choose the specific repository for this project.
    *   Click **"Install"** or **"Authorize"**.

5.  **Link the Repository in GCP:**
    *   After authorization, you will be returned to the GCP Console.
    *   Click on the connection you just created.
    *   Click the **"Connect repository"** button.
    *   Select your repository from the list.
    *   Click **"Connect"**.

Once these steps are complete, you will have the necessary `connection_id`, `github_repo_owner`, and `github_repo_name` to provide to your Terraform configuration.


## Network and Security Requirements

### 1. IP Address Ranges

**VPC Network Ranges** (must not conflict with existing networks):
- Main Subnet: `10.0.0.0/24`
- VPC Connector Subnet: `10.8.0.0/28`
- Private Service Range: `10.1.0.0/16`

**Firewall Requirements**:
- Outbound HTTPS (443) for API calls
- Outbound HTTP (80) for package downloads
- Internal communication between VPC resources

### 2. Domain and SSL

**Optional but Recommended**:
- Custom domain name for production deployment
- SSL certificate (can be managed by Google Cloud)
- DNS management access for domain configuration

## Resource Quotas

### 1. Compute Quotas

**Required Quotas per Environment**:
- Cloud Run services: 2 (staging and production)
- Cloud Run CPU: 10 vCPUs
- Cloud Run Memory: 40 GB
- VPC Connectors: 1 per environment

### 2. Storage Quotas

**Required Quotas**:
- Cloud Storage buckets: 3 (data, state staging, state production)
- Cloud SQL instances: 1 per environment
- Redis instances: 1 per environment

### 3. Network Quotas

**Required Quotas**:
- VPC networks: 1
- Subnets: 2
- Firewall rules: 10
- Static IP addresses: 2 (for Cloud SQL and Redis)

## Cost Considerations

### 1. Estimated Monthly Costs

**Staging Environment** (minimal usage):
- Cloud Run: $5-20/month
- Cloud SQL (db-f1-micro): $7-15/month
- Redis (1GB BASIC): $25-35/month
- Cloud Storage: $1-5/month
- **Total**: ~$40-75/month

**Production Environment** (moderate usage):
- Cloud Run: $20-100/month
- Cloud SQL (db-custom-1-3840): $50-100/month
- Redis (2GB BASIC): $50-70/month
- Cloud Storage: $5-20/month
- **Total**: ~$125-290/month

### 2. Cost Optimization

**Recommendations**:
- Use staging environment for development and testing
- Monitor usage with budget alerts
- Implement auto-scaling to minimize idle costs
- Use lifecycle policies for storage cost optimization

## Validation Checklist

Before starting the Terraform deployment, verify:

- [ ] Google Cloud Project created with billing enabled
- [ ] All required APIs enabled
- [ ] Proper IAM permissions configured
- [ ] gcloud CLI installed and authenticated
- [ ] Terraform installed (>= 1.5.0)
- [ ] External Vertex AI Agent Engine deployed and accessible
- [ ] OAuth consent screen configured
- [ ] GitHub repository access configured
- [ ] Network IP ranges planned and documented
- [ ] Resource quotas sufficient for deployment
- [ ] Budget alerts configured for cost monitoring

## Troubleshooting Common Issues

### 1. API Enablement Issues

**Problem**: APIs not enabled or taking time to propagate
**Solution**:
```bash
gcloud services enable run.googleapis.com cloudbuild.googleapis.com
# Wait 2-3 minutes for propagation
```

### 2. Permission Issues

**Problem**: Insufficient permissions for resource creation
**Solution**: Verify IAM roles and use `gcloud auth list` to check authentication

### 3. Quota Issues

**Problem**: Resource quota exceeded
**Solution**: Request quota increase in Google Cloud Console or choose different regions

### 4. Network Conflicts

**Problem**: IP range conflicts with existing networks
**Solution**: Modify IP ranges in networking module variables

## Important Notes

**Scope Disclaimer**: The items listed in [`docs/whats-next.md`](./whats-next.md) are outside the scope of the current POC and should be considered for future iterations. This current configuration focuses on the core deployment functionality.

## Support and Documentation

**Additional Resources**:
- [Google Cloud Documentation](https://cloud.google.com/docs)
- [Terraform Google Provider Documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Open WebUI Documentation](https://docs.openwebui.com/)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)

**Getting Help**:
- Google Cloud Support (if you have a support plan)
- Stack Overflow with `google-cloud-platform` tag
- Terraform Community Forums
- Open WebUI Community Discord/GitHub

---

**Note**: This prerequisites document should be reviewed and updated regularly as the Terraform configuration evolves and new requirements are identified.
