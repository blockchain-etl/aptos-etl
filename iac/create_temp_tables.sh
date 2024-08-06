gsutil -m cp gs://aptos_schemas/*.json ./ && \
bq mk --table --schema=transactions.json --time_partitioning_type HOUR --time_partitioning_expiration 21600 --clustering_fields=block_timestamp mainnet_temp.transactions && \
bq mk --table --schema=resources.json --time_partitioning_type HOUR --time_partitioning_expiration 21600 --clustering_fields=block_timestamp mainnet_temp.resources && \
bq mk --table --schema=modules.json --time_partitioning_type HOUR --time_partitioning_expiration 21600 --clustering_fields=block_timestamp mainnet_temp.modules && \
bq mk --table --schema=events.json --time_partitioning_type HOUR --time_partitioning_expiration 21600 --clustering_fields=block_timestamp mainnet_temp.events && \
bq mk --table --schema=blocks.json --time_partitioning_type HOUR --time_partitioning_expiration 21600 --clustering_fields=block_timestamp mainnet_temp.blocks && \
bq mk --table --schema=changes.json --time_partitioning_type HOUR --time_partitioning_expiration 21600 --clustering_fields=block_timestamp mainnet_temp.changes && \
bq mk --table --schema=signatures.json --time_partitioning_type HOUR --time_partitioning_expiration 21600 --clustering_fields=block_timestamp mainnet_temp.signatures && \
bq mk --table --schema=table_items.json --time_partitioning_type HOUR --time_partitioning_expiration 21600 --clustering_fields=block_timestamp testnet_temp.table_items && \
bq mk --table --schema=transactions.json --time_partitioning_type HOUR --time_partitioning_expiration 21600 --clustering_fields=block_timestamp testnet_temp.transactions && \
bq mk --table --schema=resources.json --time_partitioning_type HOUR --time_partitioning_expiration 21600 --clustering_fields=block_timestamp testnet_temp.resources && \
bq mk --table --schema=modules.json --time_partitioning_type HOUR --time_partitioning_expiration 21600 --clustering_fields=block_timestamp testnet_temp.modules && \
bq mk --table --schema=events.json --time_partitioning_type HOUR --time_partitioning_expiration 21600 --clustering_fields=block_timestamp testnet_temp.events && \
bq mk --table --schema=blocks.json --time_partitioning_type HOUR --time_partitioning_expiration 21600 --clustering_fields=block_timestamp testnet_temp.blocks && \
bq mk --table --schema=changes.json --time_partitioning_type HOUR --time_partitioning_expiration 21600 --clustering_fields=block_timestamp testnet_temp.changes && \
bq mk --table --schema=signatures.json --time_partitioning_type HOUR --time_partitioning_expiration 21600 --clustering_fields=block_timestamp testnet_temp.signatures
