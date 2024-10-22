# Helm provider configuration for Mainnet
locals {
  mainnet_enabled = contains(var.enabled_networks, "mainnet")
  testnet_enabled = contains(var.enabled_networks, "testnet")

  mainnet_cluster_data = local.mainnet_enabled ? google_container_cluster.aptos_bq["mainnet"] : null
  testnet_cluster_data = local.testnet_enabled ? google_container_cluster.aptos_bq["testnet"] : null
}

# Helm provider configuration for Mainnet (Only if mainnet is enabled)
provider "helm" {
  alias = "mainnet"
  kubernetes {
    host                   = local.mainnet_enabled ? "https://${local.mainnet_cluster_data.endpoint}" : ""
    token                  = local.mainnet_enabled ? data.google_client_config.default.access_token : ""
    cluster_ca_certificate = local.mainnet_enabled ? base64decode(local.mainnet_cluster_data.master_auth[0].cluster_ca_certificate) : ""
  }
}

# Helm provider configuration for Testnet (Only if testnet is enabled)
provider "helm" {
  alias = "testnet"
  kubernetes {
    host                   = local.testnet_enabled ? "https://${local.testnet_cluster_data.endpoint}" : ""
    token                  = local.testnet_enabled ? data.google_client_config.default.access_token : ""
    cluster_ca_certificate = local.testnet_enabled ? base64decode(local.testnet_cluster_data.master_auth[0].cluster_ca_certificate) : ""
  }
}

# Aptos Fullnodes for Mainnet Helm Release
resource "helm_release" "aptos_fullnodes_mainnet" {
  count     = contains(var.enabled_networks, "mainnet") ? 1 : 0
  provider  = helm.mainnet
  name      = "aptos-fullnodes-mainnet"
  namespace = "mainnet"
  chart     = "../helm/aptos-fullnodes"

  values = [
    file("../helm/aptos-fullnodes/values.aptos.prod.mainnet.yaml")
  ]

  depends_on = [
    kubernetes_namespace.aptos_namespace_mainnet,
    google_container_node_pool.aptos["mainnet"],
    google_container_node_pool.aptos_apps["mainnet"],
    google_container_cluster.aptos_bq["mainnet"],
    kubernetes_storage_class.pd-ssd_mainnet,
  ]
}

# Aptos Fullnodes for Testnet Helm Release
resource "helm_release" "aptos_fullnodes_testnet" {
  count     = contains(var.enabled_networks, "testnet") ? 1 : 0
  provider  = helm.testnet
  name      = "aptos-fullnodes-testnet"
  namespace = "testnet"
  chart     = "../helm/aptos-fullnodes"

  values = [
    file("../helm/aptos-fullnodes/values.aptos.prod.testnet.yaml")
  ]

  depends_on = [
    kubernetes_namespace.aptos_namespace_testnet,
    google_container_node_pool.aptos["testnet"],
    google_container_node_pool.aptos_apps["testnet"],
    google_container_cluster.aptos_bq["testnet"],
    kubernetes_storage_class.pd-ssd_testnet,
  ]
}

# Aptos Coordinator Helm Release
resource "helm_release" "aptos_coordinator_mainnet" {
  count     = contains(var.enabled_networks, "mainnet") ? 1 : 0
  provider  = helm.mainnet
  name      = "aptos-coordinator"
  namespace = "mainnet"
  chart     = "../helm/aptos-indexing-coordinator"

  values = [
    file("../helm/aptos-indexing-coordinator/values.mainnet.yaml")
  ]

  set {
    name  = "image.tag"
    value = var.coordinator_image_tag
  }

  set {
    name  = "image.repository"
    value = var.coordinator_image_repo
  }

  set {
    name  = "GCPServiceAccountName"
    value = google_service_account.aptos_app_sa.email
  }

  set {
    name  = "env.gcp_project_id"
    value = var.project_id
  }

  depends_on = [
    kubernetes_namespace.aptos_namespace_mainnet,
    google_container_node_pool.aptos["mainnet"],
    google_container_node_pool.aptos_apps["mainnet"],
    google_container_cluster.aptos_bq["mainnet"],
    kubernetes_storage_class.pd-ssd_mainnet,
    google_service_account_iam_binding.aptos_app_sa
  ]
}

resource "helm_release" "aptos_coordinator_testnet" {
  count     = contains(var.enabled_networks, "testnet") ? 1 : 0
  provider  = helm.testnet
  name      = "aptos-coordinator"
  namespace = "testnet"
  chart     = "../helm/aptos-indexing-coordinator"

  values = [
    file("../helm/aptos-indexing-coordinator/values.testnet.yaml")
  ]

  set {
    name  = "image.tag"
    value = var.coordinator_image_tag
  }

  set {
    name  = "image.repository"
    value = var.coordinator_image_repo
  }

  set {
    name  = "GCPServiceAccountName"
    value = google_service_account.aptos_app_sa.email
  }

  set {
    name  = "env.gcp_project_id"
    value = var.project_id
  }

  depends_on = [
    kubernetes_namespace.aptos_namespace_testnet,
    google_container_node_pool.aptos["testnet"],
    google_container_node_pool.aptos_apps["testnet"],
    google_container_cluster.aptos_bq["testnet"],
    kubernetes_storage_class.pd-ssd_testnet,
    google_service_account_iam_binding.aptos_app_sa
  ]
}

