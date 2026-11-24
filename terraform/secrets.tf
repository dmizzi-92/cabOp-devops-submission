resource "google_secret_manager_secret" "database_password" {
  project             = var.project_id
  secret_id           = "ecabs-database-password"
  version_destroy_ttl = "604800s"

  replication {
    auto {}
  }

  deletion_protection = true
  secret_type         = "OTHER_DB_CREDENTIALS"
}


resource "google_secret_manager_secret" "rabbitmq_password" {
  project             = var.project_id
  secret_id           = "ecabs-rabbitmq-password"
  version_destroy_ttl = "604800s"


  replication {
    auto {}
  }

  deletion_protection = true
  secret_type         = "OTHER"
}

