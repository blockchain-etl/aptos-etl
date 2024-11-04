from airflow.models import Variable
OUTPUT_PROJECT = Variable.get("aptos_output_project")
PUBLIC_PROJECT = Variable.get("aptos_public_project")
NETWORK_TYPE = "testnet"
TEMP_DATASET = f"{NETWORK_TYPE}_temp"
FINAL_DATASET = f"crypto_aptos_{NETWORK_TYPE}_us"

import json
from datetime import datetime, timedelta
from airflow.models import DAG
from airflow.utils.task_group import TaskGroup
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from airflow.operators.empty import EmptyOperator
from airflow.providers.google.cloud.operators.bigquery import (
    BigQueryCreateEmptyDatasetOperator, BigQueryCreateEmptyTableOperator, BigQueryUpdateTableSchemaOperator
)
from airflow.providers.google.cloud.transfers.gcs_to_bigquery import (
    GCSToBigQueryOperator,
)
from airflow.providers.google.cloud.transfers.gcs_to_local import GCSToLocalFilesystemOperator
from airflow.providers.google.cloud.operators.bigquery import BigQueryInsertJobOperator

#from google_chat_callbacks import task_fail_alert, task_success_alert

import logging


tables = ["transactions", "blocks", "changes", "events", "modules", "table_items", "resources", "signatures"]

import os
CUR_DIR = os.path.abspath(os.path.dirname(__file__))

# Open the JSON file and load its contents into a list of dicts
def read_in_schemas(table_name: str):
    #schemas_dir = "schemas"
    file_path = f"{CUR_DIR}/schemas/{table_name}.json"
    with open(file_path, 'r') as file:
        data = json.load(file)
        return data

TABLE_SCHEMAS = {table_name:read_in_schemas(table_name) for table_name in tables}

# maps a table name to its bucket
def map_table_to_bucket(table_name: str):
    return f"aptos_{NETWORK_TYPE}_{table_name}"

TABLE_BUCKETS = {table_name:map_table_to_bucket(table_name) for table_name in tables}


BLOCK_DATE = "{{ logical_date.strftime('%Y-%m-%d') }}"
BLOCK_HOUR = "{{ '{:d}'.format(logical_date.hour) }}"



default_args = {
    "depends_on_past": False,
    "start_date": datetime(2022, 9, 9),
    "provide_context": True,
    "retries": 2,
    "retry_delay": timedelta(minutes=1),
    #"on_success_callback": task_success_alert,
    #"on_failure_callback": task_fail_alert,
}


with DAG(
    dag_id="dag_hourly_aptos_etl_mainnet_4",
    schedule_interval="@hourly",
    default_args=default_args,
    catchup=True,
) as dag:

    start_task = EmptyOperator(task_id="start_task")

    with TaskGroup("gcs_to_bq_load_task") as gcs_to_bq_load_task:
        for table_name, table_schema in TABLE_SCHEMAS.items():
            bucket_name = TABLE_BUCKETS[table_name]

            with TaskGroup(f"gcs_to_bq_{table_name}") as gcs_to_bq_tasks:
                expiration_time = int((datetime.utcnow() + timedelta(hours=24)).timestamp()) * 1000

                # Create Temp Table
                '''
                create_temp_bq = BigQueryCreateEmptyTableOperator(
                    task_id=f"{table_name}_create_temp_bq_task",
                    dataset_id=f"{TEMP_DATASET}",
                    project_id=f"{OUTPUT_PROJECT}",
                    table_id=f"{table_name}",
                    table_resource={"expirationTime":expiration_time, "schema": {"fields": table_schema}},
                    # time_partitioning={"field": "block_timestamp", "type": "DAY"},
                    gcs_schema_object=f"gs://aptos_schemas/{table_name}.json",
                    if_exists="skip"
                )
                '''

                # Remove Pre-existing Data in Destination Table
                remove_sql = f"""
                BEGIN
                    IF EXISTS (SELECT 1 FROM {OUTPUT_PROJECT}.{TEMP_DATASET}.INFORMATION_SCHEMA.TABLES
                    WHERE table_name='{table_name}')
                    THEN
                       DELETE
                       FROM `{OUTPUT_PROJECT}.{TEMP_DATASET}.{table_name}`
                       WHERE DATE(block_timestamp)='{BLOCK_DATE}' AND EXTRACT(HOUR FROM block_timestamp) = {BLOCK_HOUR};
                    END IF;
                END;
                """
                bq_remove_existing_data_task = BigQueryInsertJobOperator(
                    task_id=f"{table_name}_bq_remove_existing_data_task",
                     configuration={
                        "query": {
                            "query": remove_sql,
                            "useLegacySql": False
                        },
                        "writeDisposition":  "WRITE_APPEND"
                     }
                )

                # Load Data from GCS to BQ Destination Table
                gcs_bucket_to_temp_bq_task = GCSToBigQueryOperator(
                    task_id=f"{table_name}_gcs_bucket_to_bq_task",
                    bucket=bucket_name,
                    source_objects=[
                        f"{BLOCK_DATE}/{BLOCK_HOUR}/0/*.jsonl",
                        f"{BLOCK_DATE}/{BLOCK_HOUR}/30/*.jsonl"
                    ],
                    destination_project_dataset_table=f"{OUTPUT_PROJECT}.{TEMP_DATASET}.{table_name}",
                    write_disposition="WRITE_APPEND",
                    create_disposition="CREATE_IF_NEEDED",
                    source_format="NEWLINE_DELIMITED_JSON",
                    compression="GZIP",
                    schema_update_options=["ALLOW_FIELD_ADDITION"],
                    #time_partitioning={"field": "block_timestamp", "type": "DAY"},
                    #cluster_fields=["block_timestamp"],
                    allow_quoted_newlines=True,
                    ignore_unknown_values=True,
                    schema_fields=table_schema,
                )

                # Add Data to BigQuery Public Dataset
                add_sql = f"""
                           BEGIN
                               IF EXISTS (SELECT 1 FROM {PUBLIC_PROJECT}.{FINAL_DATASET}.{table_name}
                               WHERE DATE(block_timestamp)='{BLOCK_DATE}' AND EXTRACT(HOUR FROM block_timestamp) = {BLOCK_HOUR})
                               THEN
                                  DELETE
                                  FROM {OUTPUT_PROJECT}.{TEMP_DATASET}.{table_name}
                                  WHERE DATE(block_timestamp)='{BLOCK_DATE}' AND EXTRACT(HOUR FROM block_timestamp) = {BLOCK_HOUR};
                               END IF;
                           END;
                           INSERT INTO {PUBLIC_PROJECT}.{FINAL_DATASET}.{table_name}
                           SELECT * FROM `{OUTPUT_PROJECT}.{TEMP_DATASET}.{table_name}`
                           WHERE DATE(block_timestamp)='{BLOCK_DATE}' AND EXTRACT(HOUR FROM block_timestamp) = {BLOCK_HOUR};
                           """

                bq_copy_data_task = BigQueryInsertJobOperator(
                    task_id=f"{table_name}_bq_copy_data_task",
                    configuration={
                        "query": {
                            "query": add_sql,
                            "useLegacySql": False
                        },
                        "writeDisposition":  "WRITE_APPEND"
                    }
                )

            bq_remove_existing_data_task >> gcs_bucket_to_temp_bq_task >> bq_copy_data_task


    end_task = EmptyOperator(task_id="end_task")

    (
        start_task
        >> gcs_to_bq_load_task
        >> end_task
    )
