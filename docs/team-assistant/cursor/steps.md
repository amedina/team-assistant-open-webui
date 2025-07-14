# Terraform Implementation Steps for Open WebUI on Google Cloud Platform

This document provides a comprehensive step-by-step plan for implementing the Terraform configuration to deploy Open WebUI on Google Cloud Platform. The implementation follows a modular approach with separate environments for staging and production.

## Prerequisites

**⚠️ IMPORTANT**: Before starting any implementation steps, you MUST complete all prerequisites listed in [`docs/prerequisites.md`](./prerequisites.md). This includes:

- Google Cloud Platform setup and configuration
- Local development environment setup
- External dependencies configuration
- Network and security planning
- Resource quota verification

Do not proceed with the implementation steps until all prerequisites are validated and completed.

## Overview

The deployment will be organized in the following directory structure:

```
deployment/
├── cloudbuild.yaml
├── README.md
├── run_cloud_build.sh
└── terraform
    ├── environments
    │   ├── prod
    │   │   ├── backend.tf
    │   │   ├── create_state_bucket.sh
    │   │   ├── main.tf
    │   │   ├── outputs.tf
    │   │   ├── README.md
    │   │   ├── terraform.tfvars
    │   │   ├── terraform.tfvars.example
    │   │   ├── test.tfvars
    │   │   └── variables.tf
    │   └── staging
    │       ├── backend.tf
    │       ├── create_state_bucket.sh
    │       ├── main.tf
    │       ├── outputs.tf
    │       ├── README.md
    │       ├── terraform.tfvars
    │       ├── terraform.tfvars.example
    │       └── variables.tf
    ├── modules
    │   ├── artifact-registry
    │   ├── cloud-build
    │   ├── cloud-run
    │   ├── database
    │   ├── iam
    │   ├── monitoring
    │   ├── networking
    │   ├── oauth
    │   ├── project-services
    │   ├── redis
    │   ├── secret-manager
    │   └── storage
    ├── README.md
    └── scripts
        ├── deploy.sh
        └── setup-oauth.sh
```

## Implementation Steps

### Step 1: Prerequisites and Project Setup

**Objective**: Complete all prerequisites and set up the Google Cloud Project for Terraform deployment

**Prerequisites**: 
Before starting this step, ensure you have completed ALL prerequisites listed in [`docs/prerequisites.md`](./prerequisites.md). This includes:
- Google Cloud Project setup with billing enabled
- Required APIs enabled
- Local development environment configured (gcloud CLI, Terraform, Git)
- Authentication setup
- External dependencies configured (Vertex AI Agent Engine, OAuth consent screen, GitHub access)
- Network and security requirements planned
- Resource quotas verified

**Tasks**:
1. **Validate Prerequisites**: Confirm all items in the prerequisites checklist are completed
2. **Verify Environment**: Test your setup using the validation commands from prerequisites.md
3. **Project Configuration**: Ensure your Google Cloud Project is properly configured
4. **Authentication Test**: Verify authentication is working correctly
5. **API Verification**: Confirm all required APIs are enabled and accessible

**Validation Commands**:
```bash
# Verify authentication
gcloud auth list
gcloud config get-value project

# Test API access
gcloud services list --enabled

# Verify Terraform installation
terraform version

# Test basic permissions
gcloud projects describe $(gcloud config get-value project)
```

**Deliverables**:
- All prerequisites from `docs/prerequisites.md` completed ✓
- Project with enabled APIs ✓
- Configured local development environment ✓
- Authentication setup ✓
- Prerequisites validation completed ✓

**Files to create**:
- `deployment/README.md` - Overall deployment documentation
- `terraform/README.md` - Terraform-specific documentation

**Important**: Do not proceed to Step 2 until all prerequisites are validated and working correctly.

### Step 2: Terraform State Management Setup

**Objective**: Create and configure remote state storage using Google Cloud Storage with proper locking and encryption

**Tasks**:
1. Create Cloud Storage buckets for Terraform state (one for staging, one for production)
2. Configure bucket versioning and lifecycle policies
3. Set up appropriate IAM permissions for state bucket access
4. Enable state locking and encryption
5. Create backend configuration files for each environment
6. Implement state backup and recovery procedures

**Implementation Details**:
- Buckets should be created manually or via a bootstrap script before Terraform initialization
- Use bucket naming convention: `{project-id}-terraform-state-{environment}`
- Enable versioning for state file recovery
- Configure lifecycle rules to manage old state versions (keep last 10 versions, delete after 90 days)
- Enable uniform bucket-level access for security
- Use encryption at rest and in transit
- Implement state locking to prevent concurrent modifications

**Security Requirements**:
- Enable bucket versioning for state recovery
- Configure lifecycle policies to manage costs
- Use least privilege IAM for state bucket access

**Files to create**:
- `terraform/environments/staging/create_state_bucket.sh`
- `terraform/environments/prod/create_state_bucket.sh`
- `terraform/environments/staging/backend.tf`
- `terraform/environments/prod/backend.tf`

**Backend Configuration Example**:
```hcl
terraform {
  backend "gcs" {
    bucket = "your-project-terraform-state-staging"
    prefix = "terraform/state"
    # State locking is automatically enabled with GCS backend
  }
}
```

**State Bucket Creation Script Example**:
```bash
#!/bin/bash
PROJECT_ID="your-project-id"
ENVIRONMENT="staging"
BUCKET_NAME="${PROJECT_ID}-terraform-state-${ENVIRONMENT}"

gsutil mb -p ${PROJECT_ID} -c STANDARD -l us-central1 gs://${BUCKET_NAME}
gsutil versioning set on gs://${BUCKET_NAME}
gsutil lifecycle set lifecycle.json gs://${BUCKET_NAME}
```

### Step 3: Enable APIs and Create Project Services Module

**Objective**: Enable required Google Cloud APIs and create a reusable module for API management

**Tasks**:
1. Enable all required APIs for the project
2. Create the project-services module structure
3. Define variables for project ID and required services
4. Implement google_project_service resources with proper dependencies
5. Add outputs for enabled services
6. Include dependency management for service enablement order
7. Add service usage API for monitoring

**Files to create**:
- `terraform/modules/project-services/main.tf`
- `terraform/modules/project-services/variables.tf`
- `terraform/modules/project-services/outputs.tf`

**Key Services to Enable** (in dependency order):
- Service Usage API (serviceusage.googleapis.com)
- Cloud Resource Manager API (cloudresourcemanager.googleapis.com)
- IAM Service Account Credentials API (iamcredentials.googleapis.com)
- Compute Engine API (compute.googleapis.com) - Required for VPC Connector
- VPC Access API (vpcaccess.googleapis.com) - Required for Cloud Run VPC connectivity
- Cloud Storage API (storage.googleapis.com)
- Secret Manager API (secretmanager.googleapis.com)
- Cloud SQL Admin API (sqladmin.googleapis.com)
- Memorystore for Redis API (redis.googleapis.com)
- Artifact Registry API (artifactregistry.googleapis.com)
- Cloud Build API (cloudbuild.googleapis.com)
- Cloud Run API (run.googleapis.com) - Must use v2
- Vertex AI API (aiplatform.googleapis.com) - For external agent engine reference only
- Cloud Monitoring API (monitoring.googleapis.com)
- Cloud Logging API (logging.googleapis.com)

