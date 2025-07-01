# Complete CI/CD Flow: Cloud Build → Artifact Registry → Cloud Run

## Overview

This document provides comprehensive instructions for the automated CI/CD pipeline that builds Open WebUI Docker images, stores them in Google Artifact Registry, and deploys them to Google Cloud Run across multiple environments.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Cloud Build Process](#cloud-build-process)
3. [Artifact Registry Storage](#artifact-registry-storage)
4. [Cloud Run Deployment](#cloud-run-deployment)
5. [Security & Permissions](#security--permissions)
6. [Environment-Specific Workflows](#environment-specific-workflows)
7. [Database Migrations](#database-migrations)
8. [Deployment Instructions](#deployment-instructions)
9. [Monitoring & Troubleshooting](#monitoring--troubleshooting)

## Architecture Overview

The CI/CD pipeline follows this flow:

```
GitHub Repository → Cloud Build → Artifact Registry → Cloud Run
                        ↓
                Database Migrations
```

### Key Components

- **Cloud Build**: Automated build and deployment pipeline
- **Artifact Registry**: Private Docker image storage with lifecycle management
- **Cloud Run**: Serverless container platform for running the application
- **GitHub Integration**: Automated triggers on code pushes and releases

## Cloud Build Process

### 1. Trigger Activation

When code is pushed to GitHub, Cloud Build automatically detects the change:

```bash
# Development workflow
git push origin main

# Production workflow  
git tag v1.2.3
git push origin v1.2.3
```

### 2. Build Configuration

The pipeline uses `cloudbuild.yaml` to define the build steps:

```yaml
steps:
  # Step 1: Build the Docker image
  - name: 'gcr.io/cloud-builders/docker'
    id: 'build-image'
    args:
      - 'build'
      - '-t'
      - '${_ARTIFACT_REGISTRY_URL}/open-webui:${COMMIT_SHA}'
      - '-t' 
      - '${_ARTIFACT_REGISTRY_URL}/open-webui:latest'
      - '-f'
      - 'Dockerfile'
      - '.'
    env:
      - 'DOCKER_BUILDKIT=1'

  # Step 2: Push the commit-specific image
  - name: 'gcr.io/cloud-builders/docker'
    id: 'push-commit-image'
    args:
      - 'push'
      - '${_ARTIFACT_REGISTRY_URL}/open-webui:${COMMIT_SHA}'
    waitFor: ['build-image']

  # Step 3: Push the latest tag
  - name: 'gcr.io/cloud-builders/docker' 
    id: 'push-latest-image'
    args:
      - 'push'
      - '${_ARTIFACT_REGISTRY_URL}/open-webui:latest'
    waitFor: ['build-image']

  # Step 4: Deploy to Cloud Run
  - name: 'gcr.io/cloud-builders/gcloud'
    id: 'deploy-cloud-run'
    args:
      - 'run'
      - 'deploy'
      - '${_ENVIRONMENT}-open-webui'
      - '--image'
      - '${_ARTIFACT_REGISTRY_URL}/open-webui:${COMMIT_SHA}'
      - '--region'
      - '${_REGION}'
      - '--platform'
      - 'managed'
      - '--allow-unauthenticated'
      - '--port'
      - '8080'
      - '--memory'
      - '${_MEMORY_LIMIT}'
      - '--cpu'
      - '${_CPU_LIMIT}'
      - '--min-instances'
      - '${_MIN_INSTANCES}'
      - '--max-instances'
      - '${_MAX_INSTANCES}'
      - '--service-account'
      - '${_SERVICE_ACCOUNT_EMAIL}'
      - '--vpc-connector'
      - '${_VPC_CONNECTOR}'
      - '--vpc-egress'
      - 'private-ranges-only'
      - '--quiet'
    waitFor: ['push-commit-image']
```

### 3. Build Substitutions

Environment-specific values are injected through substitutions:

```yaml
substitutions:
  _ARTIFACT_REGISTRY_URL: 'us-central1-docker.pkg.dev/PROJECT_ID/REPO_NAME'
  _ENVIRONMENT: 'dev'
  _REGION: 'us-central1'
  _MEMORY_LIMIT: '2Gi'
  _CPU_LIMIT: '1'
  _MIN_INSTANCES: '0'
  _MAX_INSTANCES: '10'
  _SERVICE_ACCOUNT_EMAIL: 'cloud-run-sa@PROJECT_ID.iam.gserviceaccount.com'
  _VPC_CONNECTOR: 'projects/PROJECT_ID/locations/REGION/connectors/CONNECTOR_NAME'
  _DATABASE_URL: 'postgresql://user:pass@host:5432/db'
  _REDIS_URL: 'redis://host:6379'
```

## Artifact Registry Storage

### Repository Structure

Artifact Registry organizes Docker images in environment-specific repositories:

```
us-central1-docker.pkg.dev/
└── your-project-id/
    ├── staging-openwebui-repo/       # Staging environment
    └── prod-openwebui-repo/          # Production environment
        └── open-webui/               # Application images
            ├── latest                # Always current (staging)
            ├── abc123def...          # Commit SHA tags
            ├── v1.2.3               # Release tags (production)
            └── stable               # Production-ready tag
```

### Image Lifecycle Management

Terraform configures automatic cleanup policies:

```hcl
# Keep recent versions
cleanup_policies {
  id     = "keep-minimum-versions"
  action = "KEEP"
  
  condition {
    tag_state             = "TAGGED"
    tag_prefixes          = ["v", "release"]
    older_than            = "2592000s"  # 30 days
  }
  
  most_recent_versions {
    keep_count = 10  # Keep last 10 versions
  }
}

# Delete untagged images
cleanup_policies {
  id     = "delete-untagged"
  action = "DELETE"
  
  condition {
    tag_state  = "UNTAGGED"
    older_than = "604800s"  # 7 days
  }
}
```

### Image Tagging Strategy

| Tag Type | Format | Use Case |
|----------|--------|----------|
| Commit SHA | `abc123def456` | Specific version tracking |
| Latest | `latest` | Development builds |
| Release | `v1.2.3` | Semantic versioning |
| Stable | `stable` | Production-ready |

## Cloud Run Deployment

### Container Startup Process

1. **Image Pull**: Cloud Run pulls the specified image from Artifact Registry
2. **Environment Setup**: Injects environment variables for database, Redis, etc.
3. **Network Configuration**: Connects to VPC for private resource access
4. **Health Checks**: Monitors `/health` endpoint for readiness
5. **Traffic Routing**: Routes incoming requests to healthy instances

### Environment Variables

Cloud Run receives comprehensive configuration through environment variables:

```bash
# Database Configuration
DATABASE_URL=postgresql://user:pass@host:5432/openwebui
WEBUI_SECRET_KEY=your-secret-key

# Redis Configuration  
REDIS_URL=redis://redis-host:6379

# Storage Configuration
STORAGE_PROVIDER=gcs
GCS_BUCKET_NAME=your-storage-bucket
GOOGLE_APPLICATION_CREDENTIALS=/app/service-account.json

# OAuth Configuration
GOOGLE_OAUTH_CLIENT_ID=your-oauth-client-id
GOOGLE_OAUTH_CLIENT_SECRET=your-oauth-client-secret
OAUTH_REDIRECT_URI=https://your-domain.com/oauth/callback

# Application Configuration
WEBUI_NAME="Open WebUI"
DEFAULT_LOCALE=en-US
ENABLE_SIGNUP=true  # false in production
ENABLE_LOGIN_FORM=true
```

### Scaling Configuration

Different environments have different scaling parameters:

#### Staging Environment  
```yaml
min_instances: 1        # Always one instance running
max_instances: 10       # Moderate scaling for testing
cpu: "2"               # 2 vCPU
memory: "4Gi"          # 4GB RAM
```

#### Production Environment
```yaml
min_instances: 2        # High availability
max_instances: 20       # High scaling capacity
cpu: "4"               # 4 vCPU  
memory: "8Gi"          # 8GB RAM
```

## Security & Permissions

### Service Account Configuration

#### Cloud Build Service Account
```hcl
resource "google_project_iam_member" "cloud_build_permissions" {
  for_each = toset([
    "roles/cloudbuild.builds.builder",
    "roles/artifactregistry.writer",    # Push images
    "roles/run.developer",              # Deploy to Cloud Run
    "roles/iam.serviceAccountUser"      # Use service accounts
  ])
  role   = each.value
  member = "serviceAccount:${google_service_account.cloud_build.email}"
}
```

#### Cloud Run Service Account
```hcl
resource "google_project_iam_member" "cloud_run_permissions" {
  for_each = toset([
    "roles/artifactregistry.reader",    # Pull images
    "roles/cloudsql.client",           # Connect to database
    "roles/redis.editor",              # Connect to Redis
    "roles/storage.objectAdmin"        # Access GCS bucket
  ])
  role   = each.value
  member = "serviceAccount:${google_service_account.cloud_run.email}"
}
```

### Network Security

- **VPC Connector**: Secure private communication with database and Redis
- **Private IP**: Database and Redis use private IP addresses only
- **Egress Control**: Cloud Run traffic restricted to private ranges only
- **SSL/TLS**: All communications encrypted in transit

## Environment-Specific Workflows

### Local Development

```bash
# Local development workflow
# Run Open WebUI locally for development and testing
cd team-assistant-open-webui
# Follow local setup instructions
```

**Characteristics:**
- Full development environment runs locally
- Fast iteration and debugging
- No cloud costs during development
- Direct access to logs and debugging tools

### Staging Environment

```bash
# Trigger staging build  
git push origin main

# Result:
# → Triggers: staging-openwebui-trigger
# → Builds: us-central1-docker.pkg.dev/project/staging-openwebui-repo/open-webui:abc123
# → Deploys: staging-open-webui Cloud Run service
# → Auto-deploy: ✅ Enabled
```

**Characteristics:**
- Automatic deployment on every push to `main` branch
- Production-like configuration for testing
- Performance and integration testing
- High availability Redis for testing
- Debug logging enabled

### Production Environment

```bash
# Trigger production release
git tag v1.2.3
git push origin v1.2.3

# Result:
# → Triggers: prod-openwebui-release-trigger  
# → Builds: us-central1-docker.pkg.dev/project/prod-openwebui-repo/open-webui:v1.2.3
# → Deploys: prod-open-webui Cloud Run service
# → Auto-deploy: ❌ Manual approval required
```

**Characteristics:**
- Release tags only (v*.*)
- Manual deployment approval required
- High availability configuration
- User signup disabled
- Enhanced monitoring and alerting

## Database Migrations

The CI/CD pipeline automatically handles database schema migrations:

```yaml
# Step 5: Run database migrations
- name: 'gcr.io/cloud-builders/gcloud'
  id: 'run-migrations'
  entrypoint: 'bash'
  args:
    - '-c'
    - |
      # Create temporary Cloud Run Job for migrations
      gcloud run jobs create migrate-${BUILD_ID} \
        --image=${_ARTIFACT_REGISTRY_URL}/open-webui:${COMMIT_SHA} \
        --region=${_REGION} \
        --service-account=${_SERVICE_ACCOUNT_EMAIL} \
        --vpc-connector=${_VPC_CONNECTOR} \
        --vpc-egress=private-ranges-only \
        --set-env-vars="DATABASE_URL=${_DATABASE_URL}" \
        --set-env-vars="REDIS_URL=${_REDIS_URL}" \
        --command="python" \
        --args="-m,alembic,upgrade,head" \
        --quiet
      
      # Execute the migration job
      gcloud run jobs execute migrate-${BUILD_ID} \
        --region=${_REGION} \
        --wait \
        --quiet
      
      # Clean up the job
      gcloud run jobs delete migrate-${BUILD_ID} \
        --region=${_REGION} \
        --quiet
  waitFor: ['deploy-cloud-run']
```

### Migration Process

1. **Create Job**: Temporary Cloud Run Job with the new image
2. **Execute Migration**: Run Alembic migration commands
3. **Validation**: Ensure migration completes successfully
4. **Cleanup**: Remove temporary job after completion

## Deployment Instructions

### Initial Setup

1. **Configure OAuth Credentials**
   ```bash
   cd terraform/scripts
   ./setup-oauth.sh
   ```

2. **Prepare Environment Configuration**
   ```bash
   cd terraform/environments/dev
   cp terraform.tfvars.example terraform.tfvars
   
   # Edit terraform.tfvars with your values:
   # - project_id
   # - region  
   # - github_owner
   # - github_repo
   # - notification_email
   ```

3. **Deploy Infrastructure**
   ```bash
   # Initialize Terraform
   terraform init
   
   # Review deployment plan
   terraform plan
   
   # Deploy infrastructure
   terraform apply
   ```

4. **Trigger First Build**
   ```bash
   # Push code to trigger initial build
   git push origin main
   ```

### Subsequent Deployments

#### Staging Deployments
```bash
# Make code changes
git add .
git commit -m "Add new feature"
git push origin main

# Staging build automatically triggers
# Check Cloud Build console for progress
```

#### Production Releases
```bash
# Create release tag
git tag v1.2.3
git push origin v1.2.3

# Monitor build in Cloud Build console
# Manually approve deployment when ready
```

### Environment-Specific Deployment

```bash
# Deploy staging environment
cd terraform/environments/staging
terraform init
terraform plan
terraform apply

# Deploy production environment
cd terraform/environments/prod
terraform init
terraform plan
terraform apply

# Or use deployment script
cd terraform/scripts  
./deploy.sh staging --apply
./deploy.sh prod --apply
```

## Monitoring & Troubleshooting

### Build Monitoring

Monitor builds in the Google Cloud Console:

1. **Cloud Build Console**: `https://console.cloud.google.com/cloud-build/builds`
2. **Build Logs**: View detailed logs for each step
3. **Build Triggers**: Manage and configure triggers

### Application Monitoring

The infrastructure includes comprehensive monitoring:

```hcl
# Uptime monitoring
resource "google_monitoring_uptime_check_config" "cloud_run_uptime" {
  display_name = "${var.environment}-openwebui-uptime-check"
  timeout      = "10s"
  period       = "300s"
  
  http_check {
    path         = "/health"
    port         = "443"
    use_ssl      = true
    validate_ssl = true
  }
}

# Alert policy for failures
resource "google_monitoring_alert_policy" "uptime_alert" {
  display_name = "${var.environment}-openwebui-uptime-alert"
  # ... configuration for email notifications
}
```

### Common Issues & Solutions

#### Build Failures

**Issue**: Docker build fails
```bash
# Check Dockerfile syntax
docker build -t test-image .

# Verify base image availability
docker pull python:3.11-slim
```

**Issue**: Permission denied pushing to registry
```bash
# Verify service account permissions
gcloud projects get-iam-policy PROJECT_ID \
  --filter="bindings.members:serviceAccount:cloud-build-sa@PROJECT_ID.iam.gserviceaccount.com"
```

#### Deployment Failures

**Issue**: Cloud Run deployment fails
```bash
# Check service account configuration
gcloud run services describe SERVICE_NAME \
  --region=REGION \
  --format="value(spec.template.spec.serviceAccountName)"

# Verify VPC connector
gcloud compute networks vpc-access connectors list \
  --region=REGION
```

**Issue**: Database connection failures
```bash
# Test database connectivity
gcloud sql connect INSTANCE_NAME --user=USER_NAME

# Check VPC peering
gcloud services vpc-peerings list \
  --network=NETWORK_NAME
```

### Logs and Debugging

#### Cloud Build Logs
```bash
# View build logs
gcloud builds list
gcloud builds log BUILD_ID
```

#### Cloud Run Logs
```bash
# View application logs
gcloud run services logs read SERVICE_NAME \
  --region=REGION \
  --limit=100
```

#### Database Logs
```bash
# View database logs
gcloud sql operations list \
  --instance=INSTANCE_NAME
```

## Best Practices

### Development Workflow

1. **Feature Branches**: Create feature branches for new development
2. **Pull Requests**: Use pull requests for code review
3. **Testing**: Ensure tests pass before merging
4. **Staging**: Test changes in staging before production

### Security Practices

1. **Least Privilege**: Grant minimum required permissions
2. **Secret Management**: Use Google Secret Manager for sensitive data
3. **Network Isolation**: Use VPC for private communication
4. **Image Scanning**: Enable vulnerability scanning in Artifact Registry

### Performance Optimization

1. **Build Caching**: Use Docker layer caching for faster builds
2. **Image Size**: Optimize Dockerfile for smaller images
3. **Scaling**: Configure appropriate min/max instances
4. **Resource Limits**: Set appropriate CPU and memory limits

## Conclusion

This CI/CD pipeline provides a robust, secure, and scalable solution for deploying Open WebUI across multiple environments. The automated workflow ensures consistent deployments while maintaining security and observability throughout the process.

For additional support or questions, refer to:
- [Google Cloud Build Documentation](https://cloud.google.com/build/docs)
- [Artifact Registry Documentation](https://cloud.google.com/artifact-registry/docs)
- [Cloud Run Documentation](https://cloud.google.com/run/docs) 