# Google Internal Deployment Guide

This guide provides solutions for deploying Open WebUI internally at Google, addressing the Cloud Run to Cloud SQL connectivity issues.

## Problem Analysis

The original configuration had several connectivity issues:
1. **Mixed connectivity approaches**: Using both VPC connector and Cloud SQL Proxy annotations
2. **Direct private IP timeouts**: Network routing issues between Cloud Run and Cloud SQL
3. **Complex networking**: Unnecessary complexity for internal deployment

## Solution: Cloud SQL Proxy (Recommended)

I've updated the configuration to use **Cloud SQL Proxy** for database connections, which is the recommended approach for Google internal deployments.

### Key Changes Made

1. **Database Connection String**: 
   - **Before**: `postgresql://user:pass@PRIVATE_IP:5432/db`
   - **After**: `postgresql://user:pass@/db?host=/cloudsql/CONNECTION_NAME`

2. **Cloud Run Configuration**:
   - Uses Cloud SQL Proxy via `cloudsql-instances` annotation
   - Keeps VPC connector only for Redis access
   - Configured for Google internal access only

3. **Security Updates**:
   - Access restricted to `domain:google.com`
   - Removed public access configuration
   - Added proper firewall rules

## Deployment Steps

### 1. Apply the Updated Configuration

```bash
# Navigate to your environment
cd deployment/terraform/environments/staging  # or prod

# Initialize (if needed)
terraform init

# Plan the changes
terraform plan

# Apply the changes
terraform apply
```

### 2. Verify the Deployment

```bash
# Run the troubleshooting script
./deployment/terraform/scripts/troubleshoot-connectivity.sh staging YOUR_PROJECT_ID

# Check Cloud Run logs
gcloud run services logs tail staging-open-webui --region=us-central1

# Test the health endpoint
curl -f "https://your-service-url/health"
```

### 3. Access the Application

Since this is configured for Google internal access:
- Access from within Google's network
- Use your Google account for authentication
- The service will be available at the Cloud Run URL

## Alternative Deployment Options

### Option 1: Cloud SQL Proxy (Current/Recommended)
- **Pros**: Reliable, secure, Google-recommended
- **Cons**: Slightly more complex setup
- **Use case**: Production deployments, maximum security

### Option 2: Public IP with Authorized Networks
For simpler setup (internal testing only):

```hcl
# In database module, enable public IP
resource "google_sql_database_instance" "postgres" {
  # ... other config ...
  
  settings {
    ip_configuration {
      ipv4_enabled    = true
      private_network = var.network_id
      
      authorized_networks {
        name  = "google-internal"
        value = "YOUR_GOOGLE_OFFICE_IP_RANGE"
      }
    }
  }
}
```

### Option 3: Direct Private IP (Advanced)
If you prefer direct private IP connection:

```hcl
# DATABASE_URL format
DATABASE_URL = "postgresql://user:pass@${private_ip}:5432/db"

# Ensure proper firewall rules
resource "google_compute_firewall" "allow_db_access" {
  name    = "allow-db-access"
  network = var.network_name
  
  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }
  
  source_ranges = [var.vpc_connector_cidr]
}
```

## Troubleshooting

### Common Issues and Solutions

1. **Database Connection Timeout**
   ```bash
   # Check VPC connector status
   gcloud compute networks vpc-access connectors describe staging-openwebui-conn --region=us-central1
   
   # Check Cloud SQL instance status
   gcloud sql instances describe staging-open-webui-db
   ```

2. **Service Account Permissions**
   ```bash
   # Verify service account has Cloud SQL client role
   gcloud projects get-iam-policy YOUR_PROJECT_ID --flatten="bindings[].members" --filter="bindings.members:staging-open-webui-cloudrun@YOUR_PROJECT_ID.iam.gserviceaccount.com"
   ```

3. **VPC Connector Issues**
   ```bash
   # Check connector logs
   gcloud logging read "resource.type=vpc_access_connector" --limit=20
   
   # If stuck in DELETING state, import existing connector
   terraform import module.networking.google_vpc_access_connector.connector projects/YOUR_PROJECT_ID/locations/us-central1/connectors/staging-openwebui-conn
   ```

### Useful Commands

```bash
# Check service health
curl -f "https://your-service-url/health"

# View application logs
gcloud run services logs tail staging-open-webui --region=us-central1

# Test database connectivity (from Cloud Shell)
gcloud sql connect staging-open-webui-db --user=openwebui

# Check Redis connectivity
gcloud redis instances describe staging-open-webui-redis --region=us-central1
```

## Configuration Summary

### Updated Database Connection
- **Connection method**: Cloud SQL Proxy (Unix socket)
- **Security**: Private connection, no public IP
- **Authentication**: Service account (no explicit keys)

### Network Configuration
- **VPC**: Custom VPC with private subnets
- **VPC Connector**: For Redis access only
- **Firewall**: Allows internal communication on required ports

### Access Control
- **Internal access**: `domain:google.com`
- **Authentication**: Google OAuth
- **Network**: VPC-based isolation

## Security Benefits

1. **No public database exposure**: Cloud SQL uses private IP only
2. **Automatic credential management**: No service account keys
3. **Network isolation**: VPC-based security
4. **Google internal access**: Restricted to Google employees
5. **Audit logging**: All access is logged

## Next Steps

1. **Test the deployment** with the updated configuration
2. **Monitor performance** using Cloud Monitoring
3. **Set up alerting** for any service issues
4. **Configure backup policies** for production data
5. **Implement CI/CD** for automated deployments

## Support

If you encounter issues:
1. Run the troubleshooting script: `./scripts/troubleshoot-connectivity.sh`
2. Check the Cloud Run logs for specific error messages
3. Verify all services are in READY/RUNNING state
4. Ensure you're accessing from within Google's network 