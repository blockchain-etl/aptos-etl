resource "google_compute_network" "aptos-bq" {
  name                    = "${local.project_id}-${local.env}"
  routing_mode            = "REGIONAL"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "aptos-bq_k8s" {
  name                     = "${local.project_id}-${local.env}-k8s-${local.region}"
  ip_cidr_range            = var.private_cidr_a
  network                  = google_compute_network.aptos-bq.id
  private_ip_google_access = true
  region                   = local.region

  secondary_ip_range {
    range_name    = "${local.project_id}-${local.env}-k8s-pods"
    ip_cidr_range = var.private_cidr_pods
  }

  secondary_ip_range {
    range_name    = "${local.project_id}-${local.env}-k8s-services"
    ip_cidr_range = var.private_cidr_services
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "google_compute_router" "aptos-bq" {
  name    = "${local.project_id}-${local.env}-${local.region}"
  network = google_compute_network.aptos-bq.id
}

resource "google_compute_router_nat" "aptos-bq" {
  name                                = "${local.project_id}-${local.env}-${local.region}"
  router                              = google_compute_router.aptos-bq.name
  nat_ip_allocate_option              = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat  = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  enable_endpoint_independent_mapping = false

  min_ports_per_vm = 64
  log_config {
    enable = false
    filter = "ALL"
  }
}
