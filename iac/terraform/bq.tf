data "google_storage_bucket_object_content" "schema_files" {
  for_each   = toset(local.schema_names)
  name       = "${each.value}.json"
  bucket     = "${local.project_id}-aptos_schemas"
  depends_on = [google_storage_bucket_object.schema_objects]
}

resource "google_bigquery_dataset" "aptos_dataset" {
  for_each                    = toset(local.dataset_names)
  dataset_id                  = each.value
  max_time_travel_hours       = 168
  storage_billing_model       = "LOGICAL"
  location                    = local.region
  is_case_insensitive         = false
  default_table_expiration_ms = each.value == "mainnet_temp" || each.value == "testnet_temp" ? 21600000 : null

  labels = local.default_labels

}

// This block requires the local_file resource to be created first
resource "google_bigquery_table" "aptos_tables" {
  for_each            = { for item in local.schemas_and_datasets : "${item.dataset_name}.${item.table_name}" => item }
  dataset_id          = each.value.dataset_name
  table_id            = each.value.table_name
  deletion_protection = false

  labels = local.default_labels

  schema = data.google_storage_bucket_object_content.schema_files[each.value.table_name].content

  range_partitioning {
    field = "block_height"
    range {
      start    = 0
      end      = 4000000000
      interval = 1000000
    }
  }
  clustering = ["block_timestamp"]

  lifecycle {
    ignore_changes = all
  }

  depends_on = [
    google_bigquery_dataset.aptos_dataset
  ]
}
