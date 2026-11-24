
output "gke_cluster_name" {
  description = "Name of the eCabs GKE Autopilot cluster"
  value       = google_container_cluster.default.name
}

output "gke_cluster_location" {
  description = "Region of the GKE cluster"
  value       = google_container_cluster.default.location
}

output "artifact_registry_url" {
  description = "Docker image repository location"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.booking_images.repository_id}"
}
