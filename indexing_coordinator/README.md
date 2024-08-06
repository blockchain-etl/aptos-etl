# Indexing Coordinator

The Python scripts in this directory are used to coordinate multiple instances of the `extractor_transformer` in Kubernetes.

## System Requirements

* protobuf compiler `protoc` for generating Python code from `pubsub_range.proto`
* python 3
* Authentication with GCP. The script looks for a key using the `GOOGLE_APPLICATION_CREDENTIALS` environment variable. This code only uses this authentication for subscribing and publishing to Google Pub/Sub topics.

## Deployment

A single instance of the `publish_ranges.py` script should be run in Kubernetes. This script imports code from `pubsub_range_pb2.py` which was generated from the `pubsub_range.proto` code using the `compile_protos.sh` build script.

Currently, there is no Dockerfile for this code.

## Compile / Build

Generate the `pubsub_range_pb2.py` code from the protobuf file `pubsub_range.proto`:

```bash
protoc pubsub_range.proto --python_out=.
```

## Environment Variables

* `NODE_ADDRESS` this is the full address of the Aptos node's **REST** api (NOT gRPC). IMPORTANT: if deploying for mainnet, make sure to use the address of the mainnet node's API. Likewise, if deploying for testnet, use the address of the testnet node's API.
* `NETWORK` this is either `mainnet` or `testnet` depending on which pipeline you are deploying for.
* `GCP_PROJECT_ID` should be `aptos-bq`
* `GOOGLE_APPLICATION_CREDENTIALS` this is used to authenticate with GCP. Currently only used for authentication for subscribing and publishing to Google Pub/Sub topics.

See the `.env.example` file for some examples used during testing.

## CLI

No command line arguments are needed. The code can be run using:

```bash
python3 publish_ranges.py
```
