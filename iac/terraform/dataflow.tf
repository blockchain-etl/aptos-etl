resource "google_dataflow_flex_template_job" "aptos_dataflow_jobs" {
  for_each = { for idx, schema in var.schemas : idx => schema }

  provider                = google-beta
  name                    = "mainnet-${replace(each.value, "_", "-")}-job-prod"
  container_spec_gcs_path = local.dataflow_bucket
  service_account_email   = google_service_account.gcp_ingest_sa.email
  parameters = {
    outputTopic       = "projects/${local.project_id}/topics/errors-${each.value}-mainnet"
    protoSchemaPath   = "gs://${local.project_id}-aptos_schemas/${each.value}.pb"
    inputSubscription = "projects/${local.project_id}/subscriptions/${replace(trimsuffix(each.value, "s"), "_", "-")}-records-mainnet-sub"
    outputTableSpec   = "aptos-data-pdp:crypto_aptos_mainnet_us.${each.value}"
    fullMessageName = "aptos.${each.value}.${
      each.value == "blocks" ? "Block" :
      each.value == "modules" ? "Module" :
      each.value == "table_items" ? "TableItem" :
      each.value == "signatures" ? "Signature" :
      each.value == "changes" ? "Change" :
      each.value == "resources" ? "Resource" :
      each.value == "events" ? "Event" :
      each.value == "transactions" ? "Transaction" :
      "Unknown"
    }"
    writeDisposition        = "WRITE_APPEND"
    createDisposition       = "CREATE_NEVER"
    bigQueryTableSchemaPath = "gs://${local.project_id}-aptos_schemas/${each.value}.json"
    preserveProtoFieldNames = "true"
  }
  additional_experiments = ["streaming_mode_at_least_once"]
  depends_on = [
    google_pubsub_subscription.records_subs,
    google_storage_bucket_object.schema_objects
  ]
}
