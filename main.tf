# ==========================================
# 1. NETWORKING (VPC, Subnet, NAT)
# ==========================================
resource "google_compute_network" "vpc" {
  name                    = "pk-vpc-v2"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "pk-subnet-v2"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.0.0.0/16"
}

resource "google_compute_router" "router" {
  name    = "pk-router-v2"
  region  = var.region
  network = google_compute_network.vpc.name
}

resource "google_compute_router_nat" "nat" {
  name                               = "pk-nat-v2"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# ==========================================
# 2. IAM & WORKLOAD IDENTITY FEDERATION
# ==========================================
resource "google_service_account" "gke_sa" {
  account_id   = "gke-custom-sa-v2"
  display_name = "GKE and GitHub Actions Service Account"
  project      = var.project_id
}

# Allow GKE to pull images
resource "google_project_iam_member" "gke_node_role" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

# Allow GitHub Actions to push images
resource "google_project_iam_member" "gke_ar_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

# Create the Workload Identity Pool
resource "google_iam_workload_identity_pool" "github_pool" {
  project                   = var.project_id
  workload_identity_pool_id = "github-pool-v2"
  display_name              = "GitHub Actions Pool"
  description               = "Identity pool for automated CI/CD"
}

# Create the OIDC Provider for GitHub
resource "google_iam_workload_identity_pool_provider" "github_provider" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider-v2"
  display_name                       = "GitHub Provider"
  
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }
  
  attribute_condition = "assertion.repository_owner == '${var.github_username}'"
  
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Bind the GitHub Repo to the Service Account
resource "google_service_account_iam_member" "github_impersonation" {
  service_account_id = google_service_account.gke_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_pool.workload_identity_pool_id}/attribute.repository/${var.github_username}/${var.github_app_repo}"
}

# ==========================================
# 3. ARTIFACT REGISTRY
# ==========================================
resource "google_artifact_registry_repository" "repo" {
  project       = var.project_id
  location      = var.region
  repository_id = "pk-repo-v2"
  description   = "Docker repository for V2 GitOps project"
  format        = "DOCKER"
}

# ==========================================
# 4. GOOGLE KUBERNETES ENGINE (GKE)
# ==========================================
resource "google_container_cluster" "primary" {
  name     = "pk-cluster-v2"
  project  = var.project_id
  location = var.zone
  
  deletion_protection      = false
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Satisfies the org policy for the temporary default pool
  node_config {
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "pk-node-pool-v2"
  project    = var.project_id
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 2

  node_config {
    machine_type = "e2-medium"
    
    service_account = google_service_account.gke_sa.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    # Satisfies the org policy for the actual worker nodes
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
}
