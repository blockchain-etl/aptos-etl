resource "google_compute_network" "aptos_bq" {
  for_each                = { for env in var.enabled_networks : env => env }
  name                    = "${local.project_id}-${each.key}"
  routing_mode            = "REGIONAL"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "aptos_bq_k8s" {
  for_each                 = { for env in var.enabled_networks : env => env }
  name                     = "${local.project_id}-${each.key}-k8s-${local.region}"
  ip_cidr_range            = var.private_cidr_a[each.key]
  network                  = google_compute_network.aptos_bq[each.key].id
  private_ip_google_access = true
  region                   = local.region

  secondary_ip_range {
    range_name    = "${local.project_id}-${each.key}-k8s-pods"
    ip_cidr_range = var.private_cidr_pods[each.key]
  }

  secondary_ip_range {
    range_name    = "${local.project_id}-${each.key}-k8s-services"
    ip_cidr_range = var.private_cidr_services[each.key]
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "google_compute_router" "aptos_bq" {
  for_each = { for env in var.enabled_networks : env => env }
  name     = "${local.project_id}-${each.key}-${local.region}"
  network  = google_compute_network.aptos_bq[each.key].id
}

resource "google_compute_router_nat" "aptos_bq" {
  for_each                            = { for env in var.enabled_networks : env => env }
  name                                = "${local.project_id}-${each.key}-${local.region}"
  router                              = google_compute_router.aptos_bq[each.key].name
  nat_ip_allocate_option              = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat  = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  enable_endpoint_independent_mapping = false

  min_ports_per_vm = 64

  log_config {
    enable = false
    filter = "ALL"
  }
}
