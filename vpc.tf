
provider "google" {
  project = var.project_id
  region  = var.region
  credentials = file(var.credentials_file)
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  credentials = file(var.credentials_file)
}

# VPC
resource "google_compute_network" "vpc" {
  name                    = "gke-vpc"
  auto_create_subnetworks = "false"
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "gke-subnet"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.10.0.0/24"
}

resource "google_compute_subnetwork" "proxy-only-sub" {
  provider = google-beta

  name          = "ilb-proxy-only-subnet"
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = "172.16.0.0/24"
  purpose       = "INTERNAL_HTTPS_LOAD_BALANCER"
  role          = "ACTIVE"
}