output "github_actions_provider_name" {
  description = "The Workload Identity Provider ID to use in GitHub Actions"
  value       = google_iam_workload_identity_pool_provider.github_provider.name
}

output "gke_cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.primary.name
}
