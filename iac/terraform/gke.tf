locals {
  k8s_node_locations = ["${local.region}-c"]

  k8s_node_tag = "${local.project_id}-${local.env}-k8s-node"
}

resource "google_pubsub_topic" "aptos-bq" {
  name = "${local.project_id}-${local.env}"

  labels = local.default_labels
}


resource "google_container_cluster" "aptos-bq" {
  provider                    = google-beta
  name                        = "${local.project_id}-${local.env}"
  location                    = local.region
  network                     = google_compute_network.aptos-bq.self_link
  subnetwork                  = google_compute_subnetwork.aptos-bq_k8s.self_link
  networking_mode             = "VPC_NATIVE"
  enable_intranode_visibility = true
  datapath_provider           = "ADVANCED_DATAPATH"
  min_master_version          = var.min_master_version

  node_locations           = local.k8s_node_locations
  initial_node_count       = 1
  remove_default_node_pool = true
  deletion_protection      = false

  release_channel { channel = "REGULAR" }
  binary_authorization { evaluation_mode = "DISABLED" }
  cluster_autoscaling { autoscaling_profile = "OPTIMIZE_UTILIZATION" }


  addons_config {
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
    gke_backup_agent_config {
      enabled = true
    }
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "${local.project_id}-${local.env}-k8s-pods"
    services_secondary_range_name = "${local.project_id}-${local.env}-k8s-services"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.gke_master_ipv4_cidr_block
  }

  workload_identity_config {
    workload_pool = "${local.project_id}.svc.id.goog"
  }

  logging_config { enable_components = ["SYSTEM_COMPONENTS"] }


  monitoring_config {
    managed_prometheus {
      enabled = false
    }
  }

  notification_config {
    pubsub {
      enabled = true
      topic   = google_pubsub_topic.aptos-bq.id
    }
  }


  resource_labels = local.default_labels

}

resource "google_container_node_pool" "aptos-mainnet" {
  name     = "aptos-mainnet"
  cluster  = google_container_cluster.aptos-bq.name
  location = local.region
  # version        = var.nodepool_version
  node_locations = local.k8s_node_locations

  initial_node_count = 1

  autoscaling {
    location_policy      = "ANY"
    total_min_node_count = 1
    total_max_node_count = 10
  }

  lifecycle {
    ignore_changes = [
      initial_node_count
    ]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    preemptible  = false
    machine_type = var.gke_node_machine_type
    image_type   = "COS_CONTAINERD"
    disk_size_gb = var.gke_node_disk_size_gb

    workload_metadata_config { mode = "GKE_METADATA" }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    service_account = google_service_account.k8s_cluster.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    resource_labels = local.default_labels

    tags = [local.k8s_node_tag]
    taint {
      key    = "usage"
      value  = "aptos-mainnet"
      effect = "NO_SCHEDULE"
    }
  }
}

resource "google_container_node_pool" "aptos-testnet" {
  name     = "aptos-testnet"
  cluster  = google_container_cluster.aptos-bq.name
  location = local.region
  # version        = var.nodepool_version
  node_locations = local.k8s_node_locations

  initial_node_count = 1

  autoscaling {
    location_policy      = "ANY"
    total_min_node_count = 1
    total_max_node_count = 10
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  lifecycle {
    ignore_changes = [
      initial_node_count
    ]
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    preemptible  = false
    machine_type = var.gke_node_machine_type
    image_type   = "COS_CONTAINERD"
    disk_size_gb = var.gke_node_disk_size_gb

    workload_metadata_config { mode = "GKE_METADATA" }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    service_account = google_service_account.k8s_cluster.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    resource_labels = local.default_labels

    tags = [local.k8s_node_tag]

    taint {
      key    = "usage"
      value  = "aptos-testnet"
      effect = "NO_SCHEDULE"
    }
  }
}

resource "google_container_node_pool" "aptos-apps" {
  name     = "aptos-apps"
  cluster  = google_container_cluster.aptos-bq.name
  location = local.region
  # version        = var.nodepool_version
  node_locations = local.k8s_node_locations

  initial_node_count = 1

  autoscaling {
    location_policy      = "ANY"
    total_min_node_count = 1
    total_max_node_count = 10
  }

  lifecycle {
    ignore_changes = [
      initial_node_count
    ]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    preemptible  = false
    machine_type = var.gke_node_machine_type
    image_type   = "COS_CONTAINERD"
    disk_size_gb = var.gke_node_disk_size_gb

    workload_metadata_config { mode = "GKE_METADATA" }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    service_account = google_service_account.k8s_cluster.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    resource_labels = local.default_labels

    tags = [local.k8s_node_tag]
  }

}

resource "google_compute_firewall" "shadow_allow_master" {
  name      = "${local.project_id_short}-${local.env}-k8s-master"
  network   = google_compute_network.aptos-bq.self_link
  direction = "INGRESS"

  source_ranges = [var.gke_master_ipv4_cidr_block]
  target_tags   = [local.k8s_node_tag]

  allow {
    protocol = "tcp"
    ports    = ["10250", "443", "8443"]
  }

  lifecycle {
    replace_triggered_by = [google_compute_network.aptos-bq]
  }
}