**Important Notes**:
- Services must be enabled in the correct order due to dependencies
- Some services may take time to propagate, add appropriate delays
- Vertex AI API is only for referencing external agent engine resources, not for deployment

### Step 4: Create IAM Module and Set Up Service Accounts

**Objective**: Create IAM module and configure service accounts with least privilege access

**Tasks**:
1. Create the IAM module structure
2. Create service accounts for different components:
   - Cloud Run service account
   - Cloud Build service account
   - Terraform deployment service account
3. Define IAM roles and bindings with least privilege principles
4. Implement workload identity configuration
5. Create custom roles if needed for specific permissions
6. Set up proper IAM bindings for all services
7. Create outputs for service account emails and keys

**Files to create**:
- `terraform/modules/iam/main.tf`
- `terraform/modules/iam/variables.tf`
- `terraform/modules/iam/outputs.tf`

**Service Accounts to Create**:
- `{environment}-open-webui-cloudrun-sa`: For Cloud Run service
- `{environment}-open-webui-cloudbuild-sa`: For Cloud Build operations
- `{environment}-open-webui-terraform-sa`: For Terraform deployment operations

**Naming Convention**: `{environment}-{project-name}-{resource-name}`
- Environment: staging, prod
- Project Name: open-webui
- Resource Name: specific resource identifier

**Resource Labels**: All resources should include consistent labels for management and cost tracking:
```hcl
default_labels = {
  application = "open-webui"
  environment = var.environment  # "staging" or "prod"
  managed-by  = "terraform"
}
```

**IAM Roles and Permissions**:

**Cloud Run Service Account Roles**:
- `roles/aiplatform.user` - Access to Vertex AI (for external agent engine reference)
- `roles/storage.objectUser` - Access to Cloud Storage buckets
- `roles/cloudsql.client` - Access to Cloud SQL database
- `roles/redis.editor` - Access to Redis instance
- `roles/secretmanager.secretAccessor` - Access to Secret Manager secrets

**Cloud Build Service Account Roles**:
- `roles/run.admin` - Deploy to Cloud Run
- `roles/iam.serviceAccountUser` - Act as service accounts
- `roles/artifactregistry.writer` - Push images to Artifact Registry
- `roles/storage.admin` - Access to build artifacts
- `roles/cloudbuild.builds.builder` - Build operations

**Security Considerations**:
- Use least privilege access principles
- Implement workload identity where possible
- Avoid using service account keys when possible
- Use conditional IAM bindings where appropriate

### Step 5: Create Networking Module and Set Up VPC Infrastructure

**Objective**: Create networking module and set up VPC networking for private services with VPC Connector

**Tasks**:
1. Create the networking module structure
2. Create VPC network and subnets
3. Configure private service networking for Cloud SQL and Redis
4. Create VPC Connector for Cloud Run to access private services
5. Set up firewall rules for secure communication
6. Configure Cloud NAT for outbound internet access
7. Enable private Google access
8. Implement network security best practices

**Files to create**:
- `terraform/modules/networking/main.tf`
- `terraform/modules/networking/variables.tf`
- `terraform/modules/networking/outputs.tf`

**Network Components**:
- VPC network with custom subnets
- VPC Connector for Cloud Run (essential for private service access)
- Private service connection for Cloud SQL and Redis
- Firewall rules for secure communication
- Cloud NAT for outbound internet access
- Private Google access configuration

**VPC Connector Configuration**:
- **Purpose**: Enables Cloud Run to connect to private services (Cloud SQL, Redis)
- **IP Range**: Dedicated /28 subnet for VPC Connector (e.g., 10.8.0.0/28)
- **Machine Type**: e2-micro for cost optimization
- **Min/Max Instances**: 1-2 instances for staging, 2-10 instances for production
- **Location**: Same region as Cloud Run service

**Network Architecture**:
- **Main Subnet**: 10.0.0.0/24 for general resources
- **VPC Connector Subnet**: 10.8.0.0/28 for VPC Connector
- **Private Service Range**: 10.1.0.0/16 for managed services
- **Secondary Ranges**: For future expansion if needed

**Security Configuration**:
- Private Google access enabled
- Firewall rules for internal communication only
- No external IP addresses for private resources
- Secure communication between all components

**Important Notes**:
- VPC Connector is mandatory for Cloud Run to access Cloud SQL and Redis
- VPC Connector subnet must not overlap with other subnets
- Proper firewall rules are essential for security

### Step 6: Create Storage Module and Set Up Cloud Storage

**Objective**: Create storage module and set up Cloud Storage buckets for application data

**Tasks**:
1. Create the storage module structure
2. Create primary data bucket for Open WebUI application data
3. Configure bucket policies and lifecycle rules
4. Set up IAM permissions for bucket access
5. Implement versioning and backup strategies
6. Configure CORS settings for web access
7. Set up bucket notifications if needed

**Files to create**:
- `terraform/modules/storage/main.tf`
- `terraform/modules/storage/variables.tf`
- `terraform/modules/storage/outputs.tf`

**Storage Components**:
- Primary data bucket with lifecycle policies
- Bucket IAM bindings for service account access
- Lifecycle rules for cost optimization (transition to Nearline after 90 days)
- CORS configuration for web application access
- Uniform bucket-level access for security

**Important Clarification - NO Volume Mounting**:
- **Cloud Run does NOT support direct GCS bucket mounting as volumes**
- Cloud Storage integration is achieved through:
  - Environment variables (GCS_BUCKET_NAME, STORAGE_PROVIDER=gcs)
  - Google Cloud Storage client libraries
  - Service account permissions for API access
  - Application-level integration, not filesystem mounting

**Storage Configuration**:
- **Bucket Naming**: `{environment}-{project-name}-data-{unique-suffix}` (follows naming convention)
- **Storage Class**: STANDARD for frequently accessed data
- **Lifecycle Policy**: Transition to NEARLINE after 90 days
- **Versioning**: Enabled for data protection
- **Uniform Bucket Access**: Enabled for security
- **Public Access**: Disabled (private bucket)

**Environment Variables for Cloud Run**:
```hcl
env {
  name  = "STORAGE_PROVIDER"
  value = "s3"
}

env {
  name  = "S3_BUCKET_NAME"
  value = google_storage_bucket.open_webui_data.name
}

env {
  name  = "S3_ENDPOINT_URL"
  value = "https://storage.googleapis.com"
}
```

