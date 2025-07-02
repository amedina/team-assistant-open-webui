# Open WebUI Terraform Infrastructure Report

## Executive Summary

This report provides a comprehensive overview of the Terraform infrastructure deployment for the Open WebUI application on Google Cloud Platform. The infrastructure supports both staging and production environments with a modular, scalable architecture.

## Infrastructure Overview

### Architecture Components

The Open WebUI infrastructure consists of 10 core modules designed for enterprise-grade deployment:

1. **Project Services** - API enablement and service configuration
2. **Networking** - VPC, subnets, and connectivity infrastructure  
3. **IAM** - Service accounts and role-based access control
4. **Storage** - Cloud Storage buckets for file management
5. **Database** - PostgreSQL with high availability options
6. **Redis** - Memorystore for caching and session management
7. **Artifact Registry** - Container image storage
8. **Cloud Build** - CI/CD pipeline automation
9. **Cloud Run** - Containerized application hosting
10. **Monitoring** - Alerting and observability

### Technology Stack

- **Platform**: Google Cloud Platform (GCP)
- **Container Runtime**: Cloud Run (serverless containers)
- **Database**: Cloud SQL PostgreSQL 15
- **Cache**: Memorystore Redis
- **Storage**: Cloud Storage (Google Cloud Storage)
- **CI/CD**: Cloud Build with GitHub integration
- **Monitoring**: Google Cloud Monitoring & Alerting
- **Infrastructure as Code**: Terraform 1.5+

## Project Structure

```
deployment/terraform/
├── environments/
│   ├── staging/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── terraform.tfvars
│       └── backend.tf
└── modules/
    ├── project-services/
    ├── networking/
    ├── iam/
    ├── storage/
    ├── database/
    ├── redis/
    ├── artifact-registry/
    ├── cloud-build/
    ├── cloud-run/
    └── monitoring/
```

## Environment Configuration

### Staging Environment

**Project**: `ps-agent-sandbox`  
**Region**: `us-central1`  
**Purpose**: Development, testing, and validation

#### Key Configuration:
- **Database**: `db-g1-small` (1 vCPU, 1.7GB RAM)
- **Redis**: `STANDARD_HA` with 1GB memory
- **Cloud Run**: 1 vCPU, 2GB RAM, 0-10 instances
- **Features**: Auto-signup enabled, debug logging, deletion protection disabled

### Production Environment

**Project**: `ps-agent-sandbox`  
**Region**: `us-central1`  
**Purpose**: Live production workloads

#### Key Configuration:
- **Database**: `db-g1-small` with high availability
- **Redis**: `STANDARD_HA` with 2GB memory  
- **Cloud Run**: 2 vCPU, 4GB RAM, 1-20 instances
- **Features**: Manual signup, production logging, deletion protection enabled

## Detailed Module Configuration

### 1. Project Services Module

**Purpose**: Enable required Google Cloud APIs

**Enabled APIs**:
- `compute.googleapis.com` - Compute Engine
- `run.googleapis.com` - Cloud Run
- `cloudbuild.googleapis.com` - Cloud Build
- `artifactregistry.googleapis.com` - Artifact Registry
- `sqladmin.googleapis.com` - Cloud SQL
- `redis.googleapis.com` - Memorystore
- `storage.googleapis.com` - Cloud Storage
- `iam.googleapis.com` - Identity & Access Management
- `secretmanager.googleapis.com` - Secret Manager
- `monitoring.googleapis.com` - Cloud Monitoring
- `logging.googleapis.com` - Cloud Logging
- `servicenetworking.googleapis.com` - Service Networking
- `vpcaccess.googleapis.com` - VPC Access
- `aiplatform.googleapis.com` - Vertex AI

### 2. Networking Module

**Purpose**: Establish secure network infrastructure

**Components**:
- **VPC Network**: Custom VPC with regional subnets
- **Database Subnet**: `10.0.0.0/24` for private services
- **VPC Connector**: `10.1.0.0/28` for Cloud Run connectivity
- **Private Service Connection**: For managed services
- **Firewall Rules**: Health check and internal traffic allowances

**Configuration**:
```hcl
vpc_connector_cidr = "10.1.0.0/28"
database_subnet_cidr = "10.0.0.0/24"
vpc_connector_min_instances = 2
vpc_connector_max_instances = 10
```

### 3. IAM Module

**Purpose**: Service account management and role assignments

**Service Accounts**:

1. **Cloud Run Service Account**: `staging-open-webui-cloudrun@ps-agent-sandbox.iam.gserviceaccount.com`
   - `roles/cloudsql.client` - Database access
   - `roles/storage.objectAdmin` - Storage bucket management
   - `roles/aiplatform.user` - Vertex AI integration
   - `roles/monitoring.metricWriter` - Metrics publishing
   - `roles/logging.logWriter` - Log writing
   - `roles/secretmanager.secretAccessor` - Secret access

