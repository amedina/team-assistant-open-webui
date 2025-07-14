terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Configure the Google Cloud Provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# Local variables
locals {
  environment = "staging"

  # Environment-specific configurations
  staging_config = {
    min_instances                = 1
    max_instances                = 1
    database_tier                = "db-f1-micro"
    redis_memory_size_gb         = 1
    vpc_connector_max_throughput = 300
  }
}

# Enable required APIs
module "project_services" {
  source = "../../modules/project-services"

  project_id  = var.project_id
  environment = local.environment
  region      = var.region
}

# Create IAM resources
module "iam" {
  source = "../../modules/iam"

  project_id          = var.project_id
  environment         = local.environment
  region              = var.region
  storage_bucket_name = module.storage.data_bucket_name
  services_ready      = module.project_services.services_ready

  depends_on = [module.project_services]
}

# Create networking resources
module "networking" {
  source = "../../modules/networking"

  project_id                   = var.project_id
  environment                  = local.environment
  region                       = var.region
  services_ready               = module.project_services.services_ready
  vpc_connector_max_throughput = local.staging_config.vpc_connector_max_throughput

  depends_on = [module.project_services]
}

# Create storage resources
module "storage" {
  source = "../../modules/storage"

  project_id                        = var.project_id
  environment                       = local.environment
  region                            = var.region
  services_ready                    = module.project_services.services_ready
  cloud_run_service_account_email   = module.iam.cloud_run_service_account_email
  cloud_build_service_account_email = module.iam.cloud_build_service_account_email

  depends_on = [module.project_services, module.iam]
}

# Create secret manager resources
module "secret_manager" {
  source = "../../modules/secret-manager"

  project_id                        = var.project_id
  environment                       = local.environment
  region                            = var.region
  backup_region                     = var.backup_region
  services_ready                    = module.project_services.services_ready
  cloud_run_service_account_email   = module.iam.cloud_run_service_account_email
  cloud_build_service_account_email = module.iam.cloud_build_service_account_email
  developer_emails                  = var.developer_emails

  depends_on = [module.project_services, module.iam]
}

# Create database resources
module "database" {
  source = "../../modules/database"

  project_id                    = var.project_id
  environment                   = local.environment
  region                        = var.region
  services_ready                = module.project_services.services_ready
  vpc_network_id                = module.networking.vpc_network_id
  private_service_connection_id = module.networking.private_service_connection_id
  database_tier                 = local.staging_config.database_tier
  database_password_secret_id   = module.secret_manager.database_password_id
  database_url_secret_id        = module.secret_manager.database_url_id

  depends_on = [module.project_services, module.networking, module.secret_manager]
}

# Create Redis resources
module "redis" {
  source = "../../modules/redis"

  project_id                    = var.project_id
  environment                   = local.environment
  region                        = var.region
  services_ready                = module.project_services.services_ready
  vpc_network_id                = module.networking.vpc_network_id
  private_service_connection_id = module.networking.private_service_connection_id
  redis_memory_size_gb          = local.staging_config.redis_memory_size_gb
  redis_url_secret_id           = module.secret_manager.redis_url_id

  depends_on = [module.project_services, module.networking, module.secret_manager]
}

# Create Artifact Registry resources
module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id                        = var.project_id
  environment                       = local.environment
  region                            = var.region
  services_ready                    = module.project_services.services_ready
  cloud_build_service_account_email = module.iam.cloud_build_service_account_email
  cloud_run_service_account_email   = module.iam.cloud_run_service_account_email
  developer_emails                  = var.developer_emails

  depends_on = [module.project_services, module.iam]
}

# Configure OAuth (external resource reference)
module "oauth" {
  source = "../../modules/oauth"

  project_id                    = var.project_id
  environment                   = local.environment
  oauth_client_id               = var.oauth_client_id
  oauth_client_secret_value     = var.oauth_client_secret
  oauth_client_secret_secret_id = module.secret_manager.oauth_client_secret_id
  secrets_ready                 = module.secret_manager.secrets_ready
  redirect_uris                 = var.oauth_redirect_uris
  support_email                 = var.oauth_support_email
  developer_email               = var.oauth_developer_email

  depends_on = [module.secret_manager]
}

# Configure Agent Engine (external resource reference)
module "agent_engine" {
  source = "../../modules/agent-engine"

  project_id                      = var.project_id
  environment                     = local.environment
  agent_engine_project_id         = var.agent_engine_project_id
  agent_engine_location           = var.agent_engine_location
  agent_engine_resource_name      = var.agent_engine_resource_name
  agent_engine_secret_id          = module.secret_manager.external_agent_engine_id_secret_id
  agent_engine_custom_url         = var.agent_engine_custom_url
  secrets_ready                   = module.secret_manager.secrets_ready
  cloud_run_service_account_email = module.iam.cloud_run_service_account_email

  depends_on = [module.secret_manager, module.iam]
}

# Deploy Cloud Run service
module "cloud_run" {
  source = "../../modules/cloud-run"

  project_id                      = var.project_id
  environment                     = local.environment
  region                          = var.region
  container_image_url             = "${module.artifact_registry.repository_url}:${local.environment}-latest"
  cloud_run_service_account_email = module.iam.cloud_run_service_account_email
  vpc_connector_name              = module.networking.vpc_connector_name

  # Resource limits
  cpu_limit     = var.cloud_run_cpu
  memory_limit  = var.cloud_run_memory
  min_instances = local.staging_config.min_instances
  max_instances = local.staging_config.max_instances

  # Secret references
  webui_secret_key_secret_id    = module.secret_manager.webui_secret_key_id
  database_url_secret_id        = module.secret_manager.database_url_id
  redis_url_secret_id           = module.secret_manager.redis_url_id
  oauth_client_secret_secret_id = module.secret_manager.oauth_client_secret_id
  agent_engine_secret_id        = module.secret_manager.external_agent_engine_id_secret_id

  # Configuration
  oauth_client_id     = var.oauth_client_id
  storage_bucket_name = module.storage.data_bucket_name

  # Dependencies
  services_ready          = module.project_services.services_ready
  networking_ready        = module.networking.networking_ready
  secrets_ready           = module.secret_manager.secrets_ready
  storage_ready           = module.storage.storage_ready
  database_ready          = module.database.database_ready
  redis_ready             = module.redis.redis_ready
  artifact_registry_ready = module.artifact_registry.artifact_registry_ready

  depends_on = [
    module.project_services,
    module.networking,
    module.secret_manager,
    module.storage,
    module.database,
    module.redis,
    module.artifact_registry
  ]
} 