**Security and Access**:
- Service account-based access only
- No public access or anonymous users
- Proper IAM bindings for least privilege access

### Step 7: Create Secret Manager Module and Set Up Secure Secret Management

**Objective**: Create secret manager module and set up secure secret management for sensitive data

**Tasks**:
1. Create the secret manager module structure
2. Create Secret Manager secrets for all sensitive data
3. Configure secret access permissions
4. Set up secret rotation policies where applicable
5. Integrate with Cloud Run for secure secret injection
6. Implement secret versioning and backup

**Files to create**:
- `terraform/modules/secret-manager/main.tf`
- `terraform/modules/secret-manager/variables.tf`
- `terraform/modules/secret-manager/outputs.tf`

**Secrets to Create**:
- `webui-secret-key`: Open WebUI application secret key
- `database-password`: PostgreSQL database password
- `database-url`: PostgreSQL connection string with SSL configuration
- `redis-url`: Redis connection string for Open WebUI
- `oauth-client-secret`: Google OAuth client secret
- `redis-auth-string`: Redis authentication string (if AUTH enabled)
- `external-agent-engine-id`: Reference to external agent engine resource ID

**Secret Configuration**:
- **Replication**: Automatic replication across regions
- **Versioning**: Enabled for all secrets
- **Access Control**: Least privilege IAM bindings
- **Rotation**: Manual rotation for most secrets, automatic where supported

**Security Best Practices**:
- **Never store secrets in tfvars files or environment variables**
- Use Secret Manager for ALL sensitive data
- Implement proper secret injection methods in Cloud Run
- Use secret versions for rollback capabilities

**Cloud Run Secret Injection Example**:
```hcl
env {
  name = "WEBUI_SECRET_KEY"
  value_source {
    secret_key_ref {
      secret  = google_secret_manager_secret.webui_secret_key.secret_id
      version = "latest"
    }
  }
}
```

**Important Notes**:
- Secrets must be created before Cloud Run deployment
- Secret Manager integration requires proper IAM permissions
- Use secret versions for safe updates and rollbacks
- External agent engine resource ID is stored as a secret for security
- External agent engine resource name should be configured in terraform.tfvars, e.g.:
  `agent_engine_resource_name = "projects/dummy-agentic/locations/us-central1/reasoningEngines/432248807204323328"`

### Step 8: Create Database Module and Set Up Cloud SQL PostgreSQL

**Objective**: Create database module and set up Cloud SQL PostgreSQL instance with private networking

**Tasks**:
1. Create the database module structure
2. Create Cloud SQL PostgreSQL instance with private IP
3. Configure database settings and flags for optimal performance
4. Set up automated backups and point-in-time recovery
5. Create database and user with proper permissions
6. Configure private IP and VPC network connectivity
7. Implement SSL enforcement and security best practices
8. Set up connection pooling configuration
9. Configure database initialization scripts

**Files to create**:
- `terraform/modules/database/main.tf`
- `terraform/modules/database/variables.tf`
- `terraform/modules/database/outputs.tf`

**Database Components**:
- Cloud SQL PostgreSQL instance (version 14 or later)
- Database and user creation with secure password from Secret Manager
- Automated backup configuration with point-in-time recovery
- Private IP configuration with VPC network integration
- SSL enforcement for secure connections
- Database flags for performance optimization
- Connection pooling setup

**Database Configuration**:
- **Instance Tier**: 2 GB RAM for both staging and production (configurable in terraform.tfvars)
- **Storage**: SSD with automatic increase enabled
- **Backup**: Daily backups at 2 AM UTC with 7-day retention
- **High Availability**: Enabled for production, disabled for staging
- **Private IP**: Only private IP, no public IP access
- **SSL**: Required for all connections
- **Database Flags**: Optimized for Open WebUI workload

**Security Configuration**:
- Private IP only (no public access)
- SSL/TLS encryption enforced
- Database password stored in Secret Manager
- VPC network integration for secure access
- Authorized networks restricted to VPC

**Connection Configuration**:
- Database URL constructed with private IP
- Connection through VPC Connector from Cloud Run
- SSL mode required
- Connection pooling recommended

**PostgreSQL Connection String Format**:
```
postgresql://username:password@host:port/database?sslmode=require
```

**DATABASE_URL Construction Example**:
```hcl
# Store the complete DATABASE_URL in Secret Manager
resource "google_secret_manager_secret_version" "database_url" {
  secret      = google_secret_manager_secret.database_url.id
  secret_data = "postgresql://${google_sql_user.open_webui_user.name}:${random_password.database_password.result}@${google_sql_database_instance.open_webui_db.private_ip_address}:5432/${google_sql_database.open_webui_database.name}?sslmode=require"
}
```

**Environment Variable for Cloud Run**:
```hcl
env {
  name = "DATABASE_URL"
  value_source {
    secret_key_ref {
      secret  = google_secret_manager_secret.database_url.secret_id
      version = "latest"
    }
  }
}
```

### Step 9: Create Redis Module and Set Up Memorystore for Redis

**Objective**: Create redis module and set up Memorystore for Redis for caching (non-persistent)

**Tasks**:
1. Create the redis module structure
2. Create Redis instance with BASIC tier (non-persistent)
3. Configure memory size and Redis version for caching workload
4. Set up private network connectivity through VPC
5. Configure Redis settings optimized for caching
6. Implement monitoring and alerting
7. Configure eviction policies for cache management

**Files to create**:
- `terraform/modules/redis/main.tf`
- `terraform/modules/redis/variables.tf`
- `terraform/modules/redis/outputs.tf`

**Redis Components**:
- Memorystore Redis instance (BASIC tier - non-persistent)
- Private network configuration
- Redis configuration parameters optimized for caching
- Monitoring and alerting setup
- Eviction policies for memory management

