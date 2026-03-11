#Version Composer 3, Airflow 2.10.5-build.26, google provider 19.0
from airflow import DAG
from datetime import datetime, timedelta
from airflow.operators.python import PythonOperator
from airflow.operators.trigger_dagrun import TriggerDagRunOperator
from airflow.providers.google.cloud.hooks.bigquery import BigQueryHook
from airflow.utils.trigger_rule import TriggerRule
import logging
import os
from airflow.utils.email import send_email
from sendgrid.helpers.mail import Mail
from sendgrid import SendGridAPIClient
from airflow.hooks.base import BaseHook

# Se importan los operadores de Dataform
from airflow.providers.google.cloud.operators.dataform import (
    DataformCreateCompilationResultOperator,
    DataformCreateWorkflowInvocationOperator,
)


# ----------------------------------------------------------------------
# CONFIGURACIÓN
# ----------------------------------------------------------------------
PROJECT_ID    = os.getenv("GCP_PROJECT_ID", "data-buildtrack-dev")
LOCATION      = os.getenv("GCP_LOCATION", "europe-west1")
REGION        = os.getenv("GCP_REGION", "europe-west1")
REPOSITORY_ID = os.getenv("GCP_REPOSITORY_ID", "europe-west1")
LAYER_NAME    = "bronze"
SAP_ENTITY    = "PROJ"

#Airflow le dice a Google: 
#"Ejecuta todo lo que en Dataform tenga el tag 'proj_bronze'". 
#Por lo tanto, el tag en el SQLX debe coincidir exactamente con este tag:
DATAFORM_TAGS          = ["proj_bronze"]
DATAFORM_GIT_COMMITISH = "main"


# ----------------------------------------------------------------------
# --- FUNCIÓN DE LOGGING ---
# ----------------------------------------------------------------------
def log_to_bq(dag_id, table_name, description, file_name='', batch_id=''):
    hook = BigQueryHook()
    rows = [{
        "load_date":   datetime.utcnow().isoformat(),
        "dag_name":    dag_id,
        "table_name":  table_name,
        "description": description,
        "layer":       LAYER_NAME, 
        "file_name":   file_name,
        "batch_id":    batch_id,
    }]
    hook.insert_all(project_id=PROJECT_ID, dataset_id="logs", table_id="dag_logs", rows=rows)


# Para recuperar file_name del conf en cada tarea
def get_file_name(context):
    return context['dag_run'].conf.get('file_name', '')


# Para recuperar batch_id del run_id de Airflow en cada tarea  
def get_batch_id(context): 
    return context['dag_run'].conf.get('batch_id', context['run_id'])  
    
    

# ----------------------------------------------------------------------
# --- FUNCIÓN DE CORREO EN CASO DE FALLO EN EL DAG ---
# ----------------------------------------------------------------------

def custom_failure_callback(context):
    dag_id    = context['dag'].dag_id
    task_id   = context['task'].task_id
    exec_date = context['execution_date']
    exception = context.get('exception')

    # 1. Log en Airflow — igual que antes
    logging.getLogger(__name__).error(
        f"✗ TAREA FALLÓ: {task_id} | Error: {exception}"
    )

    # 2. Email personalizado 
    try:
        conn = BaseHook.get_connection('smtp_default')
        message = Mail(
            from_email='maypher.roman@vasscompany.com',  # ← tu email verificado en SendGrid
            to_emails=['maypher.roman@vasscompany.com', 'jorge.gonzalezd@vasscompany.com'],
            subject=f"🚨 Error en pipeline SAP - {dag_id}",
            html_content=f"""
            <h3>Se ha producido un error en el pipeline de datos SAP</h3>
            <b>DAG:</b> {dag_id}<br>
            <b>Tarea:</b> {task_id}<br>
            <b>Fecha ejecución:</b> {exec_date}<br>
            <b>Error:</b> {exception}<br>
            <br>
            Accede a Airflow para ver los logs completos.
            """
        )
        sg = SendGridAPIClient(conn.password)
        sg.send(message)
    except Exception as e:
        logging.getLogger(__name__).error(f"✗ ERROR ENVIANDO EMAIL: {str(e)}")
        
    
    
    
# ----------------------------------------------------------------------
# DEFAULT ARGS (Con Callback de Error)
# ----------------------------------------------------------------------

