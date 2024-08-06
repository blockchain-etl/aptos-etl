# Aptos-ETL Scripts

This directory contains various scripts, including build scripts and utilities.

## Current scripts

`build_extractor_transformer.sh`

* Clones this repository and compiles the Rust code in `/aptos-etl/extractor_transformer/`.

`build_indexing_coordinator.sh`

* Clones this repository and generates the Python binding `pubsub_range_pb2.py` from the Protobuf file `pubsub_range.proto` in `/aptos-etl/indexing_coordinator/`.
* NOTE: the rest of the code in the `indexing_coordinator/` directory is written in Python, so it does not need to be compiled. The main script to run is `publish_ranges.py`, and a single instance of it should be deployed in Kubernetes. It will coordinate the Rust `extractor_transformer` instances in the same cluster.
