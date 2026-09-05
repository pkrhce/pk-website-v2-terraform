variable "project_id" {
  description = "The GCP Project ID"
  type        = string
}

variable "region" {
  description = "The GCP Region"
  type        = string
}

variable "zone" {
  description = "The GCP Zone for the GKE cluster"
  type        = string
}

variable "github_username" {
  description = "Your GitHub Username"
  type        = string
}

variable "github_app_repo" {
  description = "The GitHub repository that GitHub Actions will run from"
  type        = string
}
