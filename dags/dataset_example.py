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


def _normalize_dataset_uri(dataset_uri: str) -> str:
    dataset_uri = dataset_uri.strip()
    if not dataset_uri.startswith("gs://"):
        return dataset_uri

    bucket_and_path = dataset_uri.removeprefix("gs://").strip("/")
    if not bucket_and_path:
        return dataset_uri

    if "/" not in bucket_and_path:
        return f"gs://{bucket_and_path}/"

    bucket, _, path = bucket_and_path.partition("/")
    path = path.strip("/")
    return f"gs://{bucket}/{path}/"


if DATASET_EVENT_URI:
    SAP_LANDING_DATASET = Dataset(_normalize_dataset_uri(DATASET_EVENT_URI))
elif OBJECT_NAME_PREFIX:
    SAP_LANDING_DATASET = Dataset(f"gs://{LANDING_BUCKET}/{OBJECT_NAME_PREFIX}/")
else:
    SAP_LANDING_DATASET = Dataset(f"gs://{LANDING_BUCKET}/")


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


def _resolve_batch_prefix(extra: dict, source_object_name: str) -> str:
    batch_prefix = (extra.get("sap_batch_prefix") or "").strip("/")
    if batch_prefix:
        return batch_prefix
    if "/" in source_object_name:
        return source_object_name.rsplit("/", 1)[0].strip("/")
    raise ValueError("Unable to determine SAP batch prefix for this event.")


def _is_metadata_file(object_name: str) -> bool:
    return object_name.rsplit("/", 1)[-1] == ".sap.partfile.metadata"


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
        success_marker_name = extra.get("sap_success_marker_name", "_SUCCESS")

        if not source_bucket_name or not source_object_name or not source_uri:
            raise ValueError(
                "The triggering dataset event is missing bucket/object/gcs_uri in extra."
            )

        batch_prefix = _resolve_batch_prefix(extra, source_object_name)
        history_date = _resolve_history_date(extra)
        list_prefix = f"{batch_prefix}/"

        logger.info("Triggered by dataset: %s", dataset)
        logger.info(
            "Trigger payload: %s", json.dumps(extra, sort_keys=True, default=str)
        )
        logger.info("Resolved batch prefix: %s", batch_prefix)

        gcs_hook = GCSHook()

        batch_objects = gcs_hook.list(
            bucket_name=source_bucket_name,
            prefix=list_prefix,
        )
        if not batch_objects:
            logger.info(
                "No objects found under '%s' in landing bucket. Nothing to move.",
                list_prefix,
            )
            return {
                "source_dataset": str(dataset),
                "source_uri": source_uri,
                "landing_deleted": False,
                "destination_bucket": BRONZE_PARQUET_BUCKET,
                "batch_prefix": batch_prefix,
                "copied_objects": [],
                "deleted_objects": [],
                "note": "empty_batch_prefix",
            }

        parquet_objects = [
            obj for obj in batch_objects if obj.lower().endswith(".parquet")
        ]
        metadata_objects = [
            obj for obj in batch_objects if _is_metadata_file(obj)
        ]
        success_objects = [
            obj for obj in batch_objects if obj.rsplit("/", 1)[-1] == success_marker_name
        ]
        ignored_objects = [
            obj
            for obj in batch_objects
            if obj not in parquet_objects
            and obj not in metadata_objects
            and obj not in success_objects
        ]

        copied_root_uris = []
        copied_history_uris = []
        for object_name in parquet_objects + metadata_objects:
            destination_root_object = object_name
            destination_history_object = (
                f"history/ingest_date={history_date}/generation={generation}/{object_name}"
            )

            gcs_hook.copy(
                source_bucket=source_bucket_name,
                source_object=object_name,
                destination_bucket=BRONZE_PARQUET_BUCKET,
                destination_object=destination_root_object,
            )
            gcs_hook.copy(
                source_bucket=source_bucket_name,
                source_object=object_name,
                destination_bucket=BRONZE_PARQUET_BUCKET,
                destination_object=destination_history_object,
            )
            copied_root_uris.append(
                f"gs://{BRONZE_PARQUET_BUCKET}/{destination_root_object}"
            )
            copied_history_uris.append(
                f"gs://{BRONZE_PARQUET_BUCKET}/{destination_history_object}"
            )

        deleted_objects = []
        for object_name in sorted(set(batch_objects)):
            gcs_hook.delete(bucket_name=source_bucket_name, object_name=object_name)
            deleted_objects.append(f"gs://{source_bucket_name}/{object_name}")

        result = {
            "source_dataset": str(dataset),
            "source_uri": source_uri,
            "landing_deleted": True if deleted_objects else False,
            "destination_bucket": BRONZE_PARQUET_BUCKET,
            "batch_prefix": batch_prefix,
            "parquet_count": len(parquet_objects),
            "metadata_count": len(metadata_objects),
            "success_marker_count": len(success_objects),
            "ignored_count": len(ignored_objects),
            "root_copies": copied_root_uris,
            "history_copies": copied_history_uris,
            "deleted_objects": deleted_objects,
        }
        logger.info(
            "Mock Bronze move result: %s", json.dumps(result, sort_keys=True)
        )
        return result

    move_arrived_file()
