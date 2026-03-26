import base64
import binascii
import json
import logging
import os
import socket
import time
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
RETRYABLE_HTTP_STATUS_CODES = {429, 500, 502, 503, 504}


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


def _normalized_object_prefix() -> str:
    prefix = os.getenv("OBJECT_NAME_PREFIX", "").strip("/")
    return f"{prefix}/" if prefix else ""


def _success_marker_name() -> str:
    return os.getenv("SUCCESS_MARKER_NAME", "_SUCCESS")


def _retry_max_attempts() -> int:
    try:
        return max(1, int(os.getenv("COMPOSER_POST_MAX_ATTEMPTS", "4")))
    except ValueError:
        return 4


def _retry_initial_backoff_seconds() -> float:
    try:
        return max(0.1, float(os.getenv("COMPOSER_POST_BACKOFF_SECONDS", "1")))
    except ValueError:
        return 1.0


def _retry_max_backoff_seconds() -> float:
    try:
        return max(0.1, float(os.getenv("COMPOSER_POST_MAX_BACKOFF_SECONDS", "16")))
    except ValueError:
        return 16.0


def _decode_pubsub_payload(cloud_event: CloudEvent) -> dict[str, Any] | None:
    data = cloud_event.data if isinstance(cloud_event.data, dict) else {}
    message = data.get("message")
    if not isinstance(message, dict):
        LOGGER.error("Ignoring event: missing or invalid 'message' field.")
        return None

    encoded_payload = message.get("data")
    if not isinstance(encoded_payload, str):
        LOGGER.error(
            "Ignoring event: missing or invalid Pub/Sub message.data. message_id=%s",
            message.get("messageId"),
        )
        return None

    try:
        decoded_payload = base64.b64decode(encoded_payload).decode("utf-8")
        message_data = json.loads(decoded_payload)
    except (binascii.Error, UnicodeDecodeError, json.JSONDecodeError) as exc:
        LOGGER.error(
            "Ignoring event: invalid Pub/Sub payload encoding/JSON. message_id=%s error=%s",
            message.get("messageId"),
            exc,
        )
        return None

    if not isinstance(message_data, dict):
        LOGGER.error(
            "Ignoring event: decoded payload must be a JSON object. message_id=%s",
            message.get("messageId"),
        )
        return None

    return message_data


def _resolve_dataset_uri(bucket: str) -> str:
    dataset_event_uri = os.getenv("DATASET_EVENT_URI")
    if dataset_event_uri:
        return _normalize_dataset_uri(dataset_event_uri)

    prefix = _normalized_object_prefix().rstrip("/")
    return f"gs://{bucket}/" if not prefix else f"gs://{bucket}/{prefix}/"


def _table_and_phase_from_prefix(batch_prefix: str) -> tuple[str | None, str | None]:
    parts = [p for p in batch_prefix.split("/") if p]
    table_name = parts[0] if len(parts) >= 1 else None
    phase = parts[1] if len(parts) >= 2 else None
    return table_name, phase


def _relative_batch_prefix(batch_prefix: str, object_prefix: str) -> str:
    clean_batch_prefix = batch_prefix.strip("/")
    clean_object_prefix = object_prefix.strip("/")
    if not clean_object_prefix:
        return clean_batch_prefix

    if clean_batch_prefix == clean_object_prefix:
        return ""

    object_prefix_with_slash = f"{clean_object_prefix}/"
    if clean_batch_prefix.startswith(object_prefix_with_slash):
        return clean_batch_prefix.removeprefix(object_prefix_with_slash)

    LOGGER.warning(
        "Batch prefix '%s' does not start with configured object prefix '%s'.",
        clean_batch_prefix,
        clean_object_prefix,
    )
    return clean_batch_prefix


def _build_event_payload(
    message_data: dict[str, Any], batch_prefix: str, object_prefix: str
) -> dict[str, Any]:
    bucket = message_data["bucket"]
    object_name = message_data["name"]
    relative_batch_prefix = _relative_batch_prefix(batch_prefix, object_prefix)
    table_name, phase = _table_and_phase_from_prefix(relative_batch_prefix)
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
            "sap_batch_prefix": batch_prefix,
            "sap_batch_prefix_relative": relative_batch_prefix,
            "sap_metadata_uri": f"gs://{bucket}/{batch_prefix}/.sap.partfile.metadata",
            "sap_phase": phase,
            "sap_success_marker_name": _success_marker_name(),
            "sap_table_name": table_name,
            "size": message_data.get("size"),
            "storage_class": message_data.get("storageClass"),
            "time_created": message_data.get("timeCreated"),
            "updated": message_data.get("updated"),
        },
    }


