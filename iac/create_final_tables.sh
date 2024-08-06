gsutil -m cp gs://aptos_schemas/*.json ./ && \
bq mk --table --schema=table_items.json --range_partitioning=block_height,0,4000000000,1000000 --clustering_fields=block_timestamp,tx_version,change_type,address crypto_aptos_mainnet_us.table_items && \
bq mk --table --schema=transactions.json --range_partitioning=block_height,0,4000000000,1000000 --clustering_fields=block_timestamp,tx_version,sender,sequence_number crypto_aptos_mainnet_us.transactions && \
bq mk --table --schema=resources.json --range_partitioning=block_height,0,4000000000,1000000 --clustering_fields=block_timestamp,tx_version,change_type,address crypto_aptos_mainnet_us.resources && \
bq mk --table --schema=modules.json --range_partitioning=block_height,0,4000000000,1000000 --clustering_fields=block_timestamp,tx_version,name,address crypto_aptos_mainnet_us.modules && \
bq mk --table --schema=events.json --range_partitioning=block_height,0,4000000000,1000000 --clustering_fields=block_timestamp,tx_version,event_type,address crypto_aptos_mainnet_us.events && \
bq mk --table --schema=blocks.json --range_partitioning=block_height,0,4000000000,1000000 --clustering_fields=block_timestamp,blockmetadata_tx_version,proposer,round crypto_aptos_mainnet_us.blocks && \
bq mk --table --schema=changes.json --range_partitioning=block_height,0,4000000000,1000000 --clustering_fields=block_timestamp,tx_version,change_type,state_key_hash crypto_aptos_mainnet_us.changes && \
bq mk --table --schema=signatures.json --range_partitioning=block_height,0,4000000000,1000000 --clustering_fields=block_timestamp,tx_version,build_type,signer crypto_aptos_mainnet_us.signatures && \
bq mk --table --schema=table_items.json --range_partitioning=block_height,0,4000000000,1000000 --clustering_fields=block_timestamp,tx_version,change_type,address crypto_aptos_testnet_us.table_items && \
bq mk --table --schema=transactions.json --range_partitioning=block_height,0,4000000000,1000000 --clustering_fields=block_timestamp,tx_version,sender,sequence_number crypto_aptos_testnet_us.transactions && \
bq mk --table --schema=resources.json --range_partitioning=block_height,0,4000000000,1000000 --clustering_fields=block_timestamp,tx_version,change_type,address crypto_aptos_testnet_us.resources && \
bq mk --table --schema=modules.json --range_partitioning=block_height,0,4000000000,1000000 --clustering_fields=block_timestamp,tx_version,name,address crypto_aptos_testnet_us.modules && \
bq mk --table --schema=events.json --range_partitioning=block_height,0,4000000000,1000000 --clustering_fields=block_timestamp,tx_version,event_type,address crypto_aptos_testnet_us.events && \
bq mk --table --schema=blocks.json --range_partitioning=block_height,0,4000000000,1000000 --clustering_fields=block_timestamp,blockmetadata_tx_version,proposer,round crypto_aptos_testnet_us.blocks && \
bq mk --table --schema=changes.json --range_partitioning=block_height,0,4000000000,1000000 --clustering_fields=block_timestamp,tx_version,change_type,state_key_hash crypto_aptos_testnet_us.changes && \
bq mk --table --schema=signatures.json --range_partitioning=block_height,0,4000000000,1000000 --clustering_fields=block_timestamp,tx_version,build_type,signer crypto_aptos_testnet_us.signatures
