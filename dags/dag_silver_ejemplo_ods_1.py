from airflow import DAG
from google.cloud import dataform_v1beta1
from airflow.providers.google.cloud.operators.dataform import DataformCreateWorkflowInvocationOperator
#from airflow.providers.google.cloud.operators.dataplex import DataplexVerifyDataQualityOperator
#from airflow.providers.google.cloud.operators.dataplex import DataplexDataQualityOperator
#from airflow.providers.google.cloud.operators.dataplex import DataplexCreateDataQualityJobOperator
from airflow.providers.google.cloud.operators.dataplex import DataplexCreateTaskOperator

from datetime import datetime

with DAG("dag_sap_medallion", start_date=datetime(2025, 1, 1), schedule=None, tags=['silver', 'proj', 'ods']) as dag:

    # 1. EJECUCIÓN HACIA ATRÁS: Ejecuta ODS y todo lo que necesite (Bronze y Clean)
    run_silver = DataformCreateWorkflowInvocationOperator(
        task_id="run_silver_ods_full",
        project_id="tu-nuevo-proyecto-gcp",
        region="europe-west1",
        repository_id="tu-repo-dataform",
        workflow_invocation={
            "invocation_config": {
                "included_tags": ["silver_ods"],
                "include_dependencies": True # <--- ESTO ACTIVA EL "HACIA ATRÁS"
            }
        }
    )

    # 2. CONTROL DE CALIDAD: Dataplex revisa el ODS antes de pasar a Gold
    dq_check = DataplexCreateTaskOperator(
        task_id="ejecutar_calidad_ods",
        dataplex_task_id="ejecucion-manual-ods-{{ ds_nodash }}", # ID único para GCP
        project_id="tu-proyecto-gcp",
        region="europe-west1",
        lake_id="tu-lake-id", 
        body={
            "description": "Lanzando el scan manual desde Airflow",
            "trigger_spec": {"type": "ON_DEMAND"},
            "execution_spec": {
                "service_account": "tu-sa@proyecto.iam.gserviceaccount.com",
            },
            # Aquí es donde "enganchas" tu scan manual de la consola
            "spark": {
                "sql_scripts": [], # Se deja vacío
                "main_class": "com.google.cloud.dataplex.templates.dataquality.DataQualityScan",
                "args": {
                    "data_scan_id": "nombre-de-tu-scan-en-gcp" # El ID del scan manual
                }
            }
        },
        gcp_conn_id="google_cloud_default"
    )


    # 3. EJECUCIÓN HACIA ADELANTE: Si el ODS es bueno, actualiza Gold
    run_gold = DataformCreateWorkflowInvocationOperator(
        task_id="run_gold_layer",
        project_id="tu-nuevo-proyecto-gcp",
        region="europe-west1",
        repository_id="tu-repo-dataform",
        workflow_invocation={
            "invocation_config": {
                "included_tags": ["gold"],
                "include_dependents": False # Solo Gold
            }
        }
    )

    run_silver >> dq_check >> run_gold