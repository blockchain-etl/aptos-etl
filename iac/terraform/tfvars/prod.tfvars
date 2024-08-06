gke_master_ipv4_cidr_block = <GKE master node IP CIDR>
environment                = <environment name>
project_id                 = <GCP project name>
project_id_short           = <GCP project short name>
project_number             = <GCP project number>
region                     = <GCP region>
gke_node_machine_type      = <GKE node instance type>
private_cidr_a             = <subnetwork IP CIDR>
private_cidr_pods          = <pod network IP CIDR>
private_cidr_services      = <service network IP CIDR>
min_master_version         = <master node Kubernetes version>
nodepool_version           = <worker node kubernetess version>

composer_version           = "composer-2.6.2-airflow-2.6.3"
composer_environment_names = ["mainnet-testnet"]
aptos_buckets = [
  "aptos_testnet_blocks",
  "aptos_testnet_transactions",
  "aptos_testnet_changes",
  "aptos_testnet_events",
  "aptos_testnet_modules",
  "aptos_testnet_resources",
  "aptos_testnet_signatures",
  "aptos_testnet_table_items",
  "aptos_schemas",
]

schemas = [
  "signatures",
  "modules",
  "changes",
  "resources",
  "table_items",
  "events",
  "transactions",
  "blocks",
]
