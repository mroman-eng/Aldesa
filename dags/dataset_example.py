import json
import logging
import os
from datetime import datetime, timezone

from airflow import DAG
from airflow.decorators import task
from airflow.datasets import Dataset
from airflow.providers.google.cloud.hooks.gcs import GCSHook

LANDING_BUCKET = os.environ.get("LANDING_BUCKET", "missing-landing-bucket")
BRONZE_PARQUET_BUCKET = os.environ.get(
    "BRONZE_PARQUET_BUCKET", "missing-bronze-parquet-bucket"
)
OBJECT_NAME_PREFIX = os.environ.get("OBJECT_NAME_PREFIX", "").strip("/")
DATASET_EVENT_URI = os.environ.get("DATASET_EVENT_URI")

if DATASET_EVENT_URI:
    SAP_LANDING_DATASET = Dataset(DATASET_EVENT_URI)
elif OBJECT_NAME_PREFIX:
    SAP_LANDING_DATASET = Dataset(f"gs://{LANDING_BUCKET}/{OBJECT_NAME_PREFIX}")
else:
    SAP_LANDING_DATASET = Dataset(f"gs://{LANDING_BUCKET}")


def _extract_latest_trigger(triggering_dataset_events):
    for dataset, events in triggering_dataset_events.items():
        if events:
            return dataset, events[-1]
    raise ValueError("No triggering dataset events were found.")


def _resolve_history_date(extra: dict) -> str:
    raw_time = extra.get("time_created") or extra.get("updated")
    if raw_time:
        try:
            return (
                datetime.fromisoformat(raw_time.replace("Z", "+00:00"))
                .astimezone(timezone.utc)
                .strftime("%Y-%m-%d")
            )
        except ValueError:
            pass
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


with DAG(
    dag_id="dataset_consumer_example",
    schedule=[SAP_LANDING_DATASET],
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["example", "dataset", "mock"],
) as dag:

    @task(queue="kubernetes")
    def move_arrived_file(triggering_dataset_events=None):
        logger = logging.getLogger("airflow.task")

        if not triggering_dataset_events:
            raise ValueError("No triggering dataset events were received.")

        dataset, event = _extract_latest_trigger(triggering_dataset_events)
        extra = event.extra or {}
        source_bucket_name = extra.get("bucket")
        source_object_name = extra.get("object")
        source_uri = extra.get("gcs_uri")
        generation = extra.get("generation") or "no-generation"

        if not source_bucket_name or not source_object_name or not source_uri:
            raise ValueError(
                "The triggering dataset event is missing bucket/object/gcs_uri in extra."
            )

        history_date = _resolve_history_date(extra)
        destination_root_object = source_object_name.rsplit("/", 1)[-1]
        destination_history_object = (
            f"history/ingest_date={history_date}/{generation}_{destination_root_object}"
        )

        logger.info("Triggered by dataset: %s", dataset)
        logger.info(
            "Trigger payload: %s", json.dumps(extra, sort_keys=True, default=str)
        )

        gcs_hook = GCSHook()

        if not gcs_hook.exists(
            bucket_name=source_bucket_name, object_name=source_object_name
        ):
            raise FileNotFoundError(f"Source object does not exist: {source_uri}")

        gcs_hook.copy(
            source_bucket=source_bucket_name,
            source_object=source_object_name,
            destination_bucket=BRONZE_PARQUET_BUCKET,
            destination_object=destination_root_object,
        )
        gcs_hook.copy(
            source_bucket=source_bucket_name,
            source_object=source_object_name,
            destination_bucket=BRONZE_PARQUET_BUCKET,
            destination_object=destination_history_object,
        )
        gcs_hook.delete(
            bucket_name=source_bucket_name,
            object_name=source_object_name,
        )

        result = {
            "source_dataset": str(dataset),
            "source_uri": source_uri,
            "landing_deleted": True,
            "destination_bucket": BRONZE_PARQUET_BUCKET,
            "root_copy": f"gs://{BRONZE_PARQUET_BUCKET}/{destination_root_object}",
            "history_copy": f"gs://{BRONZE_PARQUET_BUCKET}/{destination_history_object}",
        }
        logger.info(
            "Mock Bronze move result: %s", json.dumps(result, sort_keys=True)
        )
        return result

    move_arrived_file()
