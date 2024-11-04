
from airflow import DAG
from airflow.operators.python_operator import PythonOperator
from airflow.providers.google.cloud.hooks.bigquery import BigQueryHook
from airflow.providers.google.cloud.hooks.pubsub import PubSubHook
from datetime import timedelta, datetime
from airflow.operators.empty import EmptyOperator
from airflow.decorators import dag, task
from airflow.models import Variable

from pubsub_range_pb2 import IndexingRange
from google_chat_callbacks import task_fail_alert

TEMP_PROJECT = Variable.get("aptos_internal_project")
FINAL_PROJECT = Variable.get("aptos_output_project")
NETWORK_TYPE = "mainnet" # TODO: environment variable?
FINAL_DATASET = f"crypto_aptos_{NETWORK_TYPE}_us"
INDEXING_RANGES_TOPIC_NAME = f"transaction-indexing-ranges-{NETWORK_TYPE}"

TODATE = "{{ (logical_date + macros.timedelta(days=1)).strftime('%Y-%m-%d') }}"
YESTERDATE = "{{ logical_date.strftime('%Y-%m-%d') }}"

# runs 30 minutes after midnight:
# 1. want to ensure that streaming has finished
# 2. don't need to wait 90 minutes for the streaming buffer to finish

with DAG(
    'backfill_missing_transactions_mainnet_prod',
    default_args={
        'owner': 'airflow',
        'depends_on_past': False,
        'start_date': datetime(2024, 5, 1),
        "on_failure_callback": task_fail_alert,
        'email_on_failure': False,
        'email_on_retry': False,
        'retries': 1,
        'retry_delay': timedelta(minutes=1),
    },
    description='Daily backfill QC (mainnet)',
    schedule_interval="30 0 * * *",
    max_active_runs=1,
    catchup=True,
) as dag:
    start_task = EmptyOperator(task_id="start_task")

    def bigquery_all_versions_f(yesterdate, todate):
        sql = f"""
        SELECT tx_version
        FROM `{FINAL_PROJECT}.{FINAL_DATASET}.transactions`
        WHERE block_timestamp BETWEEN TIMESTAMP('{yesterdate}') AND TIMESTAMP('{todate}') ORDER BY tx_version
        """
        hook = BigQueryHook(use_legacy_sql=False)
        result = hook.get_pandas_df(sql=sql)
        result_as_list = result['tx_version'].tolist()
        return result_as_list

    bigquery_all_versions = PythonOperator(
        task_id="bigquery_all_versions",
        python_callable=bigquery_all_versions_f,
        op_args=['{{ logical_date.strftime("%Y-%m-%d") }}', '{{ (logical_date + macros.timedelta(days=1)).strftime("%Y-%m-%d") }}'],
        do_xcom_push=True,
        provide_context=True,
        dag=dag,
    )

    # use the bigquery query results from the previous task to create a python list of all integers from min to max (inclusive)
    def generate_array(**context):
        all_versions = context['task_instance'].xcom_pull(task_ids='bigquery_all_versions')
        min_version = all_versions[0]
        max_version = all_versions[-1]

        return list(range(min_version, max_version + 1))

    # Task 2: Generate array of all integers from the daily [min, max]
    generate_integers_array = PythonOperator(
        task_id='generate_integers_array',
        python_callable=generate_array,
        provide_context=True,
        do_xcom_push=True,
        dag=dag,
    )

    def check_missing_values_f(**context):
        all_versions = context['task_instance'].xcom_pull(task_ids='bigquery_all_versions')
        all_versions_set = set(all_versions)

        all_integers = context['task_instance'].xcom_pull(task_ids='generate_integers_array')
        missing_versions = [n for n in all_integers if n not in all_versions_set]
        missing_versions.sort()
        return missing_versions

    check_missing_values = PythonOperator(
        task_id="check_missing_values",
        python_callable=check_missing_values_f,
        provide_context=True,
        do_xcom_push=True,
        dag=dag,
    )

    # create an IndexingRange protobuf object from the missing values calculated in previous task, then serialize it and publish to pub/sub
    def publish_range_f(**context):
        missing_values = context['task_instance'].xcom_pull(task_ids='check_missing_values')
        # this is allowed to fail due to no missing values
        try:
            ranges = []
            if len(missing_values) > 1:
                # for multiple possible ranges
                cur_start = missing_values[0]
                cur_end = missing_values[0]
                for n in missing_values[1:]:
                    if n > cur_end + 1:
                        ranges.append((cur_start, cur_end))
                        cur_start = n
                    cur_end = n
                else:
                    ranges.append((cur_start, cur_end))
            elif len(missing_values) == 1:
                # for single case
                ranges.append((missing_values[0], missing_values[0]))

            for (start, end) in ranges:
                # start, end = min(missing_values), max(missing_values)
                indexing_range_proto_obj = IndexingRange(start=start, end=end) # fun fact: positional arguments don't work with protobuf initializers
                assert(indexing_range_proto_obj is not None)
                indexing_range_serialized = indexing_range_proto_obj.SerializeToString()
                hook = PubSubHook(use_legacy_sql=False)
                result = hook.publish(project_id=TEMP_PROJECT, topic=INDEXING_RANGES_TOPIC_NAME, messages=[{"data": indexing_range_serialized}])
        finally:
            return

    # use the min and max values to publish a backfilling range
    publish_range = PythonOperator(
        task_id='publish_range',
        python_callable=publish_range_f,
        provide_context=True,
        do_xcom_push=True,
        dag=dag,
    )

    end_task = EmptyOperator(task_id="end_task")

# Set task dependencies
(
    start_task >> bigquery_all_versions >> generate_integers_array >> check_missing_values >> publish_range >> end_task
)
