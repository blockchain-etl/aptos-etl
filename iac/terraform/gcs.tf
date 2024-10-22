resource "google_storage_bucket" "composer_dag_bucket" {
  for_each      = toset(var.enabled_networks)
  name          = "${local.project_id_short}-composer-dag-bucket-${each.value}"
  location      = local.region
  force_destroy = true
}

resource "google_storage_bucket" "fullnode_backups" {
  for_each      = toset(["mainnet", "testnet"])
  name          = "${local.project_id_short}-${local.env}-${each.key}-backups"
  location      = local.region
  storage_class = "STANDARD"

  force_destroy = false

  versioning { enabled = true }

  lifecycle_rule {
    condition { num_newer_versions = 5 }
    action { type = "Delete" }
  }

  labels = local.default_labels
}

resource "google_storage_bucket" "aptos_buckets" {
  for_each      = { for name in var.aptos_buckets : name => name }
  name          = "${local.project_id}-${each.key}"
  location      = local.region
  storage_class = "STANDARD"
  force_destroy = true
}

locals {
  files = fileset("schemas", "**")
}

data "local_file" "schema_files" {
  for_each = { for file in local.files : file => file }

  filename = "schemas/${each.value}"
}

resource "google_storage_bucket_object" "schema_objects" {
  for_each   = data.local_file.schema_files
  name       = trimprefix(each.value.filename, "schemas/")
  bucket     = "${local.project_id}-aptos_schemas"
  source     = each.value.filename
  depends_on = [google_storage_bucket.aptos_buckets]
}
