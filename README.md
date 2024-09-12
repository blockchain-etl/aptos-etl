# Aptos ETL

This repo contains everything necessary to run an Aptos ETL pipeline (it is a monorepo).

## Architecture

The overall architecture is as follows:

### Data Source

An Aptos `mainnet` full node and `testnet` full node are both deployed in a Kubernetes cluster. These nodes act as the data source for this pipeline.

### Extraction and Transformation

1. Data extraction from the nodes and transformation into table records is performed by the Rust code in the `extractor_transformer/` directory. Two instances of this code will need to be deployed: one for `mainnet` and one for `testnet`, with the environment variables and CLI being configured for each network. This code should be deployed in Kubernetes, and it will need access to the Aptos node's gRPC port. It will also need to authenticate with GCP to dump the generated records into GCS buckets, and to subscribe to a Pub/Sub subscription.
2. To ensure that multiple instances of the `extractor_transformer` do not process the same data from the Aptos node, an *indexing coordinator* script will need to be deployed in Kubernetes as well (one for each network). This code is written in Python, and can be found in the `indexing_coordinator/` directory. It will need to authenticate with GCP to publish and subscribe to Pub/Sub topics.
3. The coordination performed by `indexing_coordinator` works by publishing ranges of transaction numbers (called "versions" on Aptos) to a Google Pub/Sub topic. The `extractor_transformer` instances each pull their tasks from the Pub/Sub topic, and make transaction requests to the node's gRPC interface in parallel. To ensure that the `extractor_transformer` instances do not receive the same messages from the Pub/Sub topic, all of them will use the same `subscription` to the topic. This is known as "competing consumers" or "competing subscribers". In testing, Pub/Sub seems to evenly distribute messages to each subscriber.

### Loading
Bath and stream loading are both supported.

If using the IAC scripts in this repo, the `mainnet` pipeline will use streaming inserts, and the `testnet` pipeline will use batch loading.
- Streaming works by publishing record as Protocol Buffers messages to Pub/Sub topics (one topic per table), which Dataflow then subscribes to and inserts into BigQuery.
- Batch loading works by uploading records as JSON files to Google Cloud Storage. Cloud Composer then copies these records from GCS to BigQuery hourly.

## Directories in this Repo

* `extractor_transformer`: Rust codebase for data extraction from the node, transformation into table records, and dumping into GCS buckets
* `indexing_coordinator`: Python codebase for coordinating multiple instances of `extractor_transformer` in Kubernetes
* `loader`: Cloud Composer scripts (aka Airflow DAGs) for loading data from GCS buckets into BigQuery
* `iac`: Infrastructure-as-code, such as terraform scripts, helm charts, and BigQuery tables and GCS buckets creation scripts
* `scripts`: Various utilities, such as build scripts for `extractor_transformer` and `indexing_coordinator`
* `schemas`: The table schemas for each of the BigQuery tables, in JSON format. Can be used to create the tables using `bq mk` command (also see `iac/create_tables.sh`)
