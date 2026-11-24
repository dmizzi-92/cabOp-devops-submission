resource "google_container_cluster" "default" {
  name = "ecabs-autopilot-cluster"

  location         = var.region
  enable_autopilot = true

  network    = google_compute_network.ecabs_vpc.id
  subnetwork = google_compute_subnetwork.gke_subnet.id

  ip_allocation_policy {
    stack_type                    = "IPV4"
    cluster_secondary_range_name  = "gke-pods"
    services_secondary_range_name = "gke-services"
  }

  # Set `deletion_protection` to `true` will ensure that one cannot
  # accidentally delete this instance by use of Terraform.
  deletion_protection = true

  cluster_autoscaling {
    auto_provisioning_defaults {
      service_account = google_service_account.gke_nodes.email
    }
  }

  depends_on = [
    google_project_service.gke_api,
    google_project_iam_member.gke_node_role,
    google_artifact_registry_repository_iam_member.gke_image_reader
  ]
}

resource "google_project_service" "gke_api" {
  project = var.project_id
  service = "container.googleapis.com"

  disable_on_destroy = false


}