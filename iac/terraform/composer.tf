resource "google_composer_environment" "composer_pipelines" {
  provider = google-beta
  for_each = toset(var.composer_environment_names)
  name     = each.value
  region   = local.region

  storage_config {
    bucket = "${local.project_id_short}-composer-dag-bucket-${each.value}"
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
      network         = google_compute_network.aptos-bq.id
      subnetwork      = google_compute_subnetwork.aptos-bq_k8s.id
      service_account = google_service_account.gcp_ingest_sa.name
    }
  }

  depends_on = [
    google_storage_bucket.composer_dag_bucket,
    google_service_account_iam_member.gcp_ingest_sa
  ]
}
