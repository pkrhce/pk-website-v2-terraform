provider "google" {
  project = var.project_id
  region  = var.region
}

# Fetch project details (needed for Workload Identity project number)
data "google_project" "current" {}
