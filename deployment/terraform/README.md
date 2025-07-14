# Open WebUI Terraform Deployment Configuration

This repository contains a comprehensive Terraform configuration for deploying Open WebUI on Google Cloud Platform (GCP) with production-ready security, scalability, and monitoring features.

## 🏗️ Architecture Overview

The deployment creates a secure, scalable architecture with the following components:

- **Cloud Run V2** - Main application hosting (2 CPU, 4GB RAM)
- **Cloud SQL PostgreSQL** - Primary database with private IP
- **Redis Memorystore** - Session caching (BASIC tier)
- **Cloud Storage** - File storage with lifecycle policies
- **Secret Manager** - Secure credential management
- **VPC Connector** - Private service connectivity (mandatory)
- **Artifact Registry** - Container image storage
- **Cloud Build** - CI/CD pipeline with 10-minute timeout
- **Cloud Monitoring** - Comprehensive observability

## 📋 Prerequisites

Before deploying, ensure you have:

1. **GCP Project** with billing enabled
2. **Google Cloud SDK** installed and authenticated
3. **Terraform 1.5+** installed
4. **External Agent Engine** already deployed
5. **OAuth Application** configured in Google Cloud Console
6. **GitHub Repository** connected to Cloud Build

## 🚀 Quick Start

### 1. Clone and Navigate
```bash
git clone <repository-url>
cd deployment/terraform/environments/staging
```

### 2. Configure Variables
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 3. Initialize and Deploy
```bash
terraform init
terraform plan
terraform apply
```

## 📁 Directory Structure

```
deployment/terraform/
├── environments/
│   ├── staging/          # Staging environment
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars.example
│   │   └── backend.tf
│   └── prod/             # Production environment
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars.example
│       └── backend.tf
├── modules/
│   ├── project-services/ # API enablement
│   ├── iam/             # Service accounts & roles
│   ├── networking/      # VPC, subnets, connector
│   ├── storage/         # Cloud Storage buckets
│   ├── secret-manager/  # Secret management
│   ├── database/        # Cloud SQL PostgreSQL
│   ├── redis/           # Memorystore Redis
│   ├── artifact-registry/ # Container registry
│   ├── oauth/           # OAuth configuration
│   ├── agent-engine/    # External agent engine
│   ├── cloud-build/     # CI/CD pipeline
│   ├── cloud-run/       # Main application
│   └── monitoring/      # Observability
├── scripts/
│   ├── deploy.sh        # Deployment script
│   ├── setup-oauth.sh   # OAuth setup
│   └── run_cloud_build.sh # Cloud Build trigger
├── cloudbuild.yaml      # Cloud Build configuration
└── README.md           # This file
```

## 🔧 Module Overview

### Core Infrastructure Modules

| Module | Description | Key Features |
|--------|-------------|--------------|
| **project-services** | API enablement | Required APIs, dependency ordering |
| **iam** | Identity & Access | Service accounts, least privilege |
| **networking** | Network setup | VPC, subnets, VPC Connector |
| **storage** | File storage | Cloud Storage, lifecycle policies |
| **secret-manager** | Credential management | All secrets, multi-region replication |

### Application Modules

| Module | Description | Key Features |
|--------|-------------|--------------|
| **database** | PostgreSQL database | Private IP, SSL, automated backups |
| **redis** | Caching layer | BASIC tier, private connectivity |
| **artifact-registry** | Container images | Private registry, cleanup policies |
| **cloud-run** | Main application | V2 API, VPC Connector, auto-scaling |
| **monitoring** | Observability | Dashboards, alerts, logging |

### External Integration Modules

| Module | Description | Key Features |
|--------|-------------|--------------|
| **oauth** | Google OAuth | External consent screen reference |
| **agent-engine** | AI/ML integration | External Vertex AI endpoint |
| **cloud-build** | CI/CD pipeline | 10-min timeout, staging/prod triggers |

## 🔐 Security Features

### Network Security
- **Private IP only** for database and Redis
- **VPC Connector** for private service access (mandatory)
- **SSL enforcement** for all database connections
- **Private container registry** with IAM controls

### Secret Management
- **All sensitive data** stored in Secret Manager
- **Multi-region replication** for high availability
- **Least privilege access** for service accounts
- **No secrets in Terraform state** or code

### IAM & Access Control
- **Service accounts** with minimal required permissions
- **Developer access** controls for staging environment
- **Audit logging** for all resource access
- **Role-based access** controls

## 🌍 Environment Configuration

### Staging Environment
- **Auto-deployment** on main branch push
- **Minimal resources** for cost optimization
- **1 instance** (no auto-scaling)
- **db-f1-micro** database tier
- **1GB Redis** BASIC tier

