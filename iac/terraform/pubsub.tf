locals {
  def_files = [for file in fileset("schemas", "**.schema") : file]
}

data "local_file" "schema_defs" {
  for_each = { for file in local.def_files : file => file }

  filename = "schemas/${each.key}"
}


resource "google_pubsub_schema" "pubsub_schemas" {
  #   for_each   = toset(concat(local.schema_names, ["indexing-range-pb"]))
  for_each   = { for file, _ in data.local_file.schema_defs : file => file }
  name       = trimsuffix(each.value, ".schema")
  type       = "PROTOCOL_BUFFER"
  definition = data.local_file.schema_defs[each.key].content
}

resource "google_pubsub_topic" "records_topics" {
  for_each = {
    for item in local.schemas_and_network_types : "${item.schema}-${item.network}" => item
  }

  name = "${trimsuffix(each.value.schema, "s")}-records-${each.value.network}"

  depends_on = [google_pubsub_schema.pubsub_schemas]
  schema_settings {
    schema   = "projects/${local.project_id}/schemas/${each.value.schema}"
    encoding = "BINARY"
  }
}

resource "google_pubsub_topic" "errors_topics" {
  for_each = {
    for item in local.schemas_and_network_types : "${item.schema}-${item.network}" => item
  }
  name                       = "errors-${each.value.schema}-records-${each.value.network}"
  message_retention_duration = "2678400s"
}

resource "google_pubsub_topic" "transaction_index_topics" {
  for_each   = local.index_topics
  name       = each.value
  depends_on = [google_pubsub_schema.pubsub_schemas]
  schema_settings {
    schema   = "projects/${local.project_id}/schemas/indexing-range-pb"
    encoding = "BINARY"
  }
}

resource "google_pubsub_subscription" "records_subs" {
  for_each = {
    for item in local.schemas_and_network_types : "${item.schema}-${item.network}" => item
  }
  name                       = "${trimsuffix(each.value.schema, "s")}-records-${each.value.network}-sub"
  topic                      = "projects/${local.project_id}/topics/${trimsuffix(each.value.schema, "s")}-records-${each.value.network}"
  message_retention_duration = "604800s"
  ack_deadline_seconds       = 10

  expiration_policy {
    ttl = "2678400s"
  }

  depends_on = [google_pubsub_topic.records_topics]
}

resource "google_pubsub_subscription" "transaction_index_subs" {
  for_each                   = local.index_topics
  name                       = "${each.value}-sub"
  topic                      = "projects/${local.project_id}/topics/${each.value}"
  message_retention_duration = "604800s"
  ack_deadline_seconds       = 10
  expiration_policy {
    ttl = "2678400s"
  }

  depends_on = [google_pubsub_topic.transaction_index_topics]
}

