from airflow.providers.google.cloud.hooks.bigquery import BigQueryHook
from datetime import datetime
from datetime import datetime, timezone
import os

PROJECT_ID = os.getenv("GCP_PROJECT_ID", "tu-proyecto-gcp")
PROJECT_ID = os.getenv("GCP_PROJECT", os.getenv("GCP_PROJECT_ID", "tu-proyecto-gcp"))

def log_to_bq(dag_id, table_name, description, layer, file_name='', batch_id=''):
    """Inserta logs de auditoría en la tabla personalizada de BigQuery."""
    hook = BigQueryHook()
    rows = [{
        "load_date":   datetime.utcnow().isoformat(),
        "load_date":   datetime.now(timezone.utc).isoformat(),
        "dag_name":    dag_id,
        "table_name":  table_name,
        "description": description,
        "layer":       layer,
        "file_name":   file_name,
        "batch_id":    batch_id, 
    }]
    hook.insert_all(
        project_id=PROJECT_ID, 
        dataset_id="logs", 
        table_id="dag_logs", 
        rows=rows
    )