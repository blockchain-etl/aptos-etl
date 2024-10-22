resource "google_composer_environment" "composer_pipelines" {
  for_each = { for env in var.enabled_networks : env => env }
  provider = google-beta
  name     = each.key
  region   = local.region

  storage_config {
    bucket = "${local.project_id_short}-composer-dag-bucket-${each.key}"
  }
  config {

    software_config {
      image_version = var.composer_version
      airflow_config_overrides = {
        core-enable_xcom_pickling = true,
      }

    }

    workloads_config {
      scheduler {
        cpu        = 2
        memory_gb  = 7.5
        storage_gb = 5
        count      = 2
      }
      triggerer {
        cpu       = 0.5
        memory_gb = 0.5
        count     = 1
      }
      worker {
        cpu        = 2
        memory_gb  = 7.5
        storage_gb = 5
        min_count  = 2
        max_count  = 6
      }
    }

    environment_size = "ENVIRONMENT_SIZE_MEDIUM"

    node_config {
      network         = google_compute_network.aptos_bq[each.key].id
      subnetwork      = google_compute_subnetwork.aptos_bq_k8s[each.key].id
      service_account = google_service_account.gcp_ingest_sa.name
    }
  }

  depends_on = [
    google_storage_bucket.composer_dag_bucket,
    google_service_account_iam_member.gcp_ingest_sa,
    google_service_account.gcp_ingest_sa,
    google_project_iam_member.composer_service_agent_role,
    google_project_iam_member.gcp_ingest_sa
  ]
}
