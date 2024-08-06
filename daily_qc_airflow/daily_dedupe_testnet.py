"""dag_hourly_aptos_etl

Extract hourly block data by running Aptos ETL
"""

from airflow.models import Variable
TEMP_PROJECT = "aptos-bq" #Variable.get("aptos_output_project")
FINAL_PROJECT = f"aptos-data-pdp"
NETWORK_TYPE = "testnet" # TODO: environment variable?
FINAL_DATASET = f"crypto_aptos_{NETWORK_TYPE}_us"

import json
from datetime import datetime, timedelta
from airflow.models import DAG
from airflow.utils.task_group import TaskGroup
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from airflow.operators.empty import EmptyOperator
from airflow.providers.google.cloud.operators.bigquery import (
    BigQueryCreateEmptyDatasetOperator, BigQueryCreateEmptyTableOperator
)
from airflow.providers.google.cloud.transfers.gcs_to_local import GCSToLocalFilesystemOperator
from airflow.providers.google.cloud.operators.bigquery import BigQueryExecuteQueryOperator

#from google_chat_callbacks import task_fail_alert, task_success_alert

TODATE = "{{ (logical_date + macros.timedelta(days=1)).strftime('%Y-%m-%d') }}"
YESTERDATE = "{{ logical_date.strftime('%Y-%m-%d') }}"

tables = ["transactions", "blocks", "changes", "modules", "table_items", "events", "resources", "signatures"]


# the fields for each table that determines if two records are unique or duplicates
# NOTE: for 4/8 tables, it's just `tx_version` and `change_index`
SQL_MERGE_TABLE = {
    "transactions": "tx_version",
    "blocks": "block_height",
    "changes": "change_index, tx_version",
    "events": "event_index, tx_version",
    "modules": "change_index, tx_version",
    "table_items": "change_index, tx_version",
    "resources": "change_index, tx_version",
    "signatures": "tx_version, signature.value, public_key.value, public_key.index, signer, is_sender, is_fee_payer",
}


default_args = {
    "depends_on_past": False,
    "start_date": datetime(2024, 4, 19),
    "provide_context": True,
    "retries": 3,
    "retry_delay": timedelta(minutes=1),
    #"on_success_callback": task_success_alert,
    #"on_failure_callback": task_fail_alert,
}


# runs 1 hour after midnight, every day
with DAG(
    dag_id="testnet_daily_dedupe",
    schedule_interval="0 1 * * *",
    default_args=default_args,
    catchup=True,
) as dag:

    start_task = EmptyOperator(task_id="start_task")

    with TaskGroup("bq_dedupe_task") as bq_dedupe_task:
        for table_name in tables:
            with TaskGroup(f"gcs_to_bq_{table_name}") as gcs_to_bq_tasks:
                # Add Data to BigQuery Public Dataset
                dedupe_sql = f"""
MERGE INTO `{FINAL_PROJECT}.{FINAL_DATASET}.{table_name}` AS INTERNAL_DEST
USING (
SELECT k.*
FROM (
SELECT ARRAY_AGG(original_data LIMIT 1)[OFFSET(0)] k
FROM `{FINAL_PROJECT}.{FINAL_DATASET}.{table_name}` AS original_data
WHERE block_timestamp BETWEEN TIMESTAMP('{YESTERDATE}') AND TIMESTAMP('{TODATE}')
GROUP BY {SQL_MERGE_TABLE[table_name]}
)
) AS INTERNAL_SOURCE
ON FALSE
WHEN NOT MATCHED BY SOURCE
AND INTERNAL_DEST.block_timestamp BETWEEN TIMESTAMP('{YESTERDATE}') AND TIMESTAMP('{TODATE}')
THEN DELETE
WHEN NOT MATCHED THEN INSERT ROW;
                """

                bq_dedupe_task_inner = BigQueryExecuteQueryOperator(
                    task_id=f"{table_name}_dedupe_bq_task",
                    #destination_dataset_table=f"{FINAL_PROJECT}.{FINAL_DATASET}.{table_name}",
                    sql=dedupe_sql,
                    use_legacy_sql=False,
                    create_disposition="CREATE_NEVER",
                    #write_disposition="WRITE_DISPOSITION_UNSPECIFIED",
                    #fields=["friendlyName", "description"],
                    #schema_object_bucket="aptos_schemas",
                    #schema_object=f"{table_name}.json",
                )

            bq_dedupe_task_inner


    end_task = EmptyOperator(task_id="end_task")

    (
        start_task
        >> bq_dedupe_task
        >> end_task
    )
