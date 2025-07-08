output "vpc_network_id" {
  description = "ID of the VPC network"
  value       = google_compute_network.main.id
}

output "vpc_network_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.main.name
}

output "vpc_connector_name" {
  description = "Name of the VPC connector"
  value       = try(google_vpc_access_connector.connector[0].name, null)
}

output "vpc_connector_id" {
  description = "ID of the VPC connector"
  value       = try(google_vpc_access_connector.connector[0].id, null)
}

output "database_subnet_name" {
  description = "Name of the database subnet"
  value       = google_compute_subnetwork.database.name
}

output "private_service_connection_id" {
  description = "ID of the private service connection"
  value       = google_service_networking_connection.private_service_connection.id
}
