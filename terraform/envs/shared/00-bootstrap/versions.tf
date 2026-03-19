terraform {
  required_version = ">= 1.5.0"

  backend "gcs" {}

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

# Bootstrap uses the shared owner-managed GCS tfstate backend.
provider "google" {
  project = var.project_id
  region  = var.region
}
