output "instance_id" {
  description = "ID of the Redis instance"
  value       = google_redis_instance.main.id
}

output "instance_name" {
  description = "Name of the Redis instance"
  value       = google_redis_instance.main.name
}

output "host" {
  description = "Redis host address"
  value       = google_redis_instance.main.host
}

output "port" {
  description = "Redis port"
  value       = google_redis_instance.main.port
}

output "connection_string" {
  description = "Redis connection string"
  value       = "redis://${google_redis_instance.main.host}:${google_redis_instance.main.port}"
}

output "current_location_id" {
  description = "Current location ID of the Redis instance"
  value       = google_redis_instance.main.current_location_id
} 