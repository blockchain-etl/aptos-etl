from airflow import DAG
from airflow.utils.task_group import TaskGroup
from airflow.exceptions import AirflowException
from airflow.operators.python_operator import PythonOperator
from airflow.providers.google.cloud.hooks.bigquery import BigQueryHook
from datetime import datetime
from airflow.operators.empty import EmptyOperator
import logging
from google_chat_callbacks import task_fail_alert

FINAL_PROJECT = "aptos_output_project"
NETWORK_TYPE = "mainnet"
FINAL_DATASET = f"crypto_aptos_{NETWORK_TYPE}_us"

# contains the fields in the transactions table used to determine expected row counts in the associated table.
TRANSACTION_COUNTS_TABLE = {
    "blocks": "block_height",
    "changes": "num_changes.total",
    "events": "num_events",
    "modules": ["num_changes.write_module", "num_changes.delete_module"],
    "table_items": ["num_changes.write_table_item", "num_changes.delete_table_item"],
    "resources": ["num_changes.write_resource", "num_changes.delete_resource"],
    "signatures": "num_signatures",
}

with DAG(
    'check_row_counts_72hrs',
    default_args={
        'owner': 'airflow',
        'depends_on_past': False,
        'start_date': datetime(2024, 9, 15),
        'on_failure_callback': task_fail_alert,
        'email_on_failure': False,
        'email_on_retry': False,
        'retries': 0,
    },
    description='72hr row counts QC (mainnet)',
    schedule_interval="0 3 * * *",
    max_active_runs=1,
    catchup=False,
) as dag:
    start_task = EmptyOperator(task_id="start_task")

    def prepare_sum_fields(table_count_fields):
        """
        Prepare the sum fields for the SQL query based on the input type
        """
        if isinstance(table_count_fields, list):
            # prepend the table reference to the field name, then add '+' between fields to create a SQL sum
            sum_fields_in_transactions_table = ["t." + field for field in table_count_fields]
            return " + ".join(sum_fields_in_transactions_table)
        elif isinstance(table_count_fields, str):
            return f"t.{table_count_fields}"
        else:
            raise AirflowException("Deduplication field was an unexpected type: not a list or string")

    with TaskGroup("bigquery_row_count_mismatches_all") as bigquery_row_count_mismatches_all:
        for table_name, table_count_fields in TRANSACTION_COUNTS_TABLE.items():
            # Prepare the sum fields for this specific table
            sum_fields_prepared = None
            if table_name == "blocks":
                sum_fields_prepared = table_count_fields
            else:
                sum_fields_prepared = prepare_sum_fields(table_count_fields)

            def bigquery_row_count_mismatches_factory(table_name, sum_fields):
                def _bigquery_row_count_mismatches(yesterdate, todate):

                    sql = None
                    # blocks is a special case, it compares the unique block_height values in blocks table and transactions table.
                    #   - a mismatch is considered a block_height value that is present in one table but not the other
                    if table_name == "blocks":
                        sql = f"""
                        SELECT
                          t.{sum_fields} AS transaction_block_height,
                          b.{sum_fields} AS block_block_height
                        FROM
                          `{FINAL_PROJECT}.{FINAL_DATASET}.transactions` t
                          LEFT JOIN `{FINAL_PROJECT}.{FINAL_DATASET}.{table_name}` b
                            ON t.{sum_fields} = b.{sum_fields}
                        WHERE
                          t.block_timestamp BETWEEN TIMESTAMP('{yesterdate}') AND TIMESTAMP('{todate}')
                          AND b.block_timestamp BETWEEN TIMESTAMP('{yesterdate}') AND TIMESTAMP('{todate}') AND
                           (t.{sum_fields} IS NULL OR b.{sum_fields} IS NULL)
                        """
                    else:
                        sql = f"""
                        SELECT
                        t.tx_version,
                        {sum_fields} as sum_esc,
                        COUNT(c.tx_version) AS record_count
                        FROM
                        `{FINAL_PROJECT}.{FINAL_DATASET}.transactions` t
                        LEFT JOIN
                        `{FINAL_PROJECT}.{FINAL_DATASET}.{table_name}` c ON t.tx_version = c.tx_version
                        WHERE
                        t.block_timestamp BETWEEN TIMESTAMP('{yesterdate}') AND TIMESTAMP('{todate}')
                        AND
                        c.block_timestamp BETWEEN TIMESTAMP('{yesterdate}') AND TIMESTAMP('{todate}')
                        GROUP BY
                        t.tx_version, sum_esc
                        HAVING
                        sum_esc != record_count
                        """
                    logging.getLogger(__name__).info(f"Running query for table {table_name}: {sql}")
                    hook = BigQueryHook(use_legacy_sql=False)
                    result = hook.get_pandas_df(sql=sql)
                    logging.getLogger(__name__).info(f"Got query result for {table_name}: {result}")

                    result_as_list = None
                    if table_name == "blocks":
                        missing_from_blocks_table = result['transaction_block_height'].tolist() if not result.empty else []
                        missing_from_transactions_table = result['block_block_height'].tolist() if not result.empty else []
                        result_as_list = missing_from_blocks_table + missing_from_transactions_table
                    else:
                        result_as_list = result['tx_version'].tolist() if not result.empty else []

                    logging.getLogger(__name__).info(f"Transformed result to python list for {table_name}: {result_as_list}")
                    return result_as_list

                return _bigquery_row_count_mismatches

            # Create a task for each table
            bigquery_row_count_mismatches = PythonOperator(
                task_id=f"bigquery_row_count_mismatches_{table_name}",
                python_callable=bigquery_row_count_mismatches_factory(table_name, sum_fields_prepared),
                op_args=['{{ (logical_date - macros.timedelta(days=2)).strftime("%Y-%m-%d") }}', '{{ (logical_date + macros.timedelta(days=1)).strftime("%Y-%m-%d") }}'],
                do_xcom_push=True,
                provide_context=True,
                dag=dag,
            )

    with TaskGroup("check_mismatches_length_all") as check_mismatches_length_all:
        for table_name in TRANSACTION_COUNTS_TABLE:
            def check_mismatches_length_factory(table_name):
                def _check_mismatches_length(**context):
                    mismatches = context['task_instance'].xcom_pull(
                        task_ids=f'bigquery_row_count_mismatches_all.bigquery_row_count_mismatches_{table_name}'
                    )
                    if len(mismatches) != 0:
                        raise AirflowException(f"Row count mismatch found for table {table_name}")
                    else:
                        return

                return _check_mismatches_length

            check_mismatches_length = PythonOperator(
                task_id=f"check_mismatches_length_{table_name}",
                python_callable=check_mismatches_length_factory(table_name),
                provide_context=True,
                do_xcom_push=True,
                dag=dag,
            )

    end_task = EmptyOperator(task_id="end_task")

    # Set task dependencies
    (
        start_task >> bigquery_row_count_mismatches_all >> check_mismatches_length_all >> end_task
    )
