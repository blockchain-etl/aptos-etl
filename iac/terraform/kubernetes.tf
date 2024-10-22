# Fetch GKE client configuration
data "google_client_config" "default" {}

# Kubernetes provider for mainnet
provider "kubernetes" {
  alias                  = "mainnet"
  host                   = local.mainnet_enabled ? "https://${local.mainnet_cluster_data.endpoint}" : ""
  token                  = local.mainnet_enabled ? data.google_client_config.default.access_token : ""
  cluster_ca_certificate = local.mainnet_enabled ? base64decode(local.mainnet_cluster_data.master_auth[0].cluster_ca_certificate) : ""
}

# Kubernetes provider for testnet
provider "kubernetes" {
  alias                  = "testnet"
  host                   = local.testnet_enabled ? "https://${local.testnet_cluster_data.endpoint}" : ""
  token                  = local.testnet_enabled ? data.google_client_config.default.access_token : ""
  cluster_ca_certificate = local.testnet_enabled ? base64decode(local.testnet_cluster_data.master_auth[0].cluster_ca_certificate) : ""
}

# Namespace for mainnet (only create if mainnet is enabled)
resource "kubernetes_namespace" "aptos_namespace_mainnet" {
  count    = contains(var.enabled_networks, "mainnet") ? 1 : 0
  provider = kubernetes.mainnet
  metadata {
    name = "mainnet"
  }
}

# Namespace for testnet (only create if testnet is enabled)
resource "kubernetes_namespace" "aptos_namespace_testnet" {
  count    = contains(var.enabled_networks, "testnet") ? 1 : 0
  provider = kubernetes.testnet
  metadata {
    name = "testnet"
  }
}

# Namespace for keda (shared across environments)
resource "kubernetes_namespace" "aptos_namespace_keda_mainnet" {
  count    = contains(var.enabled_networks, "mainnet") ? 1 : 0
  provider = kubernetes.mainnet
  metadata {
    name = "keda"
  }
}

resource "kubernetes_namespace" "aptos_namespace_keda_testnet" {
  count    = contains(var.enabled_networks, "testnet") ? 1 : 0
  provider = kubernetes.testnet
  metadata {
    name = "keda"
  }
}

# Storage class for SSD (for mainnet)
resource "kubernetes_storage_class" "pd-ssd_mainnet" {
  count    = contains(var.enabled_networks, "mainnet") ? 1 : 0
  provider = kubernetes.mainnet
  metadata {
    name = "pd-ssd"
  }
  storage_provisioner = "kubernetes.io/gce-pd"
  reclaim_policy      = "Delete"
  parameters = {
    type = "pd-ssd"
  }
}

# Storage class for SSD (for testnet)
resource "kubernetes_storage_class" "pd-ssd_testnet" {
  count    = contains(var.enabled_networks, "testnet") ? 1 : 0
  provider = kubernetes.testnet
  metadata {
    name = "pd-ssd"
  }
  storage_provisioner = "kubernetes.io/gce-pd"
  reclaim_policy      = "Delete"
  parameters = {
    type = "pd-ssd"
  }
}
