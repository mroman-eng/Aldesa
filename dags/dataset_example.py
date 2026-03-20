"""
Create Dataset Event
curl -X POST "https://<AIRFLOW_HOST>/api/v1/datasets/events" \
  -H "Content-Type: application/json" \
  -u "user:password" \
  -d '{
        "uri": "s3://dataset-bucket/example.csv",
        "extra": {
          "rows": 120345,
          "window_start": "2026-03-01T00:00:00Z",
          "window_end":   "2026-03-01T23:59:59Z"
        },
        "source": "external-system"
      }'
"""
from datetime import datetime

from airflow import DAG
from airflow.datasets import Dataset
from airflow.operators.empty import EmptyOperator

example_dataset = Dataset("s3://dataset-bucket/example.csv")

# Este DAG se ejecutará automáticamente cuando 'example_dataset' sea actualizado por otro DAG
with DAG(
    dag_id="dataset_consumer_example",
    schedule=[example_dataset],
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["example", "dataset"],
) as dag:

    # Tarea de ejemplo que se ejecuta al consumir el dataset
    consume_task = EmptyOperator(
        task_id="consume_task"
    )
