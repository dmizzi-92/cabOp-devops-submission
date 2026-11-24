
# Enable the IAM API
resource "google_project_service" "iam_api" {
  project = var.project_id
  service = "iam.googleapis.com"

  disable_on_destroy = false
}

# Dedicated service account for GKE nodes
resource "google_service_account" "gke_nodes" {
  project      = var.project_id
  account_id   = "ecabs-gke-nodes"
  display_name = "eCabs GKE Node Service Account"

  depends_on = [
    google_project_service.iam_api
  ]
}

# Required GKE node permissions
resource "google_project_iam_member" "gke_node_role" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# Allow nodes to pull images from our private repository
resource "google_artifact_registry_repository_iam_member" "gke_image_reader" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.booking_images.name

  role   = "roles/artifactregistry.reader"
  member = "serviceAccount:${google_service_account.gke_nodes.email}"
}
