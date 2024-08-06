// Either assign values to the local variables directly or define them in the variables
locals {
  project_id       = var.project_id
  project_id_short = var.project_id_short
  project_number   = var.project_number
  region           = var.region
  env              = var.environment
  default_labels = {
    env        = var.environment
    managed-by = "terraform"
  }

  index_topics = {
    transaction_indexing_ranges_mainnet = "transaction-indexing-ranges-mainnet"
    transaction_indexing_ranges_testnet = "transaction-indexing-ranges-testnet"
    last_indexed_range_mainnet          = "last-indexed-range-mainnet"
    last_indexed_range_testnet          = "last-indexed-range-testnet"
  }

  schema_names = [
    "table_items",
    "transactions",
    "resources",
    "modules",
    "events",
    "blocks",
    "changes",
    "signatures",
  ]

  dataset_names = [
    "crypto_aptos_mainnet_us",
    "crypto_aptos_testnet_us",
    "mainnet_temp",
    "testnet_temp",
  ]

  network_types = ["mainnet", "testnet"]

  schemas_and_network_types = flatten([
    for schema in local.schema_names : [
      for network in local.network_types : {
        schema  = schema
        network = network
      }
    ]
  ])

  schemas_and_datasets = flatten([
    for dataset_name in local.dataset_names :
    [
      for schema_name in local.schema_names :
      {
        schema_file  = "${schema_name}.json"
        table_name   = schema_name
        dataset_name = dataset_name
      }
    ]
  ])

  dataflow_bucket = "gs://dataflow-templates-us-central1/latest/flex/PubSub_Proto_to_BigQuery_Flex"
}

variable "gke_master_ipv4_cidr_block" {
  type = string
}

variable "gke_node_machine_type" {
  type = string
}

variable "gke_node_disk_size_gb" {
  type    = number
  default = 200
}

variable "private_cidr_a" {
  type = string
}

variable "private_cidr_pods" {
  type = string
}

variable "private_cidr_services" {
  type = string
}

variable "min_master_version" {
  type = string
}

variable "nodepool_version" {
  type = string
}

variable "composer_version" {
  type = string
}

variable "composer_environment_names" {
  type = list(string)
}

variable "aptos_buckets" {
  type = list(string)
}

variable "environment" {
  type = string
}

variable "project_id" {
  type = string
}

variable "project_id_short" {
  type = string
}

variable "project_number" {
  type = string
}

variable "region" {
  type = string
}

variable "schemas" {
  type = list(string)
}
