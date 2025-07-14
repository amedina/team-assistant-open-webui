# Terraform Configuration Prompt for Open WebUI on Google Cloud Platform

## Objective
Create a complete, production-ready Terraform configuration to deploy Open WebUI on Google Cloud Platform following the modular architecture and step-by-step implementation plan outlined in the provided documentation.

## Technical Requirements

### Terraform Version and Provider
- **Terraform Version**: 5.x (latest stable)
- **Google Cloud Provider**: >= 4.0.0
- **Backend**: Google Cloud Storage with state locking
- **API Version**: Cloud Run V2 (mandatory)

### Architecture Overview
Deploy Open WebUI with the following components:
- **Cloud Run V2**: Main application (2 CPU, 4GB RAM)
- **Cloud SQL PostgreSQL**: Primary database with private IP
- **Redis (Memorystore)**: BASIC tier for caching (non-persistent)
- **Cloud Storage**: Application data storage (API-based, NO volume mounting)
- **VPC Connector**: Mandatory for private service access
- **Secret Manager**: All sensitive data (NEVER in tfvars)
- **Artifact Registry**: Container images
- **Cloud Build**: CI/CD with 10-minute timeout

## Critical Implementation Requirements

### Security (Non-Negotiable)
- **ALL sensitive data MUST be stored in Secret Manager** - never in terraform.tfvars
- **Use VPC Connector for private service access** (Cloud SQL, Redis)
- **Private IP only** for Cloud SQL and Redis (no public access)
- **Least privilege IAM** for all service accounts
- **OAuth integration** with Google (consent screen prerequisite)
- **Secrets injection** via Secret Manager in Cloud Run

### Cloud Run V2 Configuration
- **API**: Must use `google_cloud_run_v2_service` resource
- **Resources**: 2 CPU (2000m), 4GB RAM (4096Mi) - configurable in terraform.tfvars
- **Health Checks**: 240 seconds timeout, 5 retries (Open WebUI startup time)
- **VPC Connector**: Mandatory for database/Redis access
- **Scaling**:
  - **Staging**: Min 1, Max 1 (no auto-scaling)
  - **Production**: Min 1, Max 10 (auto-scaling enabled)

### Database and Storage
- **PostgreSQL**: Private IP with SSL enforcement, connection via VPC Connector
- **Redis**: BASIC tier (non-persistent), caching only, private network
- **Cloud Storage**: API-based integration (NO volume mounting)
- **DATABASE_URL**: Complete connection string in Secret Manager
- **REDIS_URL**: Connection string in Secret Manager

### External Integrations
- **Vertex AI Agent Engine**: Reference external resource only (DO NOT deploy)
- **OAuth**: Google OAuth with manual consent screen setup
- **GitHub**: 2nd generation Cloud Build connection

### Build and Deployment
- **Build Timeout**: 10 minutes (600 seconds) for Open WebUI complexity
- **Image Strategy**: Same image promoted from staging to production
- **Machine Type**: e2-standard-2 for faster builds
- **Manual Production**: Production deployment requires manual trigger

## Directory Structure
Create the following structure:

```
deployment/
├── cloudbuild.yaml
├── README.md
├── run_cloud_build.sh
└── terraform/
    ├── environments/
    │   ├── staging/
    │   │   ├── backend.tf
    │   │   ├── create_state_bucket.sh
    │   │   ├── main.tf
    │   │   ├── outputs.tf
    │   │   ├── terraform.tfvars.example
    │   │   ├── variables.tf
    │   │   └── README.md
    │   └── prod/
    │       ├── backend.tf
    │       ├── create_state_bucket.sh
    │       ├── main.tf
    │       ├── outputs.tf
    │       ├── terraform.tfvars.example
    │       ├── test.tfvars
    │       ├── variables.tf
    │       └── README.md
    ├── modules/
    │   ├── project-services/
    │   ├── iam/
    │   ├── networking/
    │   ├── storage/
    │   ├── secret-manager/
    │   ├── database/
    │   ├── redis/
    │   ├── artifact-registry/
    │   ├── oauth/
    │   ├── agent-engine/
    │   ├── cloud-build/
    │   ├── cloud-run/
    │   └── monitoring/
    ├── scripts/
    │   ├── deploy.sh
    │   └── setup-oauth.sh
    └── README.md
```

