output "instance_id" {
  description = "ID of the database instance"
  value       = google_sql_database_instance.postgres.id
}

output "instance_name" {
  description = "Name of the database instance"
  value       = google_sql_database_instance.postgres.name
}

output "connection_name" {
  description = "Connection name for the database instance"
  value       = google_sql_database_instance.postgres.connection_name
}

output "private_ip_address" {
  description = "Private IP address of the database instance"
  value       = google_sql_database_instance.postgres.private_ip_address
}

output "database_name" {
  description = "Name of the application database"
  value       = google_sql_database.openwebui.name
}

output "database_user" {
  description = "Database user name"
  value       = google_sql_user.openwebui.name
} 