2. **Cloud Build Service Account**: `staging-open-webui-cloudbuild@ps-agent-sandbox.iam.gserviceaccount.com`
   - `roles/cloudbuild.builds.editor` - Build management
   - `roles/artifactregistry.writer` - Image publishing
   - `roles/run.developer` - Service deployment
   - `roles/iam.serviceAccountUser` - Service account usage
   - `roles/logging.logWriter` - Build logging
   - `roles/storage.admin` - Build artifact storage

### 4. Storage Module

**Purpose**: File storage and static asset management

**Configuration**:
- **Bucket**: `ps-agent-sandbox-open-webui-staging-storage`
- **Location**: `us-central1`
- **Versioning**: Enabled (staging), Disabled (production)
- **Lifecycle**: Automatic cleanup of old versions
- **Access**: Service account-based IAM

**Directory Structure**:
```
bucket/
├── uploads/       # User file uploads
├── cache/         # Application cache
├── backups/       # Database backups
├── models/        # AI model storage
└── app-data/      # Application data
```

### 5. Database Module

**Purpose**: PostgreSQL database hosting

**Configuration**:
- **Engine**: PostgreSQL 15
- **Tier**: `db-g1-small` (staging), `db-g1-small` (production)
- **Storage**: 20GB SSD (auto-expanding)
- **Backup**: Automated daily backups (7-day retention)
- **Security**: Private IP, VPC-native connectivity
- **High Availability**: Disabled (staging), Enabled (production)

**Connection Details**:
- **Host**: Private IP (10.0.0.3)
- **Port**: 5432
- **Database**: `openwebui`
- **User**: `openwebui`
- **Password**: Auto-generated (32 characters)

### 6. Redis Module

**Purpose**: Caching and session management

**Configuration**:
- **Version**: Redis 7.0
- **Tier**: `STANDARD_HA` (high availability)
- **Memory**: 1GB (staging), 2GB (production)
- **Network**: VPC-native connectivity
- **Persistence**: RDB snapshots enabled

**Connection Details**:
- **Host**: Private IP (10.0.0.4)
- **Port**: 6379
- **Auth**: No authentication (VPC-secured)

### 7. Artifact Registry Module

**Purpose**: Container image storage and management

**Configuration**:
- **Repository**: `staging-open-webui`
- **Format**: Docker
- **Location**: `us-central1`
- **Cleanup Policies**: 
  - Keep latest 10 images
  - Delete images older than 30 days
  - Keep images with specific tags (`latest`, `stable`)

### 8. Cloud Build Module

**Purpose**: CI/CD pipeline automation

**Triggers**:
1. **Staging Auto-deploy**: Branch `terraform-v1`
2. **Production Manual**: Version tags (`v*.*.*`)

**GitHub Integration**:
- **Repository**: `amedina/team-assistant-open-webui`
- **Connection**: Cloud Build GitHub App
- **Service Account**: Custom Cloud Build SA with minimal permissions

**Build Process**:
1. Source code checkout
2. Docker image build (multi-stage)
3. Image push to Artifact Registry
4. Cloud Run service deployment
5. Database migrations (if needed)

### 9. Cloud Run Module

**Purpose**: Serverless container hosting

**Configuration**:

#### Staging:
```hcl
cpu_limit = "1"
memory_limit = "2Gi"
min_instances = 0
max_instances = 10
container_concurrency = 80
timeout_seconds = 300
```

#### Production:
```hcl
cpu_limit = "2"
memory_limit = "4Gi"
min_instances = 1
max_instances = 20
container_concurrency = 80
timeout_seconds = 300
```

**Health Checks**:
- **Liveness Probe**: `/health` endpoint, 60s initial delay
- **Startup Probe**: `/health` endpoint, 240s total timeout
- **Readiness**: Automatic based on traffic serving

**Environment Variables**:
- `DATABASE_URL`: PostgreSQL connection string (URL-encoded)
- `REDIS_URL`: Redis connection string
- `WEBUI_SECRET_KEY`: Auto-generated 32-character secret
- `STORAGE_PROVIDER`: `gcs`
- `GCS_BUCKET_NAME`: Storage bucket name
- `GOOGLE_CLIENT_ID/SECRET`: OAuth configuration
- Plus 15+ additional Open WebUI specific variables

### 10. Monitoring Module

**Purpose**: Observability and alerting

**Components**:
- **Uptime Checks**: Health endpoint monitoring (5-minute intervals)
- **Alert Policies**: Service downtime notifications
- **Notification Channels**: Email alerts to `albertomedina@google.com`
- **Dashboards**: Infrastructure and application metrics

