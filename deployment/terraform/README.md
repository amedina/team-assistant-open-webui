# Open WebUI Terraform Infrastructure

This repository contains Terraform configurations for deploying Open WebUI across multiple environments (dev, staging, production) on Google Cloud Platform.

## Architecture Overview

The infrastructure deploys:
- **Google Cloud Run** - Serverless container platform
- **Google Cloud Storage** - Object storage for persistent data  
- **Google Vertex AI** - AI platform for language model capabilities
- **Cloud SQL PostgreSQL** - Managed relational database
- **Memorystore Redis** - In-memory data store for caching
- **Google OAuth** - Authentication service
- **Google Service Accounts** - Identity management
- **Google Cloud Build** - CI/CD pipeline
- **Artifact Registry** - Container registry

## Directory Structure

```
terraform/
├── README.md                    # This file
├── modules/                     # Shared Terraform modules
│   ├── project-services/        # Enable GCP APIs
│   ├── networking/             # VPC, subnets, connectors
│   ├── iam/                    # Service accounts & permissions
│   ├── storage/                # Cloud Storage buckets
│   ├── database/               # Cloud SQL PostgreSQL
│   ├── redis/                  # Memorystore Redis
│   ├── artifact-registry/      # Container registry
│   ├── cloud-build/            # CI/CD pipeline
│   ├── cloud-run/              # Serverless container service
│   └── monitoring/             # Monitoring & alerting
├── environments/               # Environment-specific configurations
│   ├── staging/                # Staging environment (auto-deploy on main)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars.example
│   │   ├── outputs.tf
│   │   └── backend.tf
│   └── prod/                   # Production environment (manual deploy)
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars.example
│       ├── outputs.tf
│       └── backend.tf
└── scripts/                    # Deployment scripts
    ├── deploy.sh
    ├── destroy.sh
    └── setup-oauth.sh
```

## Prerequisites

1. **Google Cloud SDK** installed and configured
2. **Terraform** >= 1.0 installed
3. **Docker** installed (for local builds)
4. **jq** installed (for JSON processing)

## Initial Setup

### 1. Clone Repository and Navigate to Terraform Directory

```bash
git clone <repository-url>
cd terraform
```

### 2. Set Up Google Cloud Project

```bash
# Set your project ID
export PROJECT_ID="your-project-id"

# Enable required APIs
gcloud services enable \
  run.googleapis.com \
  sqladmin.googleapis.com \
  storage.googleapis.com \
  redis.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  vpcaccess.googleapis.com \
  aiplatform.googleapis.com \
  monitoring.googleapis.com \
  logging.googleapis.com \
  --project=$PROJECT_ID
```

### 3. Configure OAuth (Required)

Before deploying, you need to set up Google OAuth:

1. Go to [Google Cloud Console > APIs & Services > Credentials](https://console.cloud.google.com/apis/credentials)
2. Create OAuth 2.0 Client ID
3. Set authorized redirect URIs:
   - `https://your-domain.com/oauth/google/callback`
   - `https://your-cloud-run-url/oauth/google/callback`
4. Note down the Client ID and Client Secret

### 4. Set Up Remote State Backend (Recommended)

```bash
# Create a bucket for Terraform state
gsutil mb gs://${PROJECT_ID}-terraform-state

# Enable versioning
gsutil versioning set on gs://${PROJECT_ID}-terraform-state
```

## Environment Deployment

### Local Development

For development, run Open WebUI locally on your machine. This provides:
- Fast iteration and debugging
- No cloud costs during development  
- Direct access to logs and debugging tools

### Staging Environment

```bash
cd environments/staging

# Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply deployment
terraform apply
```

### Production Environment

```bash
cd environments/prod

# Copy and edit variables (NEVER commit terraform.tfvars with secrets)
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your production values

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply deployment (consider using -auto-approve=false for production)
terraform apply
```

## Configuration

### Required Variables

Each environment requires these variables in `terraform.tfvars`:

```hcl
project_id                 = "your-gcp-project-id"
region                    = "us-central1"
storage_bucket_name       = "your-unique-bucket-name"
repository_url           = "https://github.com/your-org/your-repo"
support_email            = "support@your-domain.com"
notification_email       = "alerts@your-domain.com"
google_oauth_client_id   = "your-oauth-client-id"
google_oauth_client_secret = "your-oauth-client-secret"
```

### Environment-Specific Sizing

- **Local**: Development environment runs on your local machine
- **Staging**: Production-like resources for testing (auto-deploy on main branch)
- **Prod**: Full production resources with high availability (manual deploy via tags)

## Deployment Scripts

Use the provided scripts for easier deployment:

```bash
# Deploy to staging (auto-deploys on main branch push)
./scripts/deploy.sh staging

# Deploy to production (manual deployment)
./scripts/deploy.sh prod

# Destroy environment (be careful!)
./scripts/deploy.sh staging --destroy
./scripts/deploy.sh prod --destroy
```

## Post-Deployment

After successful deployment:

1. **Set up OAuth consent screen** in Google Cloud Console
2. **Configure custom domain** (if using)
3. **Set up monitoring alerts**
4. **Configure backups** (automated via Terraform)
5. **Test the application** using the provided URLs

## Monitoring and Maintenance

- **Logs**: Available in Google Cloud Logging
- **Metrics**: Available in Google Cloud Monitoring
- **Alerts**: Configured automatically for critical resources
- **Backups**: Automated daily backups for database

## Security Considerations

- All secrets are managed via Terraform and stored securely
- Database is only accessible via private network
- Redis is only accessible via private network
- Cloud Run service uses service account with minimal permissions
- OAuth is properly configured for secure authentication

## Troubleshooting

### Common Issues

1. **OAuth not working**: Check redirect URIs in Google Cloud Console
2. **Database connection issues**: Verify VPC connector and private IP settings
3. **Build failures**: Check Cloud Build logs and IAM permissions
4. **Memory issues**: Adjust Cloud Run memory limits in variables

### Useful Commands

```bash
# Check Cloud Run logs
gcloud run services logs tail open-webui --region=us-central1

# Check database status
gcloud sql instances describe openwebui-db

# Check Redis status
gcloud redis instances describe openwebui-redis --region=us-central1

# Force new deployment
gcloud run deploy open-webui --image=gcr.io/PROJECT_ID/open-webui:latest
```

## Contributing

1. Make changes to modules or environment configurations
2. Test changes locally first
3. Push to main branch (auto-deploys to staging)
4. Create version tag for production deployment (manual approval required)

## Support

For issues and questions:
- Check the troubleshooting section
- Review Google Cloud logs
- Open an issue in the repository 