## Module Implementation Details

### 1. Project Services Module
Enable APIs in dependency order:
- Service Usage API (serviceusage.googleapis.com)
- Cloud Resource Manager API (cloudresourcemanager.googleapis.com)
- Compute Engine API (compute.googleapis.com) - Required for VPC Connector
- VPC Access API (vpcaccess.googleapis.com)
- Cloud Storage, Secret Manager, Cloud SQL, Redis APIs
- Cloud Run API (run.googleapis.com) - V2
- Vertex AI API (aiplatform.googleapis.com) - External reference only
- Monitoring and Logging APIs

### 2. IAM Module
Create service accounts:
- `{environment}-open-webui-cloudrun-sa`: Cloud Run service
- `{environment}-open-webui-cloudbuild-sa`: Cloud Build operations
- IAM roles with least privilege principles

### 3. Networking Module
- **VPC Network**: Custom subnets
- **VPC Connector**: Mandatory for Cloud Run private access
- **Subnets**: 
  - Main: 10.0.0.0/24
  - VPC Connector: 10.8.0.0/28
- **Private Service Range**: 10.1.0.0/16
- **Firewall Rules**: Internal communication only

### 4. Secret Manager Module
Store ALL sensitive data:
- `webui-secret-key`: Application secret
- `database-password`: PostgreSQL password
- `database-url`: Complete connection string
- `redis-url`: Redis connection string
- `oauth-client-secret`: Google OAuth secret
- `external-agent-engine-id`: Agent engine resource ID

### 5. Database Module
- **Instance**: Private IP only, SSL enforced
- **Tiers**: 
  - Staging: db-f1-micro (configurable)
  - Production: db-custom-1-3840 (configurable)
- **Backup**: Automated with point-in-time recovery
- **Connection**: Via VPC Connector

### 6. Redis Module
- **Tier**: BASIC (non-persistent, cost-effective for caching)
- **Memory**: 1GB staging, 2GB production (configurable)
- **Network**: Private only via VPC
- **Purpose**: Caching only (no persistent data)

### 7. Cloud Run Module
Environment variables configuration:
```hcl
# Agent Engine (External Reference)
env {
  name = "AGENT_ENGINE_RESOURCE_ID"
  value_source {
    secret_key_ref {
      secret = google_secret_manager_secret.external_agent_engine_id.secret_id
      version = "latest"
    }
  }
}

# Database
env {
  name = "DATABASE_URL"
  value_source {
    secret_key_ref {
      secret = google_secret_manager_secret.database_url.secret_id
      version = "latest"
    }
  }
}

# Redis
env {
  name = "REDIS_URL"
  value_source {
    secret_key_ref {
      secret = google_secret_manager_secret.redis_url.secret_id
      version = "latest"
    }
  }
}

# Storage (API-based, NO volume mounting)
env {
  name = "STORAGE_PROVIDER"
  value = "s3"
}
env {
  name = "S3_BUCKET_NAME"
  value = google_storage_bucket.open_webui_data.name
}
env {
  name = "S3_ENDPOINT_URL"
  value = "https://storage.googleapis.com"
}

# OAuth
env {
  name = "ENABLE_OAUTH_SIGNUP"
  value = "true"
}
env {
  name = "OAUTH_PROVIDER"
  value = "google"
}
env {
  name = "GOOGLE_CLIENT_ID"
  value = var.oauth_client_id
}
env {
  name = "GOOGLE_CLIENT_SECRET"
  value_source {
    secret_key_ref {
      secret = google_secret_manager_secret.oauth_client_secret.secret_id
      version = "latest"
    }
  }
}
```

## Environment-Specific Configuration

### Staging Environment
- **Scaling**: Min 1, Max 1 instances
- **Resources**: Cost-optimized settings
- **Build Trigger**: Automatic on ta-main branch
- **Purpose**: Development and testing

