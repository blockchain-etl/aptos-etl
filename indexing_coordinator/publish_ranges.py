# TODO: support health checks for kubernetes (liveness and readiness)

print("Starting up...")

import os
import requests
import time
import math
import signal
import sys
from google.cloud import pubsub_v1
from pubsub_range_pb2 import IndexingRange

assert(os.environ.get("NODE_ADDRESS") is not None)
assert(os.environ.get("GCP_PROJECT_ID") is not None)
assert(os.environ.get("NETWORK") is not None)
assert(os.environ.get("NETWORK") == "mainnet" or os.environ.get("NETWORK") == "testnet")

NODE_ADDRESS = os.environ.get("NODE_ADDRESS")
FALLBACK_NODE_ADDRESS = os.environ.get("FALLBACK_NODE_ADDRESS")
GCP_PROJECT_ID =  os.environ.get("GCP_PROJECT_ID")
NETWORK = os.environ.get("NETWORK")

# the name is what it's called in our GCP project, but the path is what's used by the API
INDEXING_RANGES_TOPIC_NAME = f"transaction-indexing-ranges-{NETWORK}"
INDEXING_RANGES_TOPIC_PATH = f"projects/{GCP_PROJECT_ID}/topics/{INDEXING_RANGES_TOPIC_NAME}"
STATEFUL_RESUMPTION_TOPIC_NAME = f"last-indexed-range-{NETWORK}"
STATEFUL_RESUMPTION_TOPIC_PATH = f'projects/{GCP_PROJECT_ID}/topics/{STATEFUL_RESUMPTION_TOPIC_NAME}'

indexing_range_serialized = None

def signal_handler(sig, frame):
    ''' for handling interrupts (currently SIGINT and SIGTERM) '''
    if sig == signal.SIGINT:
        print('Interrupted by user (SIGINT)')
    elif sig == signal.SIGTERM:
        print('Termination signal received (SIGTERM)')
    else:
        print("Received an unexpected signal. Ignoring...")
        return
    assert(indexing_range_serialized is not None)
    future = publisher.publish(topic=STATEFUL_RESUMPTION_TOPIC_PATH, data=indexing_range_serialized)
    print(future.result())
    sys.exit(0)

# Register the signal handlers for SIGINT and SIGTERM
signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

def make_request_with_exponential_backoff(initial_delay=1, max_delay=60):
    '''makes an http request. increases the time between requests exponentially,
    until it reaches the `max_delay`. if the FALLBACK_NODE_ADDRESS env var was supplied,
    then requests will alternate between the NODE_ADDRESS and FALLBACK_NODE_ADDRESS'''

    attempt = 0
    while True:
        try:
            response = None
            if FALLBACK_NODE_ADDRESS is not None and attempt % 2 == 1:
                response = requests.get(FALLBACK_NODE_ADDRESS)
            else:
                response = requests.get(NODE_ADDRESS)
            response.raise_for_status()  # Raises an error for 4xx/5xx responses
            return response
        except requests.RequestException as e:
            wait_time = min(max_delay, initial_delay * 2 ** attempt)
            attempt += 1
            print(f"Waiting {wait_time} seconds before retrying...")
            time.sleep(wait_time)
    '''
    example response:
    {
        "chain_id":2,
        "epoch":"12535",
        "ledger_version":"896675961",
        "oldest_ledger_version":"0",
        "ledger_timestamp":"1707777175903137"
        "node_role":"full_node",
        "oldest_block_height":"0",
        "block_height":"214561141",
        "git_hash":"9c0afd458d3428d8d087102b5490144bc1586e6d"
    }

    NOTE: we only need the `ledger_version`
    '''

def range_generator(start, end, step=999):
    '''Divides a range by steps of 1000 values each. Yields values
    using lazy evaluation'''
    current = start
    while current < end:
        # Calculate the next position but ensure it does not exceed 'end'
        next_position = min(current + step - 1, end - 1)
        print("yielding range:", current, next_position + 1)
        yield range(current, next_position + 1)
        # Advance for the next iteration, ensuring disjoint ranges
        current = next_position + 1


# this publisher will be used for publishing to both the `IndexingRange` topic and the stateful resumption topic `last-indexed-range`
publisher = pubsub_v1.PublisherClient()

def pick_up_from_previous_run():
    last_indexed_range_subscriber = pubsub_v1.SubscriberClient()
    subscription_path = last_indexed_range_subscriber.subscription_path(GCP_PROJECT_ID, f"last-indexed-range-{NETWORK}-sub")

    last_indexed_end = None
    while last_indexed_end is None:
        print("Attempting to pull a message from the resumption subscription...")
        # Pull a single message
        response = last_indexed_range_subscriber.pull(
            request={"subscription": subscription_path, "max_messages": 1},
        )

        if response.received_messages:
            received_message = response.received_messages[0]
            indexing_range = IndexingRange()
            indexing_range.ParseFromString(received_message.message.data)
            last_indexed_end = indexing_range.end
            print(f"Received message: {indexing_range}")
            ack_id = received_message.ack_id
            last_indexed_range_subscriber.acknowledge(request={"subscription": subscription_path, "ack_ids": [ack_id]})
            break
        else:
            print("No messages. Starting from genesis...")
            last_indexed_end = -1
            break

    last_indexed_range_subscriber.close()
    return last_indexed_end

last_indexed_end = pick_up_from_previous_run()
assert(last_indexed_end is not None)

def get_ledger_version() -> int:
    ''' retrieves the current `ledger_version` from the node's REST API '''
    response = make_request_with_exponential_backoff()
    json_response = response.json()
    ledger_version_raw: str = json_response.get("ledger_version")
    ledger_version: int = int(ledger_version_raw)
    return ledger_version

# continually requests the maximum available transaction version from the node
while True:
    # wait 1 second between requests (don't want to overload the node with requests, or else it could desync)
    time.sleep(5)
    ledger_version = get_ledger_version()

    print("new ledger_version is", ledger_version)

    # construct indexing ranges from the ledger version, then serialize, and finally publish.
    # NOTE: we use `+ 1` as the next starting value because we don't want to re-index the previous end value.
    for r in range_generator(last_indexed_end + 1, ledger_version):
        indexing_range_proto_obj = IndexingRange(start=r.start, end=r.stop) # fun fact: positional arguments don't work with protobuf initializers
        indexing_range_serialized = indexing_range_proto_obj.SerializeToString()
        assert(indexing_range_serialized is not None)

        future = publisher.publish(topic=INDEXING_RANGES_TOPIC_PATH, data=indexing_range_serialized)
        print(future.result())

    # advance the range for the next iteration
    last_indexed_end = ledger_version
