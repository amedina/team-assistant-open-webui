# Cloud Run V2 Migration Guide

This guide provides step-by-step instructions for migrating from Cloud Run V1 to V2 without service disruption.

## Overview of Changes

### Issues Fixed
1. **Cloud SQL Configuration Fix**: Added missing `cloudsql_instances` parameter to staging environment
2. **V2 Migration**: Migrated from `google_cloud_run_service` to `google_cloud_run_v2_service`
3. **Configuration Modernization**: Converted annotations to direct attributes

### Key Changes Made

#### 1. Resource Type Updates
- **Before**: `google_cloud_run_service`
- **After**: `google_cloud_run_v2_service`

#### 2. IAM Resources Updates
- **Before**: `google_cloud_run_service_iam_member`
- **After**: `google_cloud_run_v2_service_iam_member`

#### 3. Configuration Structure Changes
- **Removed**: `spec` level nesting
- **Flattened**: `containers` moved directly under `template`
- **Converted**: Annotations to direct attributes

#### 4. Annotation to Attribute Conversion
| V1 Annotation | V2 Attribute |
|---------------|--------------|
| `"autoscaling.knative.dev/minScale"` | `scaling.min_instance_count` |
| `"autoscaling.knative.dev/maxScale"` | `scaling.max_instance_count` |
| `"run.googleapis.com/cpu-throttling"` | `resources.cpu_idle` |
| `"run.googleapis.com/vpc-access-connector"` | `vpc_access.connector` |
| `"run.googleapis.com/vpc-access-egress"` | `vpc_access.egress` |
| `"run.googleapis.com/cloudsql-instances"` | `volumes.cloud_sql_instance` |

#### 5. Cloud SQL Configuration
- **Enhanced**: Added proper Cloud SQL Auth Proxy support with socket mounting
- **Fixed**: Missing `cloudsql_instances` in staging environment

## Migration Steps

### Prerequisites
1. **Backup Current State**: 
   ```bash
   cd deployment/terraform/environments/staging
   terraform state pull > backup-staging-state.json
   
   cd ../prod
   terraform state pull > backup-prod-state.json
   ```

2. **Verify Current Services**:
   ```bash
   # Check staging
   gcloud run services list --project=YOUR_PROJECT_ID --platform=managed
   
   # Check production
   gcloud run services list --project=YOUR_PROJECT_ID --platform=managed
   ```

### Step 1: Plan the Migration

1. **Review Changes**:
   ```bash
   cd deployment/terraform/environments/staging
   terraform plan
   ```

2. **Verify No Unexpected Changes**: The plan should show:
   - Resource recreation (expected due to resource type change)
   - Configuration updates
   - IAM policy updates

### Step 2: State Migration (Critical for Zero-Downtime)

Since we're changing resource types, we need to perform state migration to avoid service recreation:

#### For Staging Environment:
1. **Remove Old State**:
   ```bash
   cd deployment/terraform/environments/staging
   terraform state rm module.cloud_run.google_cloud_run_service.openwebui
   terraform state rm module.cloud_run.google_cloud_run_service_iam_member.public_access
   terraform state rm module.cloud_run.google_cloud_run_service_iam_member.authenticated_access
   ```

2. **Import New State**:
   ```bash
   # Import the service (adjust project and region as needed)
   terraform import module.cloud_run.google_cloud_run_v2_service.openwebui projects/YOUR_PROJECT_ID/locations/YOUR_REGION/services/staging-open-webui
   
   # Import IAM members if they exist
   terraform import module.cloud_run.google_cloud_run_v2_service_iam_member.public_access "projects/YOUR_PROJECT_ID/locations/YOUR_REGION/services/staging-open-webui roles/run.invoker allUsers"
   # OR
   terraform import module.cloud_run.google_cloud_run_v2_service_iam_member.authenticated_access "projects/YOUR_PROJECT_ID/locations/YOUR_REGION/services/staging-open-webui roles/run.invoker allAuthenticatedUsers"
   ```

3. **Verify State Migration**:
   ```bash
   terraform plan
   ```
   - Should show minimal changes (configuration updates only)
   - Should NOT show resource recreation

#### For Production Environment:
Repeat the same steps but with production resource names:
```bash
cd deployment/terraform/environments/prod
terraform state rm module.cloud_run.google_cloud_run_service.openwebui
terraform state rm module.cloud_run.google_cloud_run_service_iam_member.public_access
terraform state rm module.cloud_run.google_cloud_run_service_iam_member.authenticated_access

terraform import module.cloud_run.google_cloud_run_v2_service.openwebui projects/YOUR_PROJECT_ID/locations/YOUR_REGION/services/prod-open-webui
terraform import module.cloud_run.google_cloud_run_v2_service_iam_member.public_access "projects/YOUR_PROJECT_ID/locations/YOUR_REGION/services/prod-open-webui roles/run.invoker allUsers"
```

### Step 3: Apply Changes

1. **Apply Staging First**:
   ```bash
   cd deployment/terraform/environments/staging
   terraform apply
   ```

2. **Verify Staging**:
   ```bash
   # Check service status
   gcloud run services describe staging-open-webui --region=YOUR_REGION --project=YOUR_PROJECT_ID
   
   # Test endpoint
   curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" https://YOUR_STAGING_URL/health
   ```

3. **Apply Production**:
   ```bash
   cd deployment/terraform/environments/prod
   terraform apply
   ```

### Step 4: Verification

1. **Check Service Status**:
   ```bash
   # Should show V2 configuration
   gcloud run services describe YOUR_SERVICE_NAME --region=YOUR_REGION --project=YOUR_PROJECT_ID
   ```

2. **Verify Cloud SQL Connection**:
   ```bash
   # Check if Cloud SQL socket is mounted
   gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=YOUR_SERVICE_NAME" --limit=50
   ```

3. **Test Application**:
   - Verify database connectivity
   - Check Redis connectivity
   - Test authentication flows

## Key V2 Benefits

1. **Better Cloud SQL Integration**: Proper socket mounting with Cloud SQL Auth Proxy
2. **Cleaner Configuration**: Direct attributes instead of annotations
3. **Improved Resource Management**: Better resource limits and scaling configuration
4. **Enhanced Security**: Improved VPC and service account handling

## Rollback Plan

If issues occur, you can rollback by:

1. **Restore State**:
   ```bash
   terraform state push backup-staging-state.json
   ```

2. **Revert Configuration Changes**:
   ```bash
   git checkout HEAD~1 -- deployment/terraform/modules/cloud-run/
   ```

3. **Re-apply**:
   ```bash
   terraform apply
   ```

## Troubleshooting

### Common Issues

1. **Import Errors**: 
   - Verify resource names and project IDs
   - Check IAM permissions

2. **Service Not Found**:
   - Verify service exists in specified region
   - Check project ID

3. **State Inconsistencies**:
   - Use `terraform refresh` to sync state
   - Check for drift with `terraform plan`

### Validation Commands

```bash
# Check Cloud Run V2 service
gcloud run services describe YOUR_SERVICE --region=YOUR_REGION --project=YOUR_PROJECT_ID

# Verify Cloud SQL connection
gcloud sql instances describe YOUR_DB_INSTANCE --project=YOUR_PROJECT_ID

# Check VPC connector
gcloud compute networks vpc-access connectors describe YOUR_CONNECTOR --region=YOUR_REGION --project=YOUR_PROJECT_ID
```

## Support

For issues with this migration:
1. Check the Terraform logs for specific error messages
2. Verify GCP permissions and quotas
3. Review Cloud Run V2 documentation for additional troubleshooting steps

---

**Important**: Test this migration in a development environment first before applying to staging or production! 