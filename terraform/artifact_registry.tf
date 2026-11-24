
# Enable the Artifact Registry API
resource "google_project_service" "artifact_registry_api" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"

  disable_on_destroy = false
}

# Repository for producer and consumer Docker images
resource "google_artifact_registry_repository" "booking_images" {
  project       = var.project_id
  location      = var.region
  repository_id = var.artifact_repository_id

  description = "Docker images for eCabs booking services"
  format      = "DOCKER"

  docker_config {
    immutable_tags = true
  }

  depends_on = [
    google_project_service.artifact_registry_api
  ]
}
