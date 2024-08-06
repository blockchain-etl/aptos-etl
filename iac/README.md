# Aptos-ETL Infrastructure-as-code
This directory should contain IAC scripts like `helm` charts for kubernetes, and terraform scripts for deploying services like the Aptos node cluster.

## Current scripts:
`Dockerfile`
* This is specifically for the Rust code in `extractor_transformer/`. Multiple of these container instances should be run in kubernetes.

`create_buckets.sh`
* This script creates 16 GCS buckets, because we have 8 tables and 2 datasets (using data from Aptos' mainnet and testnet networks).
* The Rust code in `extractor_transformer/` will dump records for each table & network into the associated bucket.

`create_tables.sh`
* This script uses the 8 table schemas in `aptos-etl/schemas/` to create 16 tables: 8 in the mainnet dataset and 8 in the testnet dataset.
* This script creates the tables with integer-range partitioning using the `block_height` column (with step of 1,000,000).
