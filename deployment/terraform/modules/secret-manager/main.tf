terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
  }
}

locals {
  common_labels = {
    application = "open-webui"
    environment = var.environment
    managed-by  = "terraform"
  }

  # Define all secrets required for Open WebUI
  secrets = {
    webui_secret_key = {
      description = "Secret key for Open WebUI application"
      replication = var.environment == "prod" ? "multi-region" : "single-region"
    }
    database_password = {
      description = "PostgreSQL database password"
      replication = var.environment == "prod" ? "multi-region" : "single-region"
    }
    database_url = {
      description = "Complete PostgreSQL database connection string"
      replication = var.environment == "prod" ? "multi-region" : "single-region"
    }
    redis_url = {
      description = "Redis connection string with authentication"
      replication = var.environment == "prod" ? "multi-region" : "single-region"
    }
    oauth_client_secret = {
      description = "Google OAuth client secret"
      replication = var.environment == "prod" ? "multi-region" : "single-region"
    }
    external_agent_engine_id = {
      description = "External Agent Engine resource ID"
      replication = var.environment == "prod" ? "multi-region" : "single-region"
    }
  }
}

# Create secrets
resource "google_secret_manager_secret" "secrets" {
  for_each = local.secrets

  secret_id = "${var.environment}-open-webui-${each.key}"
  project   = var.project_id

  labels = merge(local.common_labels, {
    secret-type = each.key
  })

  replication {
    dynamic "user_managed" {
      for_each = each.value.replication == "multi-region" ? [1] : []
      content {
        replicas {
          location = var.region
        }
        replicas {
          location = var.backup_region
        }
      }
    }

    dynamic "auto" {
      for_each = each.value.replication == "single-region" ? [1] : []
      content {}
    }
  }

  depends_on = [var.services_ready]
}

# Create secret versions with placeholder values
resource "google_secret_manager_secret_version" "secret_versions" {
  for_each = local.secrets

  secret = google_secret_manager_secret.secrets[each.key].id

  # Placeholder values - must be manually updated after deployment
  secret_data = (
    each.key == "webui_secret_key" ? "CHANGE_THIS_WEBUI_SECRET_KEY_AFTER_DEPLOYMENT" :
    each.key == "database_password" ? "CHANGE_THIS_DATABASE_PASSWORD_AFTER_DEPLOYMENT" :
    each.key == "database_url" ? "CHANGE_THIS_DATABASE_URL_AFTER_DEPLOYMENT" :
    each.key == "redis_url" ? "CHANGE_THIS_REDIS_URL_AFTER_DEPLOYMENT" :
    each.key == "oauth_client_secret" ? "CHANGE_THIS_OAUTH_CLIENT_SECRET_AFTER_DEPLOYMENT" :
    each.key == "external_agent_engine_id" ? "CHANGE_THIS_AGENT_ENGINE_ID_AFTER_DEPLOYMENT" :
    "CHANGE_THIS_SECRET_VALUE_AFTER_DEPLOYMENT"
  )
}

# IAM policy for Cloud Run service account to access secrets
resource "google_secret_manager_secret_iam_member" "cloud_run_access" {
  for_each = local.secrets

  project   = var.project_id
  secret_id = google_secret_manager_secret.secrets[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.cloud_run_service_account_email}"
}

# IAM policy for Cloud Build service account to access secrets
resource "google_secret_manager_secret_iam_member" "cloud_build_access" {
  for_each = local.secrets

  project   = var.project_id
  secret_id = google_secret_manager_secret.secrets[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.cloud_build_service_account_email}"
}

# Additional security: IAM policy for developers to manage secrets in staging
resource "google_secret_manager_secret_iam_member" "developer_access" {
  for_each = var.environment == "staging" ? toset(var.developer_emails) : toset([])

  project   = var.project_id
  secret_id = google_secret_manager_secret.secrets["webui_secret_key"].secret_id
  role      = "roles/secretmanager.secretVersionManager"
  member    = "user:${each.value}"
}

# Create a secret for JWT signing (if needed)
resource "google_secret_manager_secret" "jwt_secret" {
  secret_id = "${var.environment}-open-webui-jwt-secret"
  project   = var.project_id

  labels = merge(local.common_labels, {
    secret-type = "jwt"
  })

  replication {
    dynamic "user_managed" {
      for_each = var.environment == "prod" ? [1] : []
      content {
        replicas {
          location = var.region
        }
        replicas {
          location = var.backup_region
        }
      }
    }

    dynamic "auto" {
      for_each = var.environment == "staging" ? [1] : []
      content {}
    }
  }

  depends_on = [var.services_ready]
}

resource "google_secret_manager_secret_version" "jwt_secret_version" {
  secret      = google_secret_manager_secret.jwt_secret.id
  secret_data = "CHANGE_THIS_JWT_SECRET_AFTER_DEPLOYMENT"
}

# IAM for JWT secret
resource "google_secret_manager_secret_iam_member" "jwt_cloud_run_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.jwt_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.cloud_run_service_account_email}"
}

# Optional: Create secret for SSL certificates (if using custom domain)
resource "google_secret_manager_secret" "ssl_cert" {
  count = var.enable_ssl_secret ? 1 : 0

  secret_id = "${var.environment}-open-webui-ssl-cert"
  project   = var.project_id

  labels = merge(local.common_labels, {
    secret-type = "ssl-cert"
  })

  replication {
    auto {}
  }

  depends_on = [var.services_ready]
}

resource "google_secret_manager_secret_version" "ssl_cert_version" {
  count = var.enable_ssl_secret ? 1 : 0

  secret      = google_secret_manager_secret.ssl_cert[0].id
  secret_data = "CHANGE_THIS_SSL_CERT_AFTER_DEPLOYMENT"
}

# Optional: Create secret for SSL private key
resource "google_secret_manager_secret" "ssl_key" {
  count = var.enable_ssl_secret ? 1 : 0

  secret_id = "${var.environment}-open-webui-ssl-key"
  project   = var.project_id

  labels = merge(local.common_labels, {
    secret-type = "ssl-key"
  })

  replication {
    auto {}
  }

  depends_on = [var.services_ready]
}

resource "google_secret_manager_secret_version" "ssl_key_version" {
  count = var.enable_ssl_secret ? 1 : 0

  secret      = google_secret_manager_secret.ssl_key[0].id
  secret_data = "CHANGE_THIS_SSL_KEY_AFTER_DEPLOYMENT"
}
