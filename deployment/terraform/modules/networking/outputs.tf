output "vpc_network_id" {
  description = "ID of the VPC network"
  value       = google_compute_network.vpc.id
}

output "vpc_network_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.vpc.name
}

output "vpc_network_self_link" {
  description = "Self link of the VPC network"
  value       = google_compute_network.vpc.self_link
}

output "main_subnet_id" {
  description = "ID of the main subnet"
  value       = google_compute_subnetwork.main.id
}

output "main_subnet_name" {
  description = "Name of the main subnet"
  value       = google_compute_subnetwork.main.name
}

output "main_subnet_cidr" {
  description = "CIDR range of the main subnet"
  value       = google_compute_subnetwork.main.ip_cidr_range
}

output "vpc_connector_subnet_id" {
  description = "ID of the VPC Connector subnet"
  value       = google_compute_subnetwork.vpc_connector.id
}

output "vpc_connector_subnet_name" {
  description = "Name of the VPC Connector subnet"
  value       = google_compute_subnetwork.vpc_connector.name
}

output "vpc_connector_name" {
  description = "Name of the VPC Connector"
  value       = google_vpc_access_connector.connector.name
}

output "vpc_connector_id" {
  description = "ID of the VPC Connector"
  value       = google_vpc_access_connector.connector.id
}

output "private_service_range_name" {
  description = "Name of the private service range"
  value       = google_compute_global_address.private_service_range.name
}

output "private_service_connection_id" {
  description = "ID of the private service connection"
  value       = google_service_networking_connection.private_service_connection.id
}

output "router_name" {
  description = "Name of the Cloud Router"
  value       = google_compute_router.router.name
}

output "nat_name" {
  description = "Name of the Cloud NAT"
  value       = google_compute_router_nat.nat.name
}

output "networking_ready" {
  description = "Indicates that networking resources are ready"
  value       = true
  depends_on = [
    google_compute_network.vpc,
    google_compute_subnetwork.main,
    google_compute_subnetwork.vpc_connector,
    google_vpc_access_connector.connector,
    google_service_networking_connection.private_service_connection,
    google_compute_firewall.allow_internal,
    google_compute_firewall.allow_vpc_connector,
    google_compute_firewall.allow_health_checks
  ]
}

output "subnets" {
  description = "Map of subnet information"
  value = {
    main = {
      id   = google_compute_subnetwork.main.id
      name = google_compute_subnetwork.main.name
      cidr = google_compute_subnetwork.main.ip_cidr_range
    }
    vpc_connector = {
      id   = google_compute_subnetwork.vpc_connector.id
      name = google_compute_subnetwork.vpc_connector.name
      cidr = google_compute_subnetwork.vpc_connector.ip_cidr_range
    }
  }
}

output "firewall_rules" {
  description = "Map of firewall rules created"
  value = {
    allow_internal      = google_compute_firewall.allow_internal.name
    allow_vpc_connector = google_compute_firewall.allow_vpc_connector.name
    allow_health_checks = google_compute_firewall.allow_health_checks.name
  }
} 
