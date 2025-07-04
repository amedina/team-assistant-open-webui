terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# VPC Network
resource "google_compute_network" "main" {
  name                    = "${var.environment}-open-webui-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Subnet for VPC Connector
resource "google_compute_subnetwork" "vpc_connector" {
  name          = "${var.environment}-open-webui-connector-subnet"
  network       = google_compute_network.main.id
  region        = var.region
  ip_cidr_range = var.vpc_connector_cidr
  project       = var.project_id
}

# Subnet for Cloud SQL (Private IP)
resource "google_compute_subnetwork" "database" {
  name          = "${var.environment}-open-webui-db-subnet"
  network       = google_compute_network.main.id
  region        = var.region
  ip_cidr_range = var.database_subnet_cidr
  project       = var.project_id
}

# Private Service Connection for Cloud SQL
resource "google_service_networking_connection" "private_service_connection" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
  
  lifecycle {
    ignore_changes = [reserved_peering_ranges]
  }
}

# Reserved IP range for private services
resource "google_compute_global_address" "private_ip_range" {
  name          = "${var.environment}-open-webui-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.id
  project       = var.project_id
}

# VPC Access Connector for Cloud Run
resource "google_vpc_access_connector" "connector" {
  name          = "${var.environment}-openwebui-conn"
  region        = var.region
  subnet {
    name = google_compute_subnetwork.vpc_connector.name
  }
  min_instances = var.vpc_connector_min_instances
  max_instances = var.vpc_connector_max_instances
  project       = var.project_id
  
  depends_on = [google_compute_subnetwork.vpc_connector]
}

# Firewall rule to allow internal communication
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.environment}-open-webui-allow-internal"
  network = google_compute_network.main.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["5432", "6379", "8080"]
  }

  source_ranges = [
    var.vpc_connector_cidr,
    var.database_subnet_cidr,
    "10.85.0.0/16",  # Private service connection range
  ]
}

# Firewall rule for health checks
resource "google_compute_firewall" "allow_health_check" {
  name    = "${var.environment}-open-webui-allow-health-check"
  network = google_compute_network.main.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  # Google health check IP ranges
  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16",
  ]
}

# Firewall rule to allow egress to private services
resource "google_compute_firewall" "allow_egress_to_private_services" {
  name      = "${var.environment}-open-webui-allow-egress-private"
  network   = google_compute_network.main.name
  project   = var.project_id
  direction = "EGRESS"

  allow {
    protocol = "tcp"
    ports    = ["5432", "6379"]  # PostgreSQL and Redis
  }

  destination_ranges = [
    "10.85.0.0/16",  # Private service connection range
  ]
} 