default_args = {
    'owner':       'airflow',
    'retries':     2,
    'retry_delay': timedelta(minutes=5),
    'start_date':  datetime(2025, 1, 1),
    #'email': ['pepe@aldesa.es', 'ana@aldesa.es', 'juan@aldesa.es'], 
    #'email_on_failure':    True, 
    # Es fundamental para que, si algo falla, veas el error exacto en los logs de Airflow:
    'on_failure_callback': custom_failure_callback,
}

# ----------------------------------------------------------------------
# DAG
# ----------------------------------------------------------------------
with DAG(
    dag_id='dag_bronze_proj',
    default_args=default_args,
    schedule_interval=None,
    catchup=False,
    max_active_runs=1,
    tags=['bronze', 'proj'],
    # Si no encuentras la variable, no rompas el proceso inmediatamente; trátalo como un valor nulo/vacío:
    #template_undefined=None
) as dag:


    # ------------------------------------------------------------------
    # LOG DE INICIO
    # ------------------------------------------------------------------
    
    def log_dag_start_callable(**context):
        log_to_bq(context['dag_run'].dag_id, SAP_ENTITY,
                  f"INICIO DAG BRONZE - {context['dag_run'].dag_id}", get_file_name(context), batch_id=get_batch_id(context)) 

    start_dag_log_task = PythonOperator(
        task_id='start_dag_log',
        python_callable=log_dag_start_callable,
    )
    
    
    # ------------------------------------------------------------------
    # PASO 1: CREAR COMPILACIÓN EN DATAFORM
    # ------------------------------------------------------------------
    
    def log_compilation_start(**context):
        log_to_bq(context['dag'].dag_id, SAP_ENTITY,
                  "Inicio - Paso 1: Compilación Dataform", get_file_name(context), batch_id=get_batch_id(context))

    log_compilation_task = PythonOperator(
        task_id='log_compilation_start',
        python_callable=log_compilation_start
    )

    # Capturamos batch_id del conf (enviado por RAW)
    # Ya NO capturamos currentFile porque ya está en la tabla RAW
    batch_id_val = "{{ dag_run.conf.get('batch_id', 'manual_' + macros.datetime.now().strftime('%Y%m%d%H%M%S')) }}"

    create_compilation = DataformCreateCompilationResultOperator(
        task_id="create_compilation",
        project_id=PROJECT_ID,
        region=REGION,
        repository_id=REPOSITORY_ID,
        compilation_result={
            "git_commitish": DATAFORM_GIT_COMMITISH,
            "code_compilation_config": {
                "vars": {
                    "batchId": batch_id_val
                }
            },
        },
    )

    def log_compilation_end(**context):
        log_to_bq(context['dag'].dag_id, SAP_ENTITY,
                  "Fin - Paso 1: Compilación Dataform", get_file_name(context), batch_id=get_batch_id(context))

    log_compilation_end_task = PythonOperator(
        task_id='log_compilation_end',
        python_callable=log_compilation_end
    )

    # ------------------------------------------------------------------
    # PASO 2: EJECUTAR DATAFORM CON POLLING
    # ------------------------------------------------------------------
    def log_invocation_start(**context):
        log_to_bq(context['dag'].dag_id, SAP_ENTITY,
                  "Inicio - Paso 2: Ejecución Dataform", get_file_name(context), batch_id=get_batch_id(context))

    log_invocation_task = PythonOperator(
        task_id='log_invocation_start',
        python_callable=log_invocation_start
    )

    run_dataform = DataformCreateWorkflowInvocationOperator(
        task_id="run_dataform_workflow",
        project_id=PROJECT_ID,
        region=REGION,
        repository_id=REPOSITORY_ID,
        workflow_invocation={
            "compilation_result": "{{ ti.xcom_pull(task_ids='create_compilation')['name'] }}",
            "invocation_config": {
                "included_tags": DATAFORM_TAGS,
                # Esto es vital: evita que Bronze intente ejecutar Raw otra vez por error.
                "transitive_dependencies_included": False,
            },
        },
    )

    def log_invocation_end(**context):
        log_to_bq(context['dag'].dag_id, SAP_ENTITY,
                  "Fin - Paso 2: Ejecución Dataform", get_file_name(context), batch_id=get_batch_id(context))

    log_invocation_end_task = PythonOperator(
        task_id='log_invocation_end',
        python_callable=log_invocation_end
    )

        
    
    # ------------------------------------------------------------------
    # PASO 3: TRIGGER DAG SILVER
    # Solo se ejecuta si Dataform bronze completó con éxito.
    # No necesita pasar variables ya que batch_id y source_file
    # viajan dentro de los propios datos desde bronze.
    # ------------------------------------------------------------------
    
    def log_trigger_silver_start(**context):
        log_to_bq(context['dag'].dag_id, SAP_ENTITY,
                  "Inicio - Paso 3: Trigger DAG Silver", get_file_name(context), batch_id=get_batch_id(context))

    log_trigger_silver_task = PythonOperator(
        task_id='log_trigger_silver_start',
        python_callable=log_trigger_silver_start
    )
    
    trigger_silver = TriggerDagRunOperator(
        task_id='trigger_silver',
        trigger_dag_id='dag_silver_proj', # Ajustar al nombre real de tu DAG de Silver
        conf={
            'batch_id':  "{{ dag_run.conf.get('batch_id') }}",
            'file_name': "{{ dag_run.conf.get('file_name', '') }}",
        },
        wait_for_completion=False,
    )
    
    def log_trigger_silver_end(**context):
        log_to_bq(context['dag'].dag_id, SAP_ENTITY,
                  "Fin - Paso 3: Trigger DAG Silver", get_file_name(context), batch_id=get_batch_id(context))

    log_trigger_silver_end_task = PythonOperator(
        task_id='log_trigger_silver_end',
        python_callable=log_trigger_silver_end
    )
    
    '''
    # --- LOG FIN DAG ---
    def log_dag_end_callable(**context):
        log_to_bq(context['dag'].dag_id, SAP_ENTITY,
                  f"FIN DAG BRONZE - DAG {context['dag'].dag_id}", get_file_name(context), batch_id=get_batch_id(context))

    end_dag_log = PythonOperator(
        task_id='end_dag_log',
        python_callable=log_dag_end_callable,
        trigger_rule=TriggerRule.ALL_DONE
    )
    '''
    
    # ------------------------------------------------------------------
    # TAREA DE ÉXITO 
    # ------------------------------------------------------------------
    def log_success_callable(**context):
        log_to_bq(context['dag'].dag_id, SAP_ENTITY,
                  f"FIN DAG BRONZE - {context['dag'].dag_id} completado", get_file_name(context), batch_id=get_batch_id(context))
        logging.info("✓ DAG BRONZE COMPLETADO")

    success_log = PythonOperator(
        task_id='success_log',
        python_callable=log_success_callable,
        trigger_rule=TriggerRule.ALL_SUCCESS
    )

    # ------------------------------------------------------------------
    # TAREA FINAL DE FALLO (Si Dataform falla) 
    # ------------------------------------------------------------------
    def handle_failure_callable(**context):
        log_to_bq(context['dag'].dag_id, SAP_ENTITY,
                  "ERROR DAG BRONZE - Fallo en capa Bronze", get_file_name(context), batch_id=get_batch_id(context))
        logging.error("✗ DAG BRONZE FALLÓ")

    failure_handler = PythonOperator(
        task_id='failure_handler',
        python_callable=handle_failure_callable,
        trigger_rule=TriggerRule.ONE_FAILED
    )

    
    
    
    # ------------------------------------------------------------------
    # FLUJO
    # ------------------------------------------------------------------
    
    # Bloque 1: Compilación
    start_dag_log_task >> log_compilation_task >> create_compilation >> log_compilation_end_task
    
    # Bloque 2: Ejecución Dataform
    log_compilation_end_task >> log_invocation_task >> run_dataform >> log_invocation_end_task
    
    # Bloque 3: Trigger Silver (Solo si la ejecución fue bien)
    log_invocation_end_task >> log_trigger_silver_task >> trigger_silver >> log_trigger_silver_end_task
    
    # Bloque 4: Cierre de seguridad
    # ÉXITO: Se dispara solo si el paso final del trigger termina bien
    log_trigger_silver_end_task >> success_log
    
    # FALLO: Se dispara si cualquiera de las tareas críticas falla (especialmente la ejecución)
    run_dataform >> failure_handler