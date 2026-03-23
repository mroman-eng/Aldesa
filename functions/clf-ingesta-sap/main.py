import base64
import json
import logging
import os
import urllib.error
import urllib.request
from typing import Any

import functions_framework
from cloudevents.http import CloudEvent

LOGGER = logging.getLogger(__name__)
METADATA_TOKEN_URL = (
    "http://metadata.google.internal/computeMetadata/v1/"
    "instance/service-accounts/default/token"
)


def _normalize_dataset_uri(dataset_uri: str) -> str:
    if not dataset_uri.startswith("gs://"):
        return dataset_uri

    bucket_and_path = dataset_uri.removeprefix("gs://")
    if "/" not in bucket_and_path.rstrip("/"):
        return dataset_uri.rstrip("/") + "/"
    return dataset_uri

def _normalized_object_prefix() -> str:
    prefix = os.getenv("OBJECT_NAME_PREFIX", "").strip("/")
    return f"{prefix}/" if prefix else ""


def _decode_pubsub_payload(cloud_event: CloudEvent) -> dict[str, Any]:
    encoded_payload = cloud_event.data["message"]["data"]
    return json.loads(base64.b64decode(encoded_payload).decode("utf-8"))


def _resolve_dataset_uri(bucket: str) -> str:
    dataset_event_uri = os.getenv("DATASET_EVENT_URI")
    if dataset_event_uri:
        return _normalize_dataset_uri(dataset_event_uri)

    prefix = _normalized_object_prefix().rstrip("/")
    return f"gs://{bucket}/" if not prefix else f"gs://{bucket}/{prefix}"


def _build_event_payload(message_data: dict[str, Any]) -> dict[str, Any]:
    bucket = message_data["bucket"]
    object_name = message_data["name"]
    dataset_uri = _resolve_dataset_uri(bucket)

    return {
        "dataset_uri": dataset_uri,
        "extra": {
            "bucket": bucket,
            "content_type": message_data.get("contentType"),
            "crc32c": message_data.get("crc32c"),
            "etag": message_data.get("etag"),
            "gcs_uri": f"gs://{bucket}/{object_name}",
            "generation": message_data.get("generation"),
            "md5_hash": message_data.get("md5Hash"),
            "metageneration": message_data.get("metageneration"),
            "object": object_name,
            "size": message_data.get("size"),
            "storage_class": message_data.get("storageClass"),
            "time_created": message_data.get("timeCreated"),
            "updated": message_data.get("updated"),
        },
    }


def _post_dataset_event(payload: dict[str, Any]) -> None:
    airflow_url = os.environ["AIRFLOW_URL"].rstrip("/")
    endpoint = f"{airflow_url}/api/v1/datasets/events"
    request = urllib.request.Request(
        METADATA_TOKEN_URL,
        headers={"Metadata-Flavor": "Google"},
        method="GET",
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        token_payload = json.loads(response.read().decode("utf-8"))

    access_token = token_payload["access_token"]
    encoded_payload = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        endpoint,
        data=encoded_payload,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            if response.status not in (200, 201):
                raise RuntimeError(
                    f"Dataset event POST failed with HTTP {response.status}: "
                    f"{response.read().decode('utf-8')}"
                )
    except urllib.error.HTTPError as exc:
        raise RuntimeError(
            f"Dataset event POST failed with HTTP {exc.code}: "
            f"{exc.read().decode('utf-8')}"
        ) from exc


@functions_framework.cloud_event
def trigger_dag(cloud_event: CloudEvent) -> None:
    """Receives landing-bucket events and creates an Airflow dataset event."""
    message_data = _decode_pubsub_payload(cloud_event)
    object_name = message_data.get("name", "")
    bucket = message_data.get("bucket", "")

    if not bucket or not object_name:
        raise ValueError("Pub/Sub payload must contain 'bucket' and 'name'.")

    if object_name.endswith("/"):
        LOGGER.info("Ignoring folder marker '%s'.", object_name)
        return

    object_prefix = _normalized_object_prefix()
    if object_prefix and not object_name.startswith(object_prefix):
        LOGGER.info(
            "Ignoring object '%s' because it does not match prefix '%s'.",
            object_name,
            object_prefix,
        )
        return

    payload = _build_event_payload(message_data)

    LOGGER.info(
        "Publishing dataset event for '%s' with dataset uri '%s'.",
        payload["extra"]["gcs_uri"],
        payload["dataset_uri"],
    )
    _post_dataset_event(payload)
    LOGGER.info(
        "Dataset event created successfully for '%s'.", payload["extra"]["gcs_uri"]
    )
