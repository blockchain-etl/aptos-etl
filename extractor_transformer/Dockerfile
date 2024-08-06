FROM rust:1.80.1 as builder
WORKDIR /usr/src/blockchain_etl_indexer

# Install rustfmt
RUN rustup component add rustfmt

COPY . .

RUN apt update && apt install -y protobuf-compiler libpq5 libdw-dev
ARG FEATURE

ENV RUSTFLAGS="-C target-feature=+crt-static"
# Use the build-time argument to specify features
RUN cargo install --path . --features $FEATURE --target=x86_64-unknown-linux-gnu

FROM debian:stable-slim
WORKDIR /app

RUN apt update \
    && apt install -y openssl ca-certificates libpq5 \
    && apt clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Expose the metrics port for Prometheus
EXPOSE 4000
# Expose the port for kubernetes probes
EXPOSE 8080

COPY --from=builder /usr/local/cargo/bin/blockchain_etl_indexer /usr/local/bin/blockchain_etl_indexer

# CMD ["blockchain_etl_indexer", "index-subscription", "indexing-ranges-subscription-mainnet"]
