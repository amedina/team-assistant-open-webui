output "secret_ids" {
  description = "Map of secret names to their IDs"
  value = {
    for key, secret in google_secret_manager_secret.secrets :
    key => secret.secret_id
  }
}

output "secret_names" {
  description = "Map of secret names to their full resource names"
  value = {
    for key, secret in google_secret_manager_secret.secrets :
    key => secret.name
  }
}

output "webui_secret_key_id" {
  description = "ID of the WebUI secret key"
  value       = google_secret_manager_secret.secrets["webui_secret_key"].secret_id
}

output "database_password_id" {
  description = "ID of the database password secret"
  value       = google_secret_manager_secret.secrets["database_password"].secret_id
}

output "database_url_id" {
  description = "ID of the database URL secret"
  value       = google_secret_manager_secret.secrets["database_url"].secret_id
}

output "redis_url_id" {
  description = "ID of the Redis URL secret"
  value       = google_secret_manager_secret.secrets["redis_url"].secret_id
}

output "oauth_client_secret_id" {
  description = "ID of the OAuth client secret"
  value       = google_secret_manager_secret.secrets["oauth_client_secret"].secret_id
}

output "external_agent_engine_id_secret_id" {
  description = "ID of the external agent engine ID secret"
  value       = google_secret_manager_secret.secrets["external_agent_engine_id"].secret_id
}

output "jwt_secret_id" {
  description = "ID of the JWT secret"
  value       = google_secret_manager_secret.jwt_secret.secret_id
}

output "ssl_cert_secret_id" {
  description = "ID of the SSL certificate secret (if enabled)"
  value       = var.enable_ssl_secret ? google_secret_manager_secret.ssl_cert[0].secret_id : null
}

output "ssl_key_secret_id" {
  description = "ID of the SSL private key secret (if enabled)"
  value       = var.enable_ssl_secret ? google_secret_manager_secret.ssl_key[0].secret_id : null
}

output "secrets_ready" {
  description = "Indicates that all secrets are ready"
  value       = true
  depends_on = [
    google_secret_manager_secret.secrets,
    google_secret_manager_secret_version.secret_versions,
    google_secret_manager_secret_iam_member.cloud_run_access,
    google_secret_manager_secret_iam_member.cloud_build_access,
    google_secret_manager_secret.jwt_secret,
    google_secret_manager_secret_version.jwt_secret_version,
    google_secret_manager_secret_iam_member.jwt_cloud_run_access
  ]
}

output "secret_references" {
  description = "Secret references for Cloud Run environment variables"
  value = {
    webui_secret_key = {
      secret_id = google_secret_manager_secret.secrets["webui_secret_key"].secret_id
      version   = "latest"
    }
    database_password = {
      secret_id = google_secret_manager_secret.secrets["database_password"].secret_id
      version   = "latest"
    }
    database_url = {
      secret_id = google_secret_manager_secret.secrets["database_url"].secret_id
      version   = "latest"
    }
    redis_url = {
      secret_id = google_secret_manager_secret.secrets["redis_url"].secret_id
      version   = "latest"
    }
    oauth_client_secret = {
      secret_id = google_secret_manager_secret.secrets["oauth_client_secret"].secret_id
      version   = "latest"
    }
    external_agent_engine_id = {
      secret_id = google_secret_manager_secret.secrets["external_agent_engine_id"].secret_id
      version   = "latest"
    }
    jwt_secret = {
      secret_id = google_secret_manager_secret.jwt_secret.secret_id
      version   = "latest"
    }
  }
}

output "all_secrets_info" {
  description = "Comprehensive information about all secrets"
  value = {
    main_secrets = {
      for key, secret in google_secret_manager_secret.secrets :
      key => {
        id          = secret.secret_id
        name        = secret.name
        project     = secret.project
        labels      = secret.labels
        create_time = secret.create_time
      }
    }
    jwt_secret = {
      id          = google_secret_manager_secret.jwt_secret.secret_id
      name        = google_secret_manager_secret.jwt_secret.name
      project     = google_secret_manager_secret.jwt_secret.project
      labels      = google_secret_manager_secret.jwt_secret.labels
      create_time = google_secret_manager_secret.jwt_secret.create_time
    }
    ssl_secrets = var.enable_ssl_secret ? {
      cert = {
        id          = google_secret_manager_secret.ssl_cert[0].secret_id
        name        = google_secret_manager_secret.ssl_cert[0].name
        project     = google_secret_manager_secret.ssl_cert[0].project
        labels      = google_secret_manager_secret.ssl_cert[0].labels
        create_time = google_secret_manager_secret.ssl_cert[0].create_time
      }
      key = {
        id          = google_secret_manager_secret.ssl_key[0].secret_id
        name        = google_secret_manager_secret.ssl_key[0].name
        project     = google_secret_manager_secret.ssl_key[0].project
        labels      = google_secret_manager_secret.ssl_key[0].labels
        create_time = google_secret_manager_secret.ssl_key[0].create_time
      }
    } : null
  }
} 
