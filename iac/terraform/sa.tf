# Service Accounts
resource "google_service_account" "k8s_cluster" {
  account_id   = "${local.project_id}-${local.env}-k8s"
  display_name = "${local.project_id}-${local.env}-k8s"
}

resource "google_service_account" "k8s_storage" {
  account_id   = "${local.project_id_short}-${local.env}-k8s-storage"
  display_name = "${local.project_id_short}-${local.env}-k8s-storage"
}

resource "google_service_account" "aptos_app_sa" {
  account_id   = "${local.project_id}-${local.env}-aptos-app"
  display_name = "${local.project_id}-${local.env}-aptos-app"
}

resource "google_service_account" "gcp_ingest_sa" {
  account_id   = "aptos-gcp-ingest-sa"
  display_name = "aptos-gcp-ingest-sa"
}


# IAM Roles and Workload Identity Binding
locals {

  k8s_cluster_iam_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/storage.objectViewer",
    "roles/artifactregistry.reader",
  ]

  k8s_storage_iam_roles = [
    "roles/storage.objectViewer",
    "roles/storage.objectAdmin",
    "roles/storage.admin",
  ]


  ci_iam_roles = [
    "roles/storage.objectAdmin",
    "roles/storage.admin",
    "roles/container.clusterViewer",
    "roles/container.admin",
    "roles/container.developer",
  ]

  aptos_app_iam_roles = [
    "roles/pubsub.publisher",
    "roles/pubsub.subscriber",
    "roles/pubsub.viewer",
    "roles/storage.admin",
    "roles/monitoring.viewer",
    "roles/monitoring.metricWriter",
    "roles/storage.objectCreator",
  ]

  gcp_ingest_iam_roles = [
    "roles/bigquery.dataOwner",
    "roles/bigquery.jobUser",
    "roles/composer.worker",
    "roles/dataflow.worker",
  ]
}

# IAM Members for K8s Cluster
resource "google_project_iam_member" "k8s_cluster" {
  for_each = toset(local.k8s_cluster_iam_roles)
  project  = local.project_id
  role     = each.key
  member   = "serviceAccount:${google_service_account.k8s_cluster.email}"
}

# IAM Members for K8s Storage
resource "google_project_iam_member" "k8s_storage" {
  for_each = toset(local.k8s_storage_iam_roles)
  project  = local.project_id
  role     = each.key
  member   = "serviceAccount:${google_service_account.k8s_storage.email}"
}

# Workload Identity Binding for K8s Storage
resource "google_service_account_iam_binding" "k8s_storage" {
  service_account_id = google_service_account.k8s_storage.name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:${local.project_id}.svc.id.goog[mainnet/mainnet-aptos-fullnode]",
    "serviceAccount:${local.project_id}.svc.id.goog[testnet/testnet-aptos-fullnode]",
  ]

  depends_on = [google_container_cluster.aptos_bq]
}


# IAM Members for Aptos App Service Account
resource "google_project_iam_member" "aptos_app_sa" {
  for_each = toset(local.aptos_app_iam_roles)
  project  = local.project_id
  role     = each.key
  member   = "serviceAccount:${google_service_account.aptos_app_sa.email}"
}

# Workload Identity Binding for Aptos App Service Account
resource "google_service_account_iam_binding" "aptos_app_sa" {
  service_account_id = google_service_account.aptos_app_sa.name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:${local.project_id}.svc.id.goog[mainnet/aptos-app-sa]",
    "serviceAccount:${local.project_id}.svc.id.goog[testnet/aptos-app-sa]",
    "serviceAccount:${local.project_id}.svc.id.goog[keda/keda-operator]"
  ]

  depends_on = [google_container_cluster.aptos_bq]
}

resource "google_project_iam_member" "gcp_ingest_sa" {
  for_each   = toset(local.gcp_ingest_iam_roles)
  project    = local.project_id
  role       = each.key
  member     = google_service_account.gcp_ingest_sa.member
  depends_on = [google_container_cluster.aptos_bq]
}

resource "google_service_account_iam_member" "gcp_ingest_sa" {
  provider           = google-beta
  service_account_id = google_service_account.gcp_ingest_sa.name
  role               = "roles/composer.ServiceAgentV2Ext"
  member             = "serviceAccount:service-${local.project_number}@cloudcomposer-accounts.iam.gserviceaccount.com"
}


resource "google_project_iam_member" "composer_service_agent_role" {
  project = local.project_id
  role    = "roles/composer.ServiceAgentV2Ext"
  member  = "serviceAccount:${local.project_number}-compute@developer.gserviceaccount.com"
}