## Security Configuration

### Network Security
- **VPC-native**: All components use private networking
- **Egress Control**: `private-ranges-only` for Cloud Run
- **Firewall Rules**: Minimal required ports (health checks only)
- **No Public IPs**: Database and Redis are private-only

### IAM Security
- **Principle of Least Privilege**: Minimal required permissions
- **Service Account Keys**: Disabled by organization policy
- **Workload Identity**: Used for secure authentication
- **No Default Service Accounts**: Custom SAs with specific roles

### Data Security
- **Encryption at Rest**: All data encrypted with Google-managed keys
- **Encryption in Transit**: TLS 1.2+ for all connections
- **Secret Management**: Passwords auto-generated and stored securely
- **Database Security**: Private IP, VPC-only access

## Deployment Workflow

### 1. Infrastructure Deployment

```bash
# Navigate to environment
cd deployment/terraform/environments/staging

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply infrastructure
terraform apply
```

### 2. Application Deployment

```bash
# Build and deploy via Cloud Build
gcloud builds submit --config=deployment/build-only.yaml --project ps-agent-sandbox

# Or via CI/CD trigger (automatic on branch push)
git push origin terraform-v1
```

### 3. Verification

```bash
# Check Cloud Run service status
gcloud run services describe staging-open-webui --region us-central1

# View application logs  
gcloud run services logs read staging-open-webui --region us-central1

# Test health endpoint
curl https://staging-open-webui-[HASH].us-central1.run.app/health
```

## Resource Costs (Estimated Monthly)

### Staging Environment:
- **Cloud Run**: ~$20-40 (variable usage)
- **Cloud SQL**: ~$25 (db-g1-small)
- **Redis**: ~$45 (1GB STANDARD_HA)
- **Storage**: ~$2 (100GB usage)
- **Networking**: ~$10 (VPC, NAT)
- **Total**: ~$102-122/month

### Production Environment:
- **Cloud Run**: ~$50-100 (higher usage)
- **Cloud SQL**: ~$50 (HA enabled)
- **Redis**: ~$90 (2GB STANDARD_HA)
- **Storage**: ~$5 (250GB usage)
- **Networking**: ~$15 (higher bandwidth)
- **Total**: ~$210-260/month

## Current Status

### ✅ Successfully Deployed:
- All networking infrastructure
- Database and Redis instances
- Storage buckets and IAM
- Artifact Registry
- Docker image builds and pushes
- Service account permissions

### ⚠️ In Progress:
- Cloud Run startup probe timeout issues
- Application health check optimization
- OAuth configuration validation

### 🔄 Next Steps:
1. Resolve Cloud Run startup timeout (increase to 300+ seconds)
2. Optimize Open WebUI initialization time
3. Enable Cloud Build CI/CD triggers
4. Production environment deployment
5. Domain mapping and SSL certificates
6. Backup and disaster recovery procedures

## Troubleshooting Guide

### Common Issues:

1. **Build Failures**:
   - Check Cloud Build service account permissions
   - Verify Dockerfile BUILDPLATFORM argument
   - Increase Node.js heap size for frontend builds

2. **Database Connection Issues**:
   - Ensure VPC connector is properly configured
   - Verify private service connection
   - Check URL encoding of database passwords

3. **Cloud Run Startup Failures**:
   - Increase startup probe timeouts
   - Check application logs for initialization errors
   - Verify environment variables

4. **Storage Access Issues**:
   - Confirm service account IAM permissions
   - Check bucket regional configuration
   - Verify GCS client authentication

## Maintenance and Operations

### Regular Tasks:
- **Weekly**: Review application logs and performance metrics
- **Monthly**: Check resource utilization and costs
- **Quarterly**: Update base images and dependencies
- **Annually**: Review and rotate secrets

### Backup Strategy:
- **Database**: Automated daily backups (7-day retention)
- **Storage**: Object versioning enabled
- **Infrastructure**: Terraform state in Cloud Storage
- **Code**: Git repository with tagged releases

### Monitoring:
- **Uptime**: 99.9% target availability
- **Response Time**: <2s for health checks
- **Error Rate**: <1% application errors
- **Resource Usage**: Auto-scaling based on CPU/memory

## Conclusion

The Open WebUI Terraform infrastructure provides a robust, scalable, and secure foundation for both staging and production deployments. The modular architecture allows for easy customization and environment-specific configurations while maintaining infrastructure as code best practices.

The current deployment successfully establishes all core infrastructure components. Final application-level optimizations are needed to complete the startup process and achieve full operational status.

---

**Document Version**: 1.0  
**Last Updated**: July 2, 2025  
**Contact**: albertomedina@google.com  
**Project**: Open WebUI Infrastructure Deployment 