### Production Environment
- **Manual deployment** via version tags
- **High availability** configuration
- **1-10 instances** with auto-scaling
- **db-n1-standard-2** database tier
- **4GB Redis** BASIC tier

## 📊 Monitoring & Observability

### Cloud Monitoring
- **Service health** dashboards
- **Resource utilization** metrics
- **Application performance** monitoring
- **Custom alerts** for critical issues

### Cloud Logging
- **Structured logging** from all services
- **Centralized log aggregation**
- **Log-based metrics** and alerts
- **Audit trail** for all operations

### Health Checks
- **HTTP health endpoints** for all services
- **Startup probes** with 240s timeout
- **Liveness checks** with automatic restart
- **Readiness probes** for traffic routing

## 🔄 CI/CD Pipeline

### Cloud Build Configuration
- **10-minute timeout** as specified
- **e2-standard-2** machine type for faster builds
- **Staging**: Auto-deploy on main branch push
- **Production**: Manual deploy on version tags

### Build Steps
1. **Environment validation** and API checks
2. **Docker image build** with multi-stage
3. **Image push** to Artifact Registry
4. **Cloud Run deployment** with rollback
5. **Health check verification**
6. **Cleanup** of old images

## 🛠️ Deployment Instructions

### First-Time Setup

1. **Configure OAuth** (manual step required):
   ```bash
   ./scripts/setup-oauth.sh
   ```

2. **Set up Terraform backend**:
   ```bash
   gsutil mb gs://your-project-terraform-state
   ```

3. **Initialize and apply**:
   ```bash
   cd environments/staging
   terraform init
   terraform apply
   ```

### Subsequent Deployments

Use Cloud Build for automated deployments:
```bash
# Staging: Push to main branch
git push origin main

# Production: Create version tag
git tag v1.0.0
git push origin v1.0.0
```

## 🔧 Configuration Variables

### Required Variables
- `project_id` - GCP project ID
- `oauth_client_id` - Google OAuth client ID
- `oauth_client_secret` - Google OAuth client secret
- `agent_engine_project_id` - External Agent Engine project
- `agent_engine_resource_name` - Agent Engine resource ID

### Optional Variables
- `custom_domain` - Custom domain for the service
- `developer_emails` - Developer access for staging
- `enable_monitoring` - Enable monitoring (default: true)
- `notification_channels` - Alert notification channels

## 🚨 Troubleshooting

### Common Issues

1. **VPC Connector Errors**
   - Verify VPC Connector is properly configured
   - Check subnet ranges don't overlap
   - Ensure proper firewall rules

2. **Secret Manager Issues**
   - Verify all secrets are created
   - Check IAM permissions for service accounts
   - Ensure multi-region replication is enabled

3. **Cloud Build Failures**
   - Check build logs in Cloud Console
   - Verify GitHub connection is active
   - Ensure proper substitution variables

4. **Database Connection Issues**
   - Verify private IP configuration
   - Check VPC peering for Cloud SQL
   - Ensure SSL certificates are valid

### Support Resources
- [Google Cloud Documentation](https://cloud.google.com/docs)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Project Issue Tracker](https://github.com/your-org/repo/issues)

## 📈 Cost Optimization

### Staging Environment
- **Minimal instance sizing** (1 instance)
- **f1-micro database** tier
- **1GB Redis** BASIC tier
- **Auto-scaling disabled**

### Production Environment
- **Right-sized instances** (1-10 scale)
- **Optimized database** tier
- **Lifecycle policies** for storage
- **Monitoring-based scaling**

## 🛡️ Security Best Practices

1. **Never commit secrets** to version control
2. **Use Secret Manager** for all sensitive data
3. **Enable audit logging** for all resources
4. **Implement least privilege** access
5. **Regularly rotate credentials**
6. **Monitor for security events**

## 🔄 Maintenance

### Regular Tasks
- **Update Terraform modules** quarterly
- **Rotate secrets** according to policy
- **Review access logs** monthly
- **Update container images** for security patches

### Backup Strategy
- **Database backups** automated daily
- **Terraform state** backed up to Cloud Storage
- **Container images** retained for 30 days
- **Configuration backups** versioned in Git

## 📞 Support

For deployment issues or questions:
- Check this README first
- Review module documentation
- Check Cloud Console logs
- Contact the infrastructure team

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test changes in staging
4. Submit a pull request
5. Ensure all checks pass

## 📄 License

This configuration is provided under the [MIT License](LICENSE).

---

**Security Note**: This configuration handles sensitive data through Secret Manager and follows security best practices. Always review the security implications before deploying to production environments. 