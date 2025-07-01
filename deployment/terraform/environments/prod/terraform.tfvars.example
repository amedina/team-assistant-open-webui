# Google Cloud Configuration
project_id = "your-gcp-project-id"
region     = "us-central1"
zone       = "us-central1-a"

# Storage Configuration
storage_bucket_name = "your-project-id-openwebui-prod-storage"

# Source Code Repository
repository_url = "https://github.com/your-org/your-repo"
github_owner   = "your-org"
github_repo    = "your-repo"

# OAuth Configuration (create these in Google Cloud Console)
google_oauth_client_id     = "your-oauth-client-id.apps.googleusercontent.com"
google_oauth_client_secret = "your-oauth-client-secret"

# Application Configuration
webui_name = "Open WebUI"

# Custom Domain (optional)
custom_domain = "openwebui.your-domain.com"

# Notification Email (required for production)
notification_email = "alerts@your-domain.com"

# Production Database Configuration
database_tier           = "db-g1-small"
database_disk_size      = 100
database_max_disk_size  = 1000
enable_high_availability = true

# Production Redis Configuration
redis_memory_size_gb = 8
redis_tier          = "STANDARD_HA"

# Production Cloud Run Configuration
cloud_run_cpu_limit     = "4"
cloud_run_memory_limit  = "8Gi"
cloud_run_min_instances = 3
cloud_run_max_instances = 50
container_concurrency   = 100
timeout_seconds        = 900
uvicorn_workers        = "4"

# Backup Configuration
enable_backup          = true
backup_retention_days  = 30

# Custom Labels
labels = {
  application = "open-webui"
  environment = "production"
  team        = "your-team"
  cost-center = "your-cost-center"
  managed-by  = "terraform"
} 