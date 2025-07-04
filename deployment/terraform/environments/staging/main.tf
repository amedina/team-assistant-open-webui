terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Local values for environment-specific configuration
locals {
  environment = "staging"
  
  common_labels = merge(var.labels, {
    environment = local.environment
    terraform   = "true"
  })
}

# Generate random secrets
resource "random_password" "webui_secret_key" {
  length  = 64
  special = true
}

resource "random_password" "db_password" {
  length  = 32
  special = true
}

# Enable required APIs
module "project_services" {
  source     = "../../modules/project-services"
  project_id = var.project_id
}

# Networking
module "networking" {
  source      = "../../modules/networking"
  project_id  = var.project_id
  region      = var.region
  environment = local.environment
  
  vpc_connector_cidr        = var.vpc_connector_cidr
  database_subnet_cidr      = var.database_subnet_cidr
  vpc_connector_min_instances = var.vpc_connector_min_instances
  vpc_connector_max_instances = var.vpc_connector_max_instances
  
  depends_on = [module.project_services]
}

# IAM and Service Accounts
module "iam" {
  source                = "../../modules/iam"
  project_id           = var.project_id
  environment          = local.environment
  storage_bucket_name  = var.storage_bucket_name
  
  depends_on = [module.project_services]
}

# Cloud Storage
module "storage" {
  source                = "../../modules/storage"
  project_id           = var.project_id
  region               = var.region
  environment          = local.environment
  bucket_name          = var.storage_bucket_name
  service_account_email = module.iam.cloud_run_service_account_email
  labels               = local.common_labels
  
  # Staging-specific settings
  force_destroy      = true   # Allow deletion in staging
  enable_versioning  = true   # Enable versioning
  
  depends_on = [module.project_services]
}

# Cloud SQL PostgreSQL
module "database" {
  source                        = "../../modules/database"
  project_id                   = var.project_id
  region                       = var.region
  environment                  = local.environment
  database_tier                = var.database_tier
  disk_size_gb                 = var.database_disk_size
  database_password            = random_password.db_password.result
  network_id                   = module.networking.vpc_network_id
  private_service_connection_id = module.networking.private_service_connection_id
  
  # Staging-specific settings (production-like but more cost-effective)
  high_availability             = false  # Disable HA for staging
  deletion_protection          = false  # Allow deletion in staging
  enable_point_in_time_recovery = true   # Enable PITR for testing
  
  depends_on = [module.networking]
}

# Memorystore Redis
module "redis" {
  source      = "../../modules/redis"
  project_id  = var.project_id
  region      = var.region
  environment = local.environment
  network_id  = module.networking.vpc_network_id
  
  # Staging-specific settings
  memory_size_gb = var.redis_memory_size_gb
  tier          = var.redis_tier
  
  depends_on = [module.networking]
}

# Artifact Registry
module "artifact_registry" {
  source        = "../../modules/artifact-registry"
  project_id    = var.project_id
  region        = var.region
  environment   = local.environment
  repository_id = var.artifact_repository_name
  labels        = local.common_labels
  
  depends_on = [module.project_services]
}

# Cloud Build (temporarily disabled - will enable after core infrastructure is deployed)
module "cloud_build" {
  source                    = "../../modules/cloud-build"
  project_id               = var.project_id
  region                   = var.region
  environment              = local.environment
  repository_url           = var.repository_url
  github_owner             = var.github_owner
  github_repo              = var.github_repo
  trigger_branch           = "terraform-v1"  # Auto-deploy staging on terraform-v1 branch
  artifact_registry_url    = module.artifact_registry.repository_url
  service_account_email    = module.iam.cloud_build_service_account_email
  cloud_run_service_name   = var.cloud_run_service_name
  auto_deploy              = true   # Enable auto-deployment for staging
  enable_release_trigger   = false  # Disable release trigger for staging
  
  depends_on = [module.artifact_registry]
}

# Cloud Run Service
module "cloud_run" {
  source       = "../../modules/cloud-run"
  project_id   = var.project_id
  region       = var.region
  environment  = local.environment
  service_name = var.cloud_run_service_name
  
  # Container configuration  
  container_image = "${module.artifact_registry.repository_url}/open-webui:latest"
  container_port  = 8080
  
  # Environment variables specific to Open WebUI
  environment_variables = {
    ENV                                 = "staging"
    WEBUI_SECRET_KEY                   = random_password.webui_secret_key.result
    DATABASE_URL                       = "postgresql://openwebui:${urlencode(random_password.db_password.result)}@${module.database.private_ip_address}:5432/openwebui"
    REDIS_URL                          = "redis://${module.redis.host}:6379"
    STORAGE_PROVIDER                   = "gcs"
    GCS_BUCKET_NAME                    = module.storage.bucket_name
    GOOGLE_CLIENT_ID                   = var.google_oauth_client_id
    GOOGLE_CLIENT_SECRET               = var.google_oauth_client_secret
    ENABLE_SIGNUP                      = "true"   # Allow signup in staging for testing
    ENABLE_LOGIN_FORM                  = "true"
    ENABLE_OAUTH_SIGNUP                = "true"
    OAUTH_MERGE_ACCOUNTS_BY_EMAIL      = "true"
    WEBUI_NAME                         = "Open WebUI (Staging)"
    WEBUI_AUTH                         = "true"
    DATA_DIR                           = "/app/backend/data"
    CACHE_DIR                          = "/app/backend/cache"
    UPLOAD_DIR                         = "/app/backend/uploads"
    VECTOR_DB                          = "chroma"
    CHROMA_DATA_PATH                   = "/app/backend/data/vector_db"
    ENABLE_DIRECT_CONNECTIONS          = "true"
    UVICORN_WORKERS                    = var.uvicorn_workers
    LOG_LEVEL                          = "DEBUG"  # Debug logging for staging
    GLOBAL_LOG_LEVEL                   = "DEBUG"
  }
  
  # Resource configuration (staging sizing)
  cpu_limit     = var.cloud_run_cpu_limit
  memory_limit  = var.cloud_run_memory_limit
  min_instances = var.cloud_run_min_instances
  max_instances = var.cloud_run_max_instances
  
  # Network configuration
  vpc_connector_name = module.networking.vpc_connector_name
  
  # Service account
  service_account_email = module.iam.cloud_run_service_account_email
  labels               = local.common_labels
  
  depends_on = [
    module.database,
    module.redis,
    module.storage,
    module.networking,
    module.iam
  ]
}

# Monitoring (enabled for staging to test alerts)
module "monitoring" {
  count      = var.enable_monitoring ? 1 : 0
  source     = "../../modules/monitoring"
  project_id = var.project_id
  environment = local.environment
  
  # Monitoring targets
  cloud_run_service_name = module.cloud_run.service_name
  database_instance_id   = module.database.instance_id
  redis_instance_id      = module.redis.instance_id
  
  # Notification email
  notification_email = var.notification_email
  
  depends_on = [
    module.cloud_run,
    module.database,
    module.redis
  ]
} 