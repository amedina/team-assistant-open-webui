terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Notification channel for email alerts
resource "google_monitoring_notification_channel" "email" {
  count        = var.notification_email != "" ? 1 : 0
  display_name = "Email Notification Channel (${var.environment})"
  type         = "email"
  
  labels = {
    email_address = var.notification_email
  }
}

# Uptime check for Cloud Run service
resource "google_monitoring_uptime_check_config" "cloud_run_uptime" {
  count          = var.enable_uptime_checks ? 1 : 0
  display_name   = "${var.environment}-openwebui-uptime-check"
  timeout        = "10s"
  period         = "300s"
  
  http_check {
    path         = "/health"
    port         = "443"
    use_ssl      = true
    validate_ssl = true
  }
  
  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.cloud_run_service_url
    }
  }
  
  content_matchers {
    content = "ok"
    matcher = "CONTAINS_STRING"
  }
}

# Alert policy for uptime check failures
resource "google_monitoring_alert_policy" "uptime_alert" {
  count        = var.enable_uptime_checks && var.notification_email != "" ? 1 : 0
  display_name = "${var.environment}-openwebui-uptime-alert"
  combiner     = "OR"  # Required: how to combine conditions
  
  conditions {
    display_name = "Uptime check failure"
    
    condition_threshold {
      filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" resource.type=\"uptime_url\""
      duration        = "300s"
      comparison      = "COMPARISON_EQ"
      threshold_value = 0
      
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields    = ["resource.*"]
      }
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.email[0].id]
  
  alert_strategy {
    auto_close = "86400s"  # 24 hours
  }
} 