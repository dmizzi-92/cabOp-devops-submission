
# Enable the Compute Engine API
resource "google_project_service" "compute_api" {
  project = var.project_id
  service = "compute.googleapis.com"

  disable_on_destroy = false
}

# Dedicated VPC for the eCabs GKE cluster
resource "google_compute_network" "ecabs_vpc" {
  project                 = var.project_id
  name                    = "ecabs-vpc"
  auto_create_subnetworks = false

  depends_on = [
    google_project_service.compute_api
  ]
}

# Regional subnet for GKE nodes, Pods and Services
resource "google_compute_subnetwork" "gke_subnet" {
  project       = var.project_id
  name          = "ecabs-gke-subnet"
  region        = var.region
  network       = google_compute_network.ecabs_vpc.id
  ip_cidr_range = "10.10.0.0/20"

  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = "10.20.0.0/16"
  }

  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = "10.30.0.0/20"
  }
}