**Redis Configuration for Caching**:
- **Tier**: BASIC (non-persistent, cost-effective for caching)
- **Memory Size**: 1GB for staging, 2GB for production
- **Redis Version**: 6.x or 7.x (latest stable)
- **Network**: Private network with VPC integration
- **Auth**: Disabled for simplicity (private network provides security)
- **Persistence**: Disabled (BASIC tier doesn't support persistence)

**Cache-Specific Settings**:
- **maxmemory-policy**: allkeys-lru (evict least recently used keys)
- **timeout**: 0 (no client timeout for persistent connections)
- **tcp-keepalive**: 300 (keep connections alive)
- **maxclients**: 10000 (sufficient for expected load)

**Important Notes**:
- **Redis is used ONLY for caching, not for persistent data storage**
- BASIC tier is sufficient as data loss is acceptable for cache
- No backup or persistence configuration needed
- Cost-optimized for caching workload
- All persistent data is stored in Cloud SQL PostgreSQL

**Network Integration**:
- Private IP only (no public access)
- VPC network integration for secure access
- Access through VPC Connector from Cloud Run
- Firewall rules for internal communication only

**Redis URL Construction Format**:
```
redis://host:port
```

**REDIS_URL Construction Example**:
```hcl
# Store the complete REDIS_URL in Secret Manager
resource "google_secret_manager_secret_version" "redis_url" {
  secret      = google_secret_manager_secret.redis_url.id
  secret_data = "redis://${google_redis_instance.open_webui_redis.host}:${google_redis_instance.open_webui_redis.port}"
}
```

**Environment Variable for Cloud Run**:
```hcl
env {
  name = "REDIS_URL"
  value_source {
    secret_key_ref {
      secret  = google_secret_manager_secret.redis_url.secret_id
      version = "latest"
    }
  }
}
```

**Monitoring Configuration**:
- Memory usage alerts
- Connection count monitoring
- Cache hit/miss ratio tracking
- Performance metrics collection

### Step 10: Create Artifact Registry Module and Set Up Container Registry

**Objective**: Create artifact registry module and set up container registry for Docker images

**Tasks**:
1. Create the artifact registry module structure
2. Create Artifact Registry repository for Docker images
3. Configure repository settings and policies
4. Set up IAM permissions for push/pull access
5. Implement cleanup policies for cost management
6. Configure repository for multi-environment usage

**Files to create**:
- `terraform/modules/artifact-registry/main.tf`
- `terraform/modules/artifact-registry/variables.tf`
- `terraform/modules/artifact-registry/outputs.tf`

**Registry Components**:
- Docker repository for Open WebUI images
- IAM bindings for Cloud Build and Cloud Run access
- Cleanup policies for image lifecycle management
- Multi-environment image tagging strategy

**Repository Configuration**:
- **Format**: Docker
- **Location**: Same region as other resources
- **Repository ID**: open-webui
- **Description**: Container registry for Open WebUI images
- **Immutable Tags**: Disabled for flexibility

**Important Note - NO Vulnerability Scanning**:
- **Vulnerability scanning is NOT configured in this setup**
- This is intentional to reduce complexity and costs
- Security scanning can be added later if required
- Focus is on functional deployment first

**Cleanup Policies**:
- Keep last 10 versions of each image
- Delete untagged images after 7 days
- Keep production images indefinitely
- Clean up staging images after 30 days

**IAM Configuration**:
- Cloud Build service account: `roles/artifactregistry.writer`
- Cloud Run service account: `roles/artifactregistry.reader`
- Terraform service account: `roles/artifactregistry.admin`

**Image Tagging Strategy**:
- **Staging**: `staging-{build-number}` or `staging-latest`
- **Production**: `production-{version}` or `production-latest`
- **Development**: `dev-{branch-name}`
- **Shared Images**: Same image used for both staging and production

### Step 11: Create OAuth Module and Set Up Google OAuth Integration

**Objective**: Create oauth module and set up Google OAuth integration for user authentication

**Tasks**:
1. Create the oauth module structure
2. Set up OAuth client credentials using Terraform
3. Configure OAuth redirect URIs for Cloud Run
4. Implement OAuth environment variables for Cloud Run
5. Set up OAuth IAM permissions
6. Store OAuth client secret in Secret Manager

**Files to create**:
- `terraform/modules/oauth/main.tf`
- `terraform/modules/oauth/variables.tf`
- `terraform/modules/oauth/outputs.tf`

**OAuth Components**:
- OAuth client credentials (configured manually in Google Cloud Console)
- OAuth consent screen reference
- OAuth redirect URI configuration
- OAuth environment variables for Cloud Run
- OAuth client secret in Secret Manager

**OAuth Configuration**:
- **Provider**: Google OAuth 2.0
- **Scopes**: email, profile, openid
- **Redirect URI**: `{cloud-run-url}/auth/callback`
- **Client Type**: Web application
- **Authorized Domains**: Cloud Run domain

**Prerequisites**: 
OAuth consent screen must be configured as described in [`docs/prerequisites.md`](./prerequisites.md) before proceeding with this step.

**Environment Variables for Cloud Run**:
```hcl
env {
  name  = "ENABLE_OAUTH_SIGNUP"
  value = "true"
}

env {
  name  = "OAUTH_PROVIDER"
  value = "google"
}

env {
  name  = "GOOGLE_CLIENT_ID"
  value = var.oauth_client_id  # Configured in terraform.tfvars
}

env {
  name = "GOOGLE_CLIENT_SECRET"
  value_source {
    secret_key_ref {
      secret  = google_secret_manager_secret.oauth_client_secret.secret_id
      version = "latest"
    }
  }
}

env {
  name  = "OAUTH_SCOPES"
  value = "openid email profile"
}

env {
  name  = "OAUTH_REDIRECT_URI"
  value = "${google_cloud_run_service.open_webui.status[0].url}/auth/callback"
}
```

**Security Considerations**:
- OAuth client secret stored in Secret Manager
- Redirect URIs restricted to Cloud Run domains
- Proper scope configuration for minimal access
- OAuth consent screen properly configured

**Important Notes**:
- OAuth module must be deployed before Cloud Run module
- OAuth client ID is required for Cloud Run environment variables
- Manual OAuth consent screen setup must be completed as per prerequisites.md before this step

### Step 12: Create Agent Engine Integration Module

**Objective**: Create agent engine integration module for Vertex AI Agent Engine environment variables

**Tasks**:
1. Create the agent engine integration module structure
2. Configure environment variables for Vertex AI Agent Engine
3. Set up authentication options (service account JSON vs workload identity)
4. Implement agent engine configuration management
5. Add optional custom URL for testing
6. Configure agent engine credentials and project settings

**Files to create**:
- `terraform/modules/agent-engine/main.tf`
- `terraform/modules/agent-engine/variables.tf`
- `terraform/modules/agent-engine/outputs.tf`

**Agent Engine Components**:
- Environment variables for agent engine configuration
- Authentication setup (service account or workload identity)
- Project and location configuration
- Reasoning engine ID configuration
- Optional custom URL for testing

**Core Agent Engine Configuration Variables**:
- `ENABLE_AGENT_ENGINE=true` - Boolean flag to enable/disable the Agent Engine functionality
- `AGENT_ENGINE_PROJECT_ID` - Google Cloud Project ID where the Agent Engine is deployed
- `AGENT_ENGINE_LOCATION` - Google Cloud location/region for the Agent Engine (e.g., "us-central1")
- `AGENT_ENGINE_REASONING_ENGINE_ID` - The unique identifier for the Reasoning Engine instance

**Authentication Options (Choose One)**:

**Option 1: Service Account JSON (Development/Testing)**:
- `AGENT_ENGINE_SERVICE_ACCOUNT_JSON` - JSON string containing the service account credentials

**Option 2: Workload Identity Federation (Production - Recommended)**:
- `AGENT_ENGINE_WORKLOAD_IDENTITY_PROVIDER` - Workload Identity Provider for external authentication
- `AGENT_ENGINE_WORKLOAD_IDENTITY_SERVICE_ACCOUNT` - Service account email for Workload Identity

**Option 3: Default Credentials**:
- No additional environment variables needed when running on GCP with default credentials

**Optional Configuration**:
- `AGENT_ENGINE_CUSTOM_URL` - Custom URL for local testing or alternative Agent Engine endpoints (overrides the default GCP Vertex AI URL)

**Environment Variables for Cloud Run**:
```hcl
# Core Agent Engine Configuration
env {
  name  = "ENABLE_AGENT_ENGINE"
  value = "true"
}

env {
  name  = "AGENT_ENGINE_PROJECT_ID"
  value = var.agent_engine_project_id  # Configured in terraform.tfvars
}

env {
  name  = "AGENT_ENGINE_LOCATION"
  value = var.agent_engine_location  # Configured in terraform.tfvars
}

env {
  name = "AGENT_ENGINE_REASONING_ENGINE_ID"
  value_source {
    secret_key_ref {
      secret  = google_secret_manager_secret.external_agent_engine_id.secret_id
      version = "latest"
    }
  }
}

# Optional: Custom URL for testing
env {
  name  = "AGENT_ENGINE_CUSTOM_URL"
  value = var.agent_engine_custom_url  # Optional, configured in terraform.tfvars
}
```

**Important Notes**:
- Agent Engine integration is for referencing external agent engine resources only
- The agent engine must be deployed separately before this configuration
- Authentication method should be chosen based on deployment environment
- Service account JSON is recommended for development/testing only
- Workload Identity Federation is recommended for production deployments
- Custom URL is optional and primarily for local testing scenarios

### Step 13: Create Cloud Build Module and Set Up CI/CD Pipeline

**Objective**: Create cloud build module and set up CI/CD pipeline with Cloud Build and 10-minute timeout

**Tasks**:
1. Create the cloud build module structure
2. Create Cloud Build triggers for staging and production
3. Configure GitHub integration
4. Set up build substitutions and variables
5. Implement approval workflows for production
6. Configure notifications and monitoring
7. Set build timeout to 10 minutes (600 seconds)
8. Configure early build execution for faster deployments

**Files to create**:
- `terraform/modules/cloud-build/main.tf`
- `terraform/modules/cloud-build/variables.tf`
- `terraform/modules/cloud-build/outputs.tf`

**Build Components**:
- Staging trigger (ta-main branch)
- Production trigger (release tags)
- IAM permissions for Cloud Build
- Notification configurations
- Build timeout configuration (10 minutes)

**Build Configuration**:
- **Timeout**: 600 seconds (10 minutes)
- **Machine Type**: e2-standard-2 for faster builds
- **Disk Size**: 100GB for build artifacts
- **Substitutions**: Environment-specific variables
- **Approval**: Manual approval for production builds

**Build Process**:
1. **Early Execution**: Cloud Build should be moved as early as possible in the deployment
2. **Image Promotion**: Same image is promoted from staging to production (no rebuild)
3. **Manual Trigger**: Production deployment requires manual trigger to promote staging image
4. **Build Artifacts**: Images stored in Artifact Registry with environment-specific tags

**Important Notes**:
- **Cloud Build step should be moved early** because Cloud Run can't start without images
- Build timeout set to 10 minutes to handle Open WebUI build complexity
- Same image promoted from staging to production (no rebuild)
- Production deployment requires manual approval/trigger

### Step 13: Create Cloud Run Module and Deploy Open WebUI Application

**Objective**: Create cloud run module and deploy Open WebUI application on Cloud Run V2

**Tasks**:
1. Create the cloud run module structure
2. Create Cloud Run V2 service configuration
3. Set up environment variables for all integrations (Agent Engine, OAuth, Database, Redis, Storage)
4. Configure VPC Connector for private service access
5. Implement auto-scaling settings (environment-specific)
6. Set up health checks and startup checks (240 seconds, 5 retries)
7. Configure resource specifications (1 CPU, 4 GB RAM)
8. Set up traffic allocation and revisions
9. Configure secret injection from Secret Manager

**Files to create**:
- `terraform/modules/cloud-run/main.tf`
- `terraform/modules/cloud-run/variables.tf`
- `terraform/modules/cloud-run/outputs.tf`

**Cloud Run V2 Configuration**:
- **API Version**: Cloud Run V2 (using google_cloud_run_v2_service resource)
- **CPU**: 2 CPU (2000m) - configurable in terraform.tfvars
- **Memory**: 4 GB (4096Mi) - configurable in terraform.tfvars
- **VPC Connector**: Required for private service access
- **Execution Environment**: Second generation (gen2)

**Environment-Specific Scaling**:
- **Staging**: Min 1 instance, Max 1 instance (no scaling)
- **Production**: Min 1 instance, Max 10 instances (auto-scaling)

**Health and Startup Checks**:
- **Startup Probe**: 240 seconds timeout, 5 retries (Open WebUI takes time to start)
- **Liveness Probe**: HTTP check on `/health` endpoint
- **Readiness Probe**: HTTP check on `/ready` endpoint
- **Port**: 8080 (Open WebUI default port)

**VPC Connector Integration**:
- **VPC Connector**: Reference from networking module
- **Egress**: Private ranges only (for database and Redis access)
- **Ingress**: All traffic (public access with OAuth)

**Environment Variables Configuration**:
```hcl
# Agent Engine Configuration (External Reference Only)
env {
  name = "AGENT_ENGINE_RESOURCE_ID"
  value_source {
    secret_key_ref {
      secret  = google_secret_manager_secret.external_agent_engine_id.secret_id
      version = "latest"
    }
  }
}

# Database Configuration
env {
  name = "DATABASE_URL"
  value_source {
    secret_key_ref {
      secret  = google_secret_manager_secret.database_url.secret_id
      version = "latest"
    }
  }
}

# Redis Configuration
env {
  name  = "REDIS_HOST"
  value = google_redis_instance.open_webui_redis.host
}

env {
  name  = "REDIS_PORT"
  value = tostring(google_redis_instance.open_webui_redis.port)
}

# Storage Configuration
env {
  name  = "STORAGE_PROVIDER"
  value = "s3"
}

env {
  name  = "S3_BUCKET_NAME"
  value = google_storage_bucket.open_webui_data.name
}

env {
  name  = "S3_ENDPOINT_URL"
  value = "https://storage.googleapis.com"
}

# OAuth Configuration
env {
  name  = "OAUTH_PROVIDER"
  value = "google"
}

env {
  name  = "OAUTH_CLIENT_ID"
  value = var.oauth_client_id  # Configured in terraform.tfvars
}

# Secret Manager Integration
env {
  name = "WEBUI_SECRET_KEY"
  value_source {
    secret_key_ref {
      secret  = google_secret_manager_secret.webui_secret_key.secret_id
      version = "latest"
    }
  }
}
```

**Important Notes**:
- **NO volume mounting for Cloud Storage** (API-based integration only)
- **Cloud Run V2 required** for enhanced features and VPC connectivity
- **VPC Connector mandatory** for private service access
- **Health checks configured for 240 seconds** due to Open WebUI startup time
- **Same image promoted from staging to production** (no rebuild)
- **All secrets injected via Secret Manager**, never in environment variables directly

**Security Configuration**:
- Service account with least privilege access
- VPC Connector for private network access
- Secret Manager for sensitive data
- OAuth for user authentication
- No public access without authentication

### Step 14: Create Monitoring Module and Set Up Comprehensive Monitoring

**Objective**: Create monitoring module and set up comprehensive monitoring and alerting for Open WebUI

**Tasks**:
1. Create the monitoring module structure
2. Configure Cloud Monitoring dashboards for Open WebUI metrics
3. Set up alerting policies for critical issues
4. Implement log-based metrics and alerts
5. Configure notification channels (email, Slack, etc.)
6. Set up uptime checks for Cloud Run service
7. Implement cost monitoring and budget alerts
8. Configure SLI/SLO monitoring
9. Set up performance monitoring

**Files to create**:
- `terraform/modules/monitoring/main.tf`
- `terraform/modules/monitoring/variables.tf`
- `terraform/modules/monitoring/outputs.tf`

**Monitoring Components**:
- Custom dashboards for Open WebUI application metrics
- Alert policies for critical issues (downtime, errors, performance)
- Log-based metrics and alerts for application logs
- Uptime monitoring for external availability
- Cost alerts and budget monitoring
- SLI/SLO configuration for service reliability
- Integration with Cloud Run, Cloud SQL, and Redis metrics

**Dashboard Configuration**:
- **Application Metrics**: Request count, response time, error rate
- **Infrastructure Metrics**: CPU, memory, network usage
- **Database Metrics**: Connection count, query performance
- **Redis Metrics**: Cache hit/miss ratio, memory usage
- **Cost Metrics**: Daily/monthly spend tracking

**Alert Policies**:
- **Critical**: Service downtime, database connectivity issues
- **Warning**: High response time, high error rate, resource usage
- **Info**: Cost threshold exceeded, unusual traffic patterns

**Uptime Monitoring**:
- **External Checks**: HTTP checks from multiple regions
- **Frequency**: Every 1 minute for production, 5 minutes for staging
- **Timeout**: 10 seconds
- **Failure Threshold**: 3 consecutive failures

**Cost Monitoring**:
- **Budget Alerts**: 50%, 80%, 100% of monthly budget
- **Anomaly Detection**: Unusual spending patterns
- **Resource Optimization**: Recommendations for cost savings

### Step 15: Staging Environment Configuration

**Objective**: Create staging environment configuration with cost-optimized settings

**Tasks**:
1. Create staging-specific variable definitions
2. Configure backend for staging state
3. Create main.tf that calls all modules in correct order
4. Set up staging-specific outputs
5. Create example tfvars file (without secrets)
6. Document staging deployment process
7. Configure environment-specific scaling (1 instance max 1)

**Files to create**:
- `terraform/environments/staging/main.tf`
- `terraform/environments/staging/variables.tf`
- `terraform/environments/staging/outputs.tf`
- `terraform/environments/staging/terraform.tfvars.example`
- `terraform/environments/staging/README.md`

**Staging Configuration**:
- **Cloud Run**: Min 1 instance, Max 1 instance (no auto-scaling)
- **Cloud SQL**: db-f1-micro instance tier
- **Redis**: 1GB BASIC tier (non-persistent)
- **Resource Limits**: 1 CPU, 4 GB RAM for Cloud Run
- **Cost Optimization**: Minimal resource allocation
- **Security**: Standard security settings (not production-grade)

**Environment-Specific Settings**:
- **Auto-scaling**: Disabled (min=1, max=1)
- **High Availability**: Disabled for cost savings
- **Backup Retention**: 7 days (shorter than production)
- **Monitoring**: Basic monitoring and alerting
- **Build Triggers**: Automatic deployment from ta-main branch

**Important Security Notes**:
- **Never store secrets in terraform.tfvars files**
- All sensitive data must be in Secret Manager
- Use terraform.tfvars.example as template only
- Actual secrets are injected via Secret Manager during deployment

### Step 16: Production Environment Configuration

**Objective**: Create production environment configuration with enhanced security and scaling

**Tasks**:
1. Create production-specific variable definitions
2. Configure backend for production state
3. Create main.tf that calls all modules in correct order
4. Set up production-specific outputs
5. Create example tfvars and test tfvars files (without secrets)
6. Document production deployment process
7. Implement additional security measures
8. Configure environment-specific scaling (1 instance min, 10 instances max)

**Files to create**:
- `terraform/environments/prod/main.tf`
- `terraform/environments/prod/variables.tf`
- `terraform/environments/prod/outputs.tf`
- `terraform/environments/prod/terraform.tfvars.example`
- `terraform/environments/prod/test.tfvars`
- `terraform/environments/prod/README.md`

**Production Configuration**:
- **Cloud Run**: Min 1 instance, Max 10 instances (auto-scaling enabled)
- **Cloud SQL**: db-custom-1-3840 instance tier (1 vCPU, 3.75 GB RAM)
- **Redis**: 2GB BASIC tier (non-persistent, optimized for production load)
- **Resource Limits**: 1 CPU, 4 GB RAM for Cloud Run
- **High Availability**: Enabled where supported
- **Security**: Production-grade security settings

**Environment-Specific Settings**:
- **Auto-scaling**: Enabled (min=1, max=10 instances)
- **High Availability**: Enabled for Cloud SQL
- **Backup Retention**: 30 days (longer than staging)
- **Monitoring**: Comprehensive monitoring and alerting
- **Build Triggers**: Manual deployment approval required
- **SSL/TLS**: Enforced for all connections

**Production Security Enhancements**:
- **Secret Manager**: All sensitive data stored securely
- **VPC Security**: Private networking for all backend services
- **IAM**: Least privilege access principles
- **Audit Logging**: Enabled for all critical resources
- **Network Security**: Firewall rules for internal communication only

**Deployment Process**:
- **Manual Approval**: Production deployments require manual trigger
- **Same Image**: Uses the same image built for staging
- **Blue-Green**: Traffic allocation for safe deployments
- **Rollback**: Quick rollback capabilities

**Important Security Notes**:
- **Never store secrets in terraform.tfvars files**
- All sensitive data must be in Secret Manager
- Use terraform.tfvars.example as template only
- Production secrets are managed separately from staging
- Manual approval required for all production changes

### Step 17: Cloud Build Configuration

**Objective**: Create Cloud Build configuration for CI/CD with 10-minute timeout

**Tasks**:
1. Create cloudbuild.yaml for building and deploying
2. Configure build steps for Docker image creation
3. Set up deployment steps for Cloud Run
4. Implement environment-specific substitutions
5. Configure build triggers and approvals
6. Set build timeout to 10 minutes (600 seconds)
7. Configure early build execution for faster deployments

**Files to create**:
- `deployment/cloudbuild.yaml`

**Build Configuration**:
- **Timeout**: 600 seconds (10 minutes) for Open WebUI build complexity
- **Multi-step build process**: Docker build, test, push, deploy
- **Docker image building**: With Agent Engine integration
- **Artifact Registry push**: Store images for both environments
- **Cloud Run deployment**: Environment-specific configurations
- **Build machine**: e2-standard-2 for faster builds

**cloudbuild.yaml Structure**:
```yaml
timeout: 600s  # 10 minutes
options:
  machineType: 'E2_STANDARD_2'
  diskSizeGb: 100

steps:
  # Build Docker image
  - name: 'gcr.io/cloud-builders/docker'
    args: [
      'build',
      '--build-arg', 'ENABLE_AGENT_ENGINE=true',
      '-t', '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPOSITORY}/${_IMAGE}:${_TAG}',
      '.'
    ]
    timeout: 480s  # 8 minutes for build

  # Push to Artifact Registry
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPOSITORY}/${_IMAGE}:${_TAG}']
    timeout: 120s  # 2 minutes for push

  # Deploy to Cloud Run (conditional)
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: 'gcloud'
    args: [
      'run', 'deploy', '${_SERVICE_NAME}',
      '--image', '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPOSITORY}/${_IMAGE}:${_TAG}',
      '--region', '${_REGION}',
      '--platform', 'managed'
    ]
```

**Important Notes**:
- **Build timeout set to 10 minutes** to handle Open WebUI complexity
- **Same image used for staging and production** environments
- **Early execution**: Cloud Build moved early in deployment process
- **Manual trigger required** for production deployments

### Step 18: Deployment Scripts

**Objective**: Create utility scripts for deployment and setup

**Tasks**:
1. Create deployment automation script
2. Create OAuth setup script
3. Create Cloud Build execution script
4. Implement error handling and logging
5. Add validation and pre-flight checks
6. Create environment switching scripts

**Files to create**:
- `terraform/scripts/deploy.sh`
- `terraform/scripts/setup-oauth.sh`
- `deployment/run_cloud_build.sh`

**Script Features**:
- Automated deployment workflow
- Environment validation (staging/production)
- OAuth configuration assistance
- Error handling and rollback capabilities
- Pre-flight checks for prerequisites
- Secret Manager integration validation

**deploy.sh Features**:
- Environment selection (staging/production)
- Prerequisites validation
- Terraform plan and apply automation
- Secret Manager secret creation
- OAuth setup verification
- Post-deployment validation

### Step 19: Documentation and Examples

**Objective**: Create comprehensive documentation and examples

**Tasks**:
1. Update all README files with detailed instructions
2. Create terraform.tfvars.example files with all variables (no secrets)
3. Document deployment procedures
4. Create troubleshooting guides
5. Add security best practices documentation
6. Document the recommended step reordering

**Documentation Components**:
- Step-by-step deployment guides
- Variable reference documentation
- Troubleshooting and FAQ sections
- Security configuration guides (Secret Manager usage)
- Cost optimization recommendations
- Environment-specific configuration examples

**Important Documentation Notes**:
- **Never include secrets in example files**
- All sensitive data examples should reference Secret Manager
- Include clear warnings about security best practices
- Document the correct step ordering and dependencies

### Step 20: Testing and Validation

**Objective**: Implement testing and validation procedures

**Tasks**:
1. Create test configurations for both environments
2. Implement validation scripts
3. Set up integration tests
4. Create rollback procedures
5. Document testing workflows
6. Validate all security configurations

**Testing Components**:
- Terraform plan validation
- Resource creation verification
- Application deployment testing
- Security configuration validation (Secret Manager, VPC, etc.)
- Performance testing procedures
- Environment-specific testing (staging vs production scaling)

**Validation Checklist**:

**Prerequisites Validation** (from [`docs/prerequisites.md`](./prerequisites.md)):
- [ ] All prerequisites from prerequisites.md completed and validated
- [ ] Google Cloud Project setup with billing enabled
- [ ] All required APIs enabled
- [ ] Local development environment configured
- [ ] Authentication setup working
- [ ] External dependencies configured (Vertex AI Agent Engine, OAuth consent screen)

**Implementation Validation**:
- [ ] All APIs enabled and accessible
- [ ] VPC Connector properly configured
- [ ] Secret Manager secrets created and accessible
- [ ] OAuth configuration working
- [ ] Cloud Run V2 deployment successful
- [ ] Database connectivity through VPC Connector
- [ ] Redis connectivity and caching working
- [ ] Cloud Storage integration functional
- [ ] Monitoring and alerting configured
- [ ] Build timeout set to 10 minutes
- [ ] Health checks configured (240 seconds, 5 retries)
- [ ] Environment-specific scaling working (staging: 1-1, production: 1-10)
- [ ] Same image deployment for both environments

## Implementation Order and Dependencies

The implementation follows a carefully designed order where each step includes both module creation and implementation to ensure proper dependencies and successful deployment:

### Phase 1: Foundation (Steps 1-4)
- **Step 1**: Prerequisites and Project Setup
- **Step 2**: Terraform State Management Setup
- **Step 3**: Enable APIs and Create Project Services Module
- **Step 4**: Create IAM Module and Set Up Service Accounts

**Dependencies**: Each step depends on the previous one. APIs must be enabled before IAM setup. Each step creates the necessary module and implements the functionality together.

### Phase 2: Infrastructure (Steps 5-9)
- **Step 5**: Create Networking Module and Set Up VPC Infrastructure
- **Step 6**: Create Storage Module and Set Up Cloud Storage
- **Step 7**: Create Secret Manager Module and Set Up Secure Secret Management
- **Step 8**: Create Database Module and Set Up Cloud SQL PostgreSQL
- **Step 9**: Create Redis Module and Set Up Memorystore for Redis

**Dependencies**: Networking must be set up before database and Redis. Secret Manager must be configured before other services that need secrets. Each step creates the module and implements the infrastructure component together.

### Phase 3: Application Services (Steps 10-14)
- **Step 10**: Create Artifact Registry Module and Set Up Container Registry
- **Step 11**: Create OAuth Module and Set Up Google OAuth Integration
- **Step 12**: Create Agent Engine Integration Module
- **Step 13**: Create Cloud Build Module and Set Up CI/CD Pipeline
- **Step 14**: Create Cloud Run Module and Deploy Open WebUI Application

**Dependencies**: 
- Artifact Registry must exist before Cloud Build
- OAuth must be configured before Cloud Run (needs OAuth client ID)
- Cloud Build must be early because Cloud Run needs images
- Cloud Run depends on all previous infrastructure
- Each step creates the module and implements the service together

### Phase 4: Operations (Step 15)
- **Step 15**: Create Monitoring Module and Set Up Comprehensive Monitoring

**Dependencies**: Monitoring should be set up after all services are deployed. This step creates the monitoring module and implements monitoring together.

### Phase 5: Environment Configuration (Steps 16-17)
- **Step 16**: Staging Environment Configuration
- **Step 17**: Production Environment Configuration

**Dependencies**: Environment configurations use all modules created in previous steps, so they come after all module development and implementation.

### Phase 6: CI/CD and Automation (Steps 18-19)
- **Step 18**: Cloud Build Configuration
- **Step 19**: Deployment Scripts

**Dependencies**: Build configuration and scripts depend on all infrastructure being defined and modules being created.

### Phase 7: Documentation and Validation (Steps 20-21)
- **Step 20**: Documentation and Examples
- **Step 21**: Testing and Validation

**Dependencies**: Documentation and testing come last to ensure all components are properly documented and validated.

## Critical Dependencies

### Must Come Before Cloud Run Deployment (Step 14):
1. **Create OAuth Module and Set Up Google OAuth Integration (Step 11)** - Cloud Run needs OAuth client ID
2. **Create Secret Manager Module and Set Up Secure Secret Management (Step 7)** - Cloud Run needs secrets for configuration
3. **Create Networking Module and Set Up VPC Infrastructure (Step 5)** - Cloud Run needs VPC connectivity for private services
4. **Create Agent Engine Integration Module (Step 12)** - Cloud Run needs agent engine environment variables
5. **Create Cloud Build Module and Set Up CI/CD Pipeline (Step 13)** - Cloud Run needs container images

### Must Come Before Production Environment (Step 17):
1. **All infrastructure and application services (Steps 5-15)** - Production needs all services to be created and configured
2. **Staging Environment Configuration (Step 16)** - Test in staging before production

### Security Dependencies:
1. **Create Secret Manager Module and Set Up Secure Secret Management (Step 7)** must come before any service that needs secrets
2. **Create IAM Module and Set Up Service Accounts (Step 4)** must come before any service creation
3. **Create Networking Module and Set Up VPC Infrastructure (Step 5)** must come before private services (database, Redis)

## Key Considerations

### Security (Critical Requirements)
- **NEVER store secrets in tfvars files** - All sensitive data must be in Secret Manager
- **Use Secret Manager for ALL sensitive data** including database passwords, OAuth secrets, API keys
- **Use proper secret injection methods** in Cloud Run via Secret Manager integration
- **Implement least privilege access principles** for all service accounts
- **Use VPC Connector for private service access** (Cloud SQL, Redis)
- **Enable private networking** for all backend services (no public IPs)
- **Configure OAuth properly** with consent screen and proper scopes

### Cloud Run V2 Requirements
- **Must use Cloud Run V2 API** for enhanced features and VPC connectivity
- **Resource specifications**: 2 CPU, 4 GB RAM (configurable in terraform.tfvars)
- **Health checks**: 240 seconds timeout, 5 retries (Open WebUI startup time)
- **VPC Connector**: Mandatory for private service access
- **Environment-specific scaling**:
  - **Staging**: Min 1 instance, Max 1 instance (no scaling)
  - **Production**: Min 1 instance, Max 10 instances (auto-scaling)

### Build and Deployment
- **Build timeout**: 10 minutes (600 seconds) for Open WebUI complexity
- **Same image for both environments**: Staging image promoted to production
- **Manual production deployment**: Requires manual trigger/approval
- **Early Cloud Build execution**: Move Cloud Build early because Cloud Run needs images
- **No vulnerability scanning**: Intentionally disabled in Artifact Registry

### Database and Caching
- **Redis for caching only**: Non-persistent, BASIC tier sufficient
- **No Redis persistence needed**: All persistent data in Cloud SQL PostgreSQL
- **VPC connectivity**: Both database and Redis accessible via VPC Connector only
- **Private IPs only**: No public access to backend services

### Vertex AI Integration
- **External agent engine reference only**: Do NOT deploy agent engine in this config
- **Resource ID storage**: External agent engine resource ID stored in Secret Manager
- **API enablement**: Vertex AI API enabled only for referencing external resources

### Cost Optimization
- **Environment-appropriate sizing**:
  - **Staging**: 2GB RAM database, 1GB Redis (configurable in terraform.tfvars)
  - **Production**: 2GB RAM database, 2GB Redis (configurable in terraform.tfvars)
- **Auto-scaling to zero**: Cloud Run scales down when not in use
- **Storage lifecycle policies**: Transition to Nearline after 90 days
- **No vulnerability scanning**: Reduces costs and complexity
- **BASIC Redis tier**: Cost-effective for caching workload

### Reliability and Performance
- **Health checks configured**: 240 seconds timeout for Open WebUI startup
- **Startup probes**: 5 retries with appropriate timeouts
- **VPC Connector redundancy**: Multiple instances for availability
- **Database backups**: Automated with appropriate retention
- **Monitoring and alerting**: Comprehensive coverage for all services

### Network Architecture
- **VPC Connector mandatory**: Required for Cloud Run to access private services
- **Private service networking**: Cloud SQL and Redis on private IPs only
- **Firewall rules**: Internal communication only
- **No public database access**: Security through network isolation

### Development Workflow
- **Branch Strategy**: Development happens on `ta-main` branch
- **Staging Deployment**: Automatic deployment to staging when commits are pushed/merged to `ta-main` branch
- **Production Deployment**: Manual trigger required to promote staging image to production
- **Image Promotion**: Same image tested in staging is promoted to production (no rebuild)
- **Testing Flow**: Test in staging environment, then manually trigger production deployment
- **Secret Separation**: Different secrets for staging and production environments

## Success Criteria

Each step should be considered complete when:
1. **Prerequisites validated** (for Step 1): All items in [`docs/prerequisites.md`](./prerequisites.md) are completed and verified
2. **Files created**: All required files are created and properly configured
3. **Terraform validation**: Terraform plan executes without errors
4. **Resource creation**: Resources are created successfully
5. **Integration tests**: Integration tests pass
6. **Documentation**: Documentation is updated
7. **Security requirements**: Security requirements are met

## Next Steps After Implementation

1. **Security Hardening**: Implement additional security measures
2. **Performance Optimization**: Fine-tune resource configurations
3. **Monitoring Enhancement**: Add custom metrics and dashboards
4. **Disaster Recovery**: Implement backup and recovery procedures
5. **Multi-Region Deployment**: Expand to multiple regions for high availability

This step-by-step approach ensures a systematic and reliable implementation of the Open WebUI Terraform configuration on Google Cloud Platform.
