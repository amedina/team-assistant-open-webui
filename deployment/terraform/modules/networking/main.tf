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
}

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "${var.environment}-open-webui-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  description             = "VPC network for Open WebUI ${var.environment} environment"

  depends_on = [var.services_ready]
}

# Main subnet for general resources
resource "google_compute_subnetwork" "main" {
  name          = "${var.environment}-open-webui-subnet-main"
  ip_cidr_range = "10.0.0.0/24"
  network       = google_compute_network.vpc.id
  region        = var.region
  description   = "Main subnet for Open WebUI ${var.environment} environment"

  # Enable private Google access for accessing Google APIs
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# VPC Connector subnet (required for Cloud Run private access)
resource "google_compute_subnetwork" "vpc_connector" {
  name          = "${var.environment}-open-webui-subnet-vpc-connector"
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.vpc.id
  region        = var.region
  description   = "VPC Connector subnet for Open WebUI ${var.environment} environment"

  # VPC Connector specific settings
  private_ip_google_access = true

  # Purpose must be set for VPC Connector
  purpose = "VPC_PEERING"
  role    = "ACTIVE"
}

# Private service connection for Cloud SQL and Redis
resource "google_compute_global_address" "private_service_range" {
  name          = "${var.environment}-open-webui-private-service-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
  description   = "Private service range for Cloud SQL and Redis"
}

# Private service connection
resource "google_service_networking_connection" "private_service_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_range.name]
}

# VPC Connector for Cloud Run (mandatory for private service access)
resource "google_vpc_access_connector" "connector" {
  name          = "${var.environment}-open-webui-vpc-connector"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.8.0.0/28"

  min_throughput = 200
  max_throughput = var.environment == "prod" ? 1000 : 300

  depends_on = [
    google_compute_subnetwork.vpc_connector,
    var.services_ready
  ]
}

# Firewall rule to allow internal communication
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.environment}-open-webui-allow-internal"
  network = google_compute_network.vpc.name

  description = "Allow internal communication within VPC"

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [
    "10.0.0.0/24", # Main subnet
    "10.8.0.0/28", # VPC Connector subnet
    "10.1.0.0/16", # Private service range
  ]

  direction = "INGRESS"
  priority  = 1000
}

# Firewall rule to allow VPC Connector access
resource "google_compute_firewall" "allow_vpc_connector" {
  name    = "${var.environment}-open-webui-allow-vpc-connector"
  network = google_compute_network.vpc.name

  description = "Allow VPC Connector access to private services"

  allow {
    protocol = "tcp"
    ports    = ["5432", "6379", "8080", "443", "80"]
  }

  source_ranges = ["10.8.0.0/28"] # VPC Connector subnet
  target_tags   = ["private-service"]

  direction = "INGRESS"
  priority  = 1000
}

# Firewall rule to allow Cloud Run health checks
resource "google_compute_firewall" "allow_health_checks" {
  name    = "${var.environment}-open-webui-allow-health-checks"
  network = google_compute_network.vpc.name

  description = "Allow health checks from Google Cloud Load Balancer"

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16",
    "209.85.152.0/22",
    "209.85.204.0/22"
  ]

  target_tags = ["cloud-run-service"]

  direction = "INGRESS"
  priority  = 1000
}

# NAT Gateway for outbound internet access (if needed)
resource "google_compute_router" "router" {
  name    = "${var.environment}-open-webui-router"
  region  = var.region
  network = google_compute_network.vpc.id

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.environment}-open-webui-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
} 
