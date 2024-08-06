from concurrent.futures import TimeoutError
from google.cloud import pubsub_v1
import os
import logging

# TODO(developer)
# project_id = "your-project-id"
# subscription_id = "your-subscription-id"
# Number of seconds the subscriber should listen for messages
# timeout = 5.0
logging.getLogger('google.cloud.pubsub_v1').setLevel(logging.ERROR)

os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "/Users/julian/work/bcw/aptos-etl/iac/range_publisher/aptos-bq-6794af7285c9.json"
PUBSUB_TOPIC = 'projects/{project_id}/topics/{topic}'.format(
    project_id='aptos-bq', #os.getenv('GOOGLE_CLOUD_PROJECT'),
    topic='transaction-indexing-ranges-mainnet',
)

subscriber = pubsub_v1.SubscriberClient()
# The `subscription_path` method creates a fully qualified identifier
# in the form `projects/{project_id}/subscriptions/{subscription_id}`
subscription_path = subscriber.subscription_path('aptos-bq', 'indexing-ranges-subscription-mainnet')

def callback(message: pubsub_v1.subscriber.message.Message) -> None:
    print(f"Received {message}.")

    # Use `ack_with_response()` instead of `ack()` to get a future that tracks
    # the result of the acknowledge call. When exactly-once delivery is enabled
    # on the subscription, the message is guaranteed to not be delivered again
    # if the ack future succeeds.
    ack_future = message.ack_with_response()
    try:



        # Block on result of acknowledge call.
        # When `timeout` is not set, result() will block indefinitely,
        # unless an exception is encountered first.
        ack_future.result() # timeout=timeout
        print(f"Ack for message {message.message_id} successful.")
    except sub_exceptions.AcknowledgeError as e:
        print(
            f"Ack for message {message.message_id} failed with error: {e.error_code}"
        )



streaming_pull_future = subscriber.subscribe(subscription_path, callback=callback)
print(f"Listening for messages on {subscription_path}..\n")

# Wrap subscriber in a 'with' block to automatically call close() when done.
with subscriber:
    try:
        # When `timeout` is not set, result() will block indefinitely,
        # unless an exception is encountered first.
        streaming_pull_future.result() #timeout=5
    except TimeoutError:
        streaming_pull_future.cancel()  # Trigger the shutdown.
        streaming_pull_future.result()  # Block until the shutdown is complete.
