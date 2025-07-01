# Workflow Changes Summary: Local Development + Staging/Production Deployment

## Overview

The Terraform configuration has been updated to support a streamlined deployment workflow:

- **Local Development**: Development happens locally on your machine
- **Staging Environment**: Auto-deploys when you push to the `main` branch
- **Production Environment**: Manual deployment triggered by version tags

## What Was Removed

### Development Environment
- Deleted entire `terraform/environments/dev/` directory and all its files:
  - `main.tf`
  - `variables.tf` 
  - `outputs.tf`
  - `backend.tf`
  - `terraform.tfvars.example`

## What Was Updated

### 1. Staging Environment Configuration
**File**: `terraform/environments/staging/main.tf`

**Cloud Build Module Updates**:
```hcl
module "cloud_build" {
  # ... existing configuration ...
  github_owner             = var.github_owner
  github_repo              = var.github_repo
  trigger_branch           = "main"      # Auto-deploy staging on main branch
  auto_deploy              = true        # Enable auto-deployment for staging
  enable_release_trigger   = false       # Disable release trigger for staging
}
```

### 2. Production Environment Configuration
**File**: `terraform/environments/prod/main.tf`

**Cloud Build Module Updates**:
```hcl
module "cloud_build" {
  # ... existing configuration ...
  github_owner             = var.github_owner
  github_repo              = var.github_repo
  trigger_branch           = "main"      # Branch for building (not auto-deploying)
  auto_deploy              = false       # Disable auto-deployment for production
  enable_release_trigger   = true        # Enable release trigger for production
  release_tag_pattern      = "v*"        # Trigger on version tags (v1.0.0, v1.2.3, etc.)
}
```

### 3. Added Missing Variables
**Files**: 
- `terraform/environments/staging/variables.tf`
- `terraform/environments/prod/variables.tf`

**New Variables Added**:
```hcl
variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}
```

### 4. Updated Configuration Examples
**Files**:
- `terraform/environments/staging/terraform.tfvars.example`
- `terraform/environments/prod/terraform.tfvars.example`

**Added GitHub Configuration**:
```hcl
# Source Code Repository
repository_url = "https://github.com/your-org/your-repo"
github_owner   = "your-org"
github_repo    = "your-repo"
```

### 5. Updated Deployment Script
**File**: `terraform/scripts/deploy.sh`

**Changes**:
- Removed `dev` from valid environments
- Updated help text to explain new workflow
- Added workflow guidance in usage instructions

### 6. Updated Documentation
**Files Updated**:
- `terraform/README.md`
- `docs/team-assistant/cicd-flow-guide.md`

**Key Changes**:
- Removed all dev environment references
- Updated environment descriptions
- Clarified local development approach
- Updated deployment workflows

## New Deployment Workflow

### Local Development
```bash
# Run Open WebUI locally for development
# No cloud infrastructure needed during development
# Fast iteration and debugging
```

### Staging Deployment (Automatic)
```bash
# Make changes and commit
git add .
git commit -m "Add new feature"
git push origin main

# Result: Automatically triggers staging deployment
# → Cloud Build triggers on main branch push
# → Builds image and deploys to staging environment
# → No manual approval required
```

### Production Deployment (Manual)
```bash
# Create version tag for production release
git tag v1.2.3
git push origin v1.2.3

# Result: Creates production build but requires manual deployment
# → Cloud Build creates production-ready image
# → Manual approval required for deployment
# → Deploy using: terraform apply in prod environment
```

## Benefits of New Workflow

### 1. Cost Efficiency
- **No cloud dev environment**: Eliminates dev environment cloud costs
- **Local development**: Free local development with full debugging capabilities
- **Faster iteration**: No waiting for cloud deployments during development

### 2. Simplified Pipeline
- **Two environments**: Only staging and production cloud environments
- **Clear separation**: Local dev → Staging testing → Production
- **Reduced complexity**: Fewer environments to manage and monitor

### 3. Better Control
- **Staging auto-deploy**: Immediate feedback on main branch changes
- **Production approval**: Manual control over production deployments
- **Version control**: Clear versioning through git tags

### 4. Enhanced Security
- **Production safeguards**: Manual approval prevents accidental deployments
- **Environment isolation**: Clear separation between testing and production
- **Controlled releases**: Version tags provide clear deployment tracking

## Migration Steps

If you have existing infrastructure, follow these steps:

### 1. Backup Existing Dev Environment (Optional)
```bash
# If you want to preserve dev environment data
cd terraform/environments/dev
terraform output > dev-environment-backup.txt
```

### 2. Destroy Dev Environment (If Exists)
```bash
cd terraform/environments/dev
terraform destroy
```

### 3. Update Staging Environment
```bash
cd terraform/environments/staging
# Copy terraform.tfvars.example to terraform.tfvars
# Add github_owner and github_repo variables
# Run terraform plan to see changes
terraform plan
terraform apply
```

### 4. Update Production Environment
```bash
cd terraform/environments/prod
# Copy terraform.tfvars.example to terraform.tfvars  
# Add github_owner and github_repo variables
# Run terraform plan to see changes
terraform plan
terraform apply
```

### 5. Test New Workflow
```bash
# Test staging auto-deployment
git push origin main
# Check Cloud Build console for automatic deployment

# Test production manual deployment
git tag v1.0.0
git push origin v1.0.0
# Check Cloud Build for build creation
# Manually deploy using terraform apply
```

## Troubleshooting

### Common Issues

1. **Missing GitHub Variables**
   - **Error**: "No declaration found for var.github_owner"
   - **Solution**: Add github_owner and github_repo to terraform.tfvars

2. **Cloud Build Trigger Not Working**
   - **Error**: Push to main doesn't trigger build
   - **Solution**: Verify GitHub integration in Cloud Build console

3. **Production Auto-Deploy Enabled**
   - **Error**: Production deploys automatically
   - **Solution**: Ensure auto_deploy = false in prod environment

### Verification Commands

```bash
# Check Cloud Build triggers
gcloud builds triggers list

# Check staging service
gcloud run services describe staging-open-webui --region=us-central1

# Check production service  
gcloud run services describe prod-open-webui --region=us-central1
```

## Conclusion

The new workflow provides:
- **Local development** for fast iteration
- **Automatic staging deployment** for immediate testing
- **Manual production deployment** for controlled releases
- **Cost optimization** by eliminating dev cloud environment
- **Simplified management** with fewer environments

This approach aligns with modern DevOps practices and provides better control over your deployment pipeline. 