# Aptos Transformer Helm Release
resource "helm_release" "aptos_transformer_mainnet" {
  count     = contains(var.enabled_networks, "mainnet") ? 1 : 0
  provider  = helm.mainnet
  name      = "aptos-transformer"
  namespace = "mainnet"
  chart     = "../helm/aptos-extractor-transformer"

  values = [
    file("../helm/aptos-extractor-transformer/values.mainnet.yaml")
  ]

  set {
    name  = "image.tag"
    value = var.transformer_mainnet_image_tag
  }

  set {
    name  = "image.repository"
    value = var.transformer_mainnet_image_repo
  }

  depends_on = [
    kubernetes_namespace.aptos_namespace_mainnet,
    google_container_node_pool.aptos["mainnet"],
    google_container_node_pool.aptos_apps["mainnet"],
    google_container_cluster.aptos_bq["mainnet"],
    kubernetes_storage_class.pd-ssd_mainnet,
    helm_release.aptos_coordinator_mainnet,
    google_storage_bucket.aptos_buckets
  ]
}

resource "helm_release" "aptos_transformer_testnet" {
  count     = contains(var.enabled_networks, "testnet") ? 1 : 0
  provider  = helm.testnet
  name      = "aptos-transformer"
  namespace = "testnet"
  chart     = "../helm/aptos-extractor-transformer"

  values = [
    file("../helm/aptos-extractor-transformer/values.testnet.yaml")
  ]

  set {
    name  = "image.tag"
    value = var.transformer_testnet_image_tag
  }

  set {
    name  = "image.repository"
    value = var.transformer_testnet_image_repo
  }

  set {
    name  = "project_id"
    value = var.project_id
  }

  depends_on = [
    kubernetes_namespace.aptos_namespace_testnet,
    google_container_node_pool.aptos["testnet"],
    google_container_node_pool.aptos_apps["testnet"],
    google_container_cluster.aptos_bq["testnet"],
    kubernetes_storage_class.pd-ssd_testnet,
    helm_release.aptos_coordinator_testnet,
    google_storage_bucket.aptos_buckets
  ]
}

# Keda Helm Release (applied to all clusters)
resource "helm_release" "keda_mainnet" {
  count      = contains(var.enabled_networks, "mainnet") ? 1 : 0
  provider   = helm.mainnet
  name       = "keda"
  namespace  = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = "2.15.2"

  set {
    name  = "serviceAccount.operator.annotations.iam\\.gke\\.io/gcp-service-account"
    value = google_service_account.aptos_app_sa.email
  }

  set {
    name  = "podIdentity.gcp.enabled"
    value = true
  }
  set {
    name  = "podIdentity.gcp.gcpIAMServiceAccount"
    value = google_service_account.aptos_app_sa.email
  }

  depends_on = [
    google_container_node_pool.aptos["mainnet"],
    google_container_node_pool.aptos_apps["mainnet"],
    google_container_cluster.aptos_bq["mainnet"],
    kubernetes_namespace.aptos_namespace_keda_mainnet,
    google_service_account_iam_binding.aptos_app_sa
  ]
}

resource "helm_release" "keda_testnet" {
  count      = contains(var.enabled_networks, "testnet") ? 1 : 0
  provider   = helm.testnet
  name       = "keda"
  namespace  = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = "2.15.2"

  set {
    name  = "serviceAccount.operator.annotations.iam\\.gke\\.io/gcp-service-account"
    value = google_service_account.aptos_app_sa.email
  }

  set {
    name  = "podIdentity.gcp.enabled"
    value = true
  }
  set {
    name  = "podIdentity.gcp.gcpIAMServiceAccount"
    value = google_service_account.aptos_app_sa.email
  }

  depends_on = [
    google_container_node_pool.aptos["testnet"],
    google_container_node_pool.aptos_apps["testnet"],
    google_container_cluster.aptos_bq["testnet"],
    kubernetes_namespace.aptos_namespace_keda_testnet,
    google_service_account_iam_binding.aptos_app_sa
  ]
}

# # ScaledObject Helm Release for Keda (applied to all clusters)
resource "helm_release" "scaledObject_mainnet" {
  count     = contains(var.enabled_networks, "mainnet") ? 1 : 0
  provider  = helm.mainnet
  name      = "scaledobject"
  namespace = "mainnet"
  chart     = "../helm/keda"

  values = [
    file("../helm/keda/values.mainnet.yaml")
  ]

  depends_on = [
    google_container_node_pool.aptos["mainnet"],
    google_container_node_pool.aptos_apps["mainnet"],
    google_container_cluster.aptos_bq["mainnet"],
    kubernetes_namespace.aptos_namespace_keda_mainnet,
    helm_release.keda_mainnet,
  ]
}

resource "helm_release" "scaledObject_testnet" {
  count     = contains(var.enabled_networks, "testnet") ? 1 : 0
  provider  = helm.testnet
  name      = "scaledobject"
  namespace = "testnet"
  chart     = "../helm/keda"

  values = [
    file("../helm/keda/values.testnet.yaml")
  ]

  depends_on = [
    google_container_node_pool.aptos["testnet"],
    google_container_node_pool.aptos_apps["testnet"],
    google_container_cluster.aptos_bq["testnet"],
    kubernetes_namespace.aptos_namespace_keda_testnet,
    helm_release.keda_testnet
  ]
}
