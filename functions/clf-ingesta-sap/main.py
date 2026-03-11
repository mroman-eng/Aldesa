import base64
import json
import requests
import logging
import os
import google.auth
import google.auth.transport.requests
import functions_framework
from cloudevents.http import CloudEvent

# URL base de tu entorno Airflow en Composer
AIRFLOW_URL = os.getenv(
    "AIRFLOW_URL",
    "https://8c08dbb4083f4edebae17031160ad4dc-dot-europe-southwest1.composer.googleusercontent.com",
)

# Mapeo de prefijos GCS a DAGs de Airflow
DAG_MAPPING = {
    "raw/sap/proj/to_be_processed/": "dag_raw_proj",
    "raw/sap/prps/to_be_processed/": "dag_raw_prps",
    # "raw/sap/OTRA/a_procesar/": "dag_sap_otra_raw",
}

# Subcarpetas que deben ignorarse silenciosamente sin log de warning
IGNORED_PREFIXES = [
    "raw/sap/proj/processed/",
    "raw/sap/proj/unprocessed/",
    "raw/sap/prps/processed/",
    "raw/sap/prps/unprocessed/",
    # Añade aquí las subcarpetas de futuras entidades SAP
]

def trigger_airflow_dag(dag_id: str, file_path: str) -> None:
    """Llama a la API de Airflow para triggerear un DAG."""
    logger = logging.getLogger(__name__)

    logger.info(f"🔐 Obteniendo credenciales para llamar a Airflow...")
    credentials, project = google.auth.default(
        scopes=["https://www.googleapis.com/auth/cloud-platform"]
    )
    auth_req = google.auth.transport.requests.Request()
    credentials.refresh(auth_req)
    token = credentials.token
    logger.info(f"✅ Credenciales obtenidas correctamente")

    url = f"{AIRFLOW_URL}/api/v1/dags/{dag_id}/dagRuns"
    logger.info(f"📡 Llamando a la API de Airflow: {url}")

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    payload = {
        "conf": {
            "source_file": file_path.split("/")[-1],
        }
    }

    response = requests.post(url, headers=headers, json=payload)
    logger.info(f"📨 Respuesta de Airflow: HTTP {response.status_code}")

    if response.status_code in [200, 201]:
        logger.info(f"✅ DAG '{dag_id}' triggerado correctamente")
        logger.info(f"   Fichero: {file_path.split('/')[-1]}")
    else:
        logger.error(f"❌ Error al triggerear DAG '{dag_id}'")
        logger.error(f"   HTTP {response.status_code}: {response.text}")
        raise Exception(f"Error triggereando DAG {dag_id}: {response.status_code} - {response.text}")


@functions_framework.cloud_event
def trigger_dag(cloud_event: CloudEvent) -> None:
    """
    Cloud Function 2ª gen que recibe notificaciones de GCS via Pub/Sub
    y triggerea el DAG de Airflow correspondiente.
    """
    logger = logging.getLogger(__name__)

    # ── Decodificar mensaje de Pub/Sub ───────────────────────────────────
    pubsub_message = base64.b64decode(cloud_event.data["message"]["data"]).decode("utf-8")
    message_data = json.loads(pubsub_message)

    file_path = message_data.get("name", "")

    # ── Ignorar carpetas (GCS notifica también la creación de carpetas) ──
    if file_path.endswith("/"):
        return

    # ── Ignorar silenciosamente subcarpetas que no son de entrada ────────
    for ignored_prefix in IGNORED_PREFIXES:
        if file_path.startswith(ignored_prefix):
            return

    logger.info("=" * 60)
    logger.info(f"📂 Nuevo fichero detectado en GCS")
    logger.info(f"   Path : {file_path}")
    logger.info(f"   Nombre: {file_path.split('/')[-1]}")
    logger.info("=" * 60)

    # ── Buscar DAG correspondiente según el prefijo del fichero ──────────
    dag_id = None
    for prefix, mapped_dag_id in DAG_MAPPING.items():
        if file_path.startswith(prefix):
            dag_id = mapped_dag_id
            break

    if not dag_id:
        logger.warning(f"⚠️ No se encontró DAG configurado para la ruta: {file_path}")
        logger.warning(f"   Añade la ruta al DAG_MAPPING si es una nueva entidad SAP")
        return

    logger.info(f"🚀 Lanzando DAG: {dag_id}")
    trigger_airflow_dag(dag_id, file_path)
    logger.info("=" * 60)
