
variable "project_id" {
  description = "GCP project ID used for the eCabs infrastructure"
  type        = string
}

variable "region" {
  description = "GCP region for infrastructure resources"
  type        = string
  default     = "europe-west1"
}

variable "artifact_repository_id" {
  description = "Artifact Registry Docker repository ID"
  type        = string
  default     = "ecabs-bookings"
}