### Production Environment
- **Scaling**: Min 1, Max 10 instances
- **Resources**: Production-grade settings
- **Build Trigger**: Manual approval required
- **Purpose**: Production workload

## Configuration Variables (terraform.tfvars.example)

Create comprehensive terraform.tfvars.example files with:
- All required variables documented
- NO sensitive data (use Secret Manager references)
- Clear comments and examples
- Environment-specific defaults

Example structure:
```hcl
# Project Configuration
project_id = "your-project-id"
region     = "us-central1"
environment = "staging"

# Resource Configuration (configurable tiers)
database_tier = "db-f1-micro"  # staging: db-f1-micro, prod: db-custom-1-3840
redis_memory_size_gb = 1       # staging: 1, prod: 2
cloud_run_cpu = "2000m"        # 2 CPUs
cloud_run_memory = "4096Mi"    # 4GB RAM

# Scaling Configuration
cloud_run_min_instances = 1    # staging: 1, prod: 1
cloud_run_max_instances = 1    # staging: 1, prod: 10

# OAuth Configuration (client secret in Secret Manager)
oauth_client_id = "your-oauth-client-id.googleusercontent.com"

# GitHub Configuration
github_connection_id = "your-github-connection"
github_repo_owner = "your-github-username"
github_repo_name = "your-repo-name"

# Agent Engine Configuration (external reference)
agent_engine_project_id = "external-project-id"
agent_engine_location = "us-central1"
# agent_engine_resource_name stored in Secret Manager

# Optional
agent_engine_custom_url = ""  # For testing only
```

## Cloud Build Configuration

Create cloudbuild.yaml with:
- **Timeout**: 600 seconds (10 minutes)
- **Machine Type**: e2-standard-2
- **Build Steps**: Docker build, push, deploy
- **Environment Substitutions**: Staging vs production
- **Manual Production Trigger**: Approval required

## Important Constraints and Considerations

### What NOT to Do
- **NO volume mounting** for Cloud Storage (API-based only)
- **NO vulnerability scanning** in Artifact Registry (cost optimization)
- **NO public IPs** for Cloud SQL or Redis
- **NO secrets in terraform.tfvars** files
- **NO agent engine deployment** (external reference only)
- **NO Redis persistence** (BASIC tier sufficient for caching)

### Critical Dependencies
1. **Prerequisites**: All items in prerequisites.md must be completed first
2. **OAuth**: Consent screen must be manually configured
3. **VPC Connector**: Must exist before Cloud Run deployment
4. **Secrets**: Must be in Secret Manager before Cloud Run
5. **Build Images**: Cloud Build must run before Cloud Run deployment

### Naming Convention
- Resources: `{environment}-{project-name}-{resource-name}`
- Labels: Include application, environment, managed-by tags
- Buckets: `{project-id}-{purpose}-{environment}`

### Cost Optimization
- Environment-appropriate resource sizing
- Auto-scaling to zero for Cloud Run
- BASIC Redis tier for caching
- Storage lifecycle policies
- Build machine optimization

## Validation Requirements

Each module must include:
- Input validation for all variables
- Output values for resource references
- Proper dependencies between resources
- Error handling for common issues
- Documentation for all variables and outputs

## Success Criteria

The configuration should:
1. **Deploy successfully** in both staging and production
2. **Pass all security requirements** (private networking, secrets management)
3. **Integrate properly** with all external services (OAuth, Agent Engine)
4. **Scale appropriately** per environment
5. **Follow best practices** for Terraform and GCP
6. **Be cost-optimized** for the intended workload
7. **Include comprehensive documentation** and examples

## Additional Requirements

- Include comprehensive README files for each environment
- Create validation scripts for testing
- Implement proper state management with GCS backend
- Add monitoring and alerting configurations
- Include deployment automation scripts
- Document troubleshooting procedures

**Remember**: Security is paramount. NEVER store secrets in code or tfvars files. Use Secret Manager for ALL sensitive data and implement proper secret injection in Cloud Run.