def _fetch_access_token() -> str:
    request = urllib.request.Request(
        METADATA_TOKEN_URL,
        headers={"Metadata-Flavor": "Google"},
        method="GET",
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        token_payload = json.loads(response.read().decode("utf-8"))

    access_token = token_payload.get("access_token")
    if not access_token:
        raise RuntimeError("Could not retrieve access token from metadata server.")
    return access_token


def _is_retryable_http_status(status_code: int) -> bool:
    return status_code in RETRYABLE_HTTP_STATUS_CODES


def _retry_sleep_seconds(attempt: int) -> float:
    initial_backoff = _retry_initial_backoff_seconds()
    max_backoff = _retry_max_backoff_seconds()
    return min(max_backoff, initial_backoff * (2 ** (attempt - 1)))


def _post_dataset_event(payload: dict[str, Any]) -> None:
    airflow_url = os.environ["AIRFLOW_URL"].rstrip("/")
    endpoint = f"{airflow_url}/api/v1/datasets/events"
    access_token = _fetch_access_token()
    encoded_payload = json.dumps(payload).encode("utf-8")

    max_attempts = _retry_max_attempts()
    for attempt in range(1, max_attempts + 1):
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
                if response.status in (200, 201):
                    return

                response_body = response.read().decode("utf-8")
                if (
                    _is_retryable_http_status(response.status)
                    and attempt < max_attempts
                ):
                    sleep_seconds = _retry_sleep_seconds(attempt)
                    LOGGER.warning(
                        (
                            "Retrying dataset event POST after HTTP %s "
                            "(attempt %s/%s, sleep %.1fs)."
                        ),
                        response.status,
                        attempt,
                        max_attempts,
                        sleep_seconds,
                    )
                    time.sleep(sleep_seconds)
                    continue

                raise RuntimeError(
                    f"Dataset event POST failed with HTTP {response.status}: {response_body}"
                )
        except urllib.error.HTTPError as exc:
            response_body = exc.read().decode("utf-8")
            if _is_retryable_http_status(exc.code) and attempt < max_attempts:
                sleep_seconds = _retry_sleep_seconds(attempt)
                LOGGER.warning(
                    (
                        "Retrying dataset event POST after HTTP %s "
                        "(attempt %s/%s, sleep %.1fs)."
                    ),
                    exc.code,
                    attempt,
                    max_attempts,
                    sleep_seconds,
                )
                time.sleep(sleep_seconds)
                continue

            raise RuntimeError(
                f"Dataset event POST failed with HTTP {exc.code}: {response_body}"
            ) from exc
        except (urllib.error.URLError, TimeoutError, socket.timeout) as exc:
            if attempt < max_attempts:
                sleep_seconds = _retry_sleep_seconds(attempt)
                LOGGER.warning(
                    (
                        "Retrying dataset event POST after transient network error "
                        "(attempt %s/%s, sleep %.1fs): %s"
                    ),
                    attempt,
                    max_attempts,
                    sleep_seconds,
                    exc,
                )
                time.sleep(sleep_seconds)
                continue

            raise RuntimeError(
                f"Dataset event POST failed after network error: {exc}"
            ) from exc


@functions_framework.cloud_event
def trigger_dag(cloud_event: CloudEvent) -> None:
    """Receives landing-bucket events and creates an Airflow dataset event."""
    message_data = _decode_pubsub_payload(cloud_event)
    if message_data is None:
        return

    object_name = message_data.get("name")
    bucket = message_data.get("bucket")
    success_marker_name = _success_marker_name()

    if not isinstance(bucket, str) or not isinstance(object_name, str):
        raise ValueError("Pub/Sub payload must contain string 'bucket' and 'name'.")

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

    object_basename = object_name.rsplit("/", 1)[-1]
    if object_basename != success_marker_name:
        LOGGER.info(
            "Ignoring object '%s' because only '%s' triggers dataset events.",
            object_name,
            success_marker_name,
        )
        return

    if "/" not in object_name:
        LOGGER.warning(
            "Ignoring success marker '%s' because it has no batch prefix.",
            object_name,
        )
        return

    batch_prefix = object_name.rsplit("/", 1)[0].strip("/")
    payload = _build_event_payload(message_data, batch_prefix, object_prefix)

    LOGGER.info(
        (
            "Publishing dataset event for '%s' (batch_prefix='%s', "
            "relative_batch_prefix='%s') with dataset uri '%s'."
        ),
        payload["extra"]["gcs_uri"],
        payload["extra"]["sap_batch_prefix"],
        payload["extra"]["sap_batch_prefix_relative"],
        payload["dataset_uri"],
    )
    _post_dataset_event(payload)
    LOGGER.info(
        "Dataset event created successfully for '%s'.", payload["extra"]["gcs_uri"]
    )
