output "notification_channel_id" {
  description = "ID of the email notification channel"
  value       = var.notification_email != "" ? google_monitoring_notification_channel.email[0].id : null
}

output "uptime_check_id" {
  description = "ID of the uptime check"
  value       = var.enable_uptime_checks ? google_monitoring_uptime_check_config.cloud_run_uptime[0].uptime_check_id : null
}

output "alert_policy_id" {
  description = "ID of the uptime alert policy"
  value       = var.enable_uptime_checks && var.notification_email != "" ? google_monitoring_alert_policy.uptime_alert[0].id : null
} 