#Version Composer 3, Airflow 2.10.5-build.26, google provider 19.0
from airflow import DAG
from datetime import datetime, timedelta
from airflow.operators.python import PythonOperator
from airflow.providers.google.cloud.hooks.bigquery import BigQueryHook
from airflow.providers.google.cloud.operators.dataform import (
    DataformCreateCompilationResultOperator,
    DataformCreateWorkflowInvocationOperator,
)
from airflow.utils.trigger_rule import TriggerRule
import logging
import os
from airflow.utils.email import send_email
from airflow.operators.email import EmailOperator
from airflow.exceptions import AirflowFailException


# ----------------------------------------------------------------------
# CONFIGURACIÓN
# ----------------------------------------------------------------------
PROJECT_ID    = os.getenv("GCP_PROJECT_ID", "data-buildtrack-dev")
LOCATION      = os.getenv("GCP_LOCATION", "europe-west1")
REGION        = os.getenv("GCP_REGION", "europe-west1")
REPOSITORY_ID = os.getenv("GCP_REPOSITORY_ID", "europe-west1")
LAYER_NAME    = "silver"
SAP_ENTITY    = "PROJ"

# El tag debe coincidir con el que pusimos en el fichero SQLX de Silver
DATAFORM_TAGS          = ["proj_silver"]
DATAFORM_GIT_COMMITISH = "main"

# Configuración de notificaciones
RECIPIENTS = ["maypher.roman@vasscompany.com","jorge.gonzalezd@vasscompany.com"] 


# ----------------------------------------------------------------------
# --- FUNCIÓN DE LOGGING ---
# ----------------------------------------------------------------------
def log_to_bq(dag_id, table_name, description, file_name='', batch_id=''):
    hook = BigQueryHook()
    rows = [{
        "load_date": datetime.utcnow().isoformat(),
        "dag_name": dag_id,
        "table_name": table_name,
        "description": description,
        "layer": LAYER_NAME,
        "file_name":   file_name,
        "batch_id":    batch_id,
    }]
    hook.insert_all(project_id=PROJECT_ID, dataset_id="logs", table_id="dag_logs", rows=rows)
    

# Para recuperar file_name del conf en cada tarea
def get_file_name(context):
    return context['dag_run'].conf.get('file_name', '')
    
    
# Para recuperar batch_id del conf (enviado por Bronze) o del run_id de Airflow como fallback  
def get_batch_id(context):  
    return context['dag_run'].conf.get('batch_id', context['run_id']) 
    
    
'''
# ----------------------------------------------------------------------
# --- FUNCIÓN DE CORREO EN CASO DE FALLO EN EL DAG ---
# ----------------------------------------------------------------------

def custom_failure_callback(context):
    """
    Esta función se dispara automáticamente al fallar cualquier tarea del DAG.
    Envía un correo personalizado y fuerza el estado FAILED en Airflow.
    """
    ti = context.get('task_instance')
    dag_id = context.get('dag').dag_id
    task_id = ti.task_id
    error_msg = context.get('exception')
    log_url = ti.log_url
    execution_date = context.get('execution_date')

    # Configuración del cuerpo del mensaje personalizado (HTML)
    subject = f"⚠️ ERROR CRÍTICO - Capa Silver: {dag_id}"
    body = f"""
    <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6;">
            <h2 style="color: #d32f2f;">Fallo en la ejecución del DAG Silver</h2>
            <hr>
            <p><b>DAG:</b> {dag_id}</p>
            <p><b>Tarea:</b> {task_id}</p>
            <p><b>Fecha de ejecución:</b> {execution_date}</p>
            <p style="color: #555;"><b>Mensaje de error:</b><br>
            <code style="background: #f4f4f4; padding: 5px; display: block;">{error_msg}</code></p>
            <br>
            <a href="{log_url}" style="background-color: #0288d1; color: white; padding: 10px 15px; text-decoration: none; border-radius: 5px;">
                Ver Logs Completos en Airflow
            </a>
            <br><br>
            <p style="font-size: 0.8em; color: #888;">Este es un mensaje automático generado por el sistema de auditoría de data-ai-lab-485911.</p>
        </body>
    </html>
    """

    # Enviar el correo usando EmailOperator de forma interna
    email_op = EmailOperator(
        task_id='send_error_email',
        to=['tu_correo@dominio.com'], # SUSTITUYE POR TU CORREO REAL
        subject=subject,
        html_content=body
    )
    email_op.execute(context)

    # LÓGICA DE FALLO: Importante para que el DAG no se marque como SUCCESS
    print(f"Callback ejecutado para la tarea {task_id}. Correo enviado.")
    
    # Si quieres que Airflow se detenga y muestre el error en rojo:
    raise AirflowFailException(f"Fallo en {task_id}. Notificación enviada.")
'''
    
# ----------------------------------------------------------------------
# DEFAULT ARGS
# ----------------------------------------------------------------------
default_args = {
    'owner':       'airflow',
    'retries':     2,
    'retry_delay': timedelta(minutes=5),
    'start_date':  datetime(2025, 1, 1),
    #'email': ['pepe@aldesa.es', 'ana@aldesa.es', 'juan@aldesa.es'],  
    #'email_on_failure':    True, 
    #'email_on_retry': False,
    # Es fundamental para que, si algo falla, veas el error exacto en los logs de Airflow:
    'on_failure_callback': None  #custom_failure_callback,
}

# ----------------------------------------------------------------------
# DAG
# ----------------------------------------------------------------------
with DAG(
    dag_id='dag_silver_proj',
    default_args=default_args,
    schedule_interval=None,
    catchup=False,
    max_active_runs=1,
    tags=['silver', 'proj'],
    # Si no encuentras la variable, no rompas el proceso inmediatamente; trátalo como un valor nulo/vacío:
    #template_undefined=None
) as dag:


    # ------------------------------------------------------------------
    # LOG DE INICIO
    # ------------------------------------------------------------------
    def log_dag_start_callable(**context):
        log_to_bq(context['dag'].dag_id, SAP_ENTITY,
                  f"INICIO DAG SILVER - {context['dag'].dag_id}", get_file_name(context), batch_id=get_batch_id(context))
        
    log_dag_start = PythonOperator(
        task_id='log_dag_start',
        python_callable=log_dag_start_callable
    )
    
    
    # ------------------------------------------------------------------
    # PASO 1: CREAR COMPILACIÓN DATAFORM
    # Las variables batch_id y source_file ya viajan dentro de los
    # datos desde bronze, no es necesario pasarlas por conf.
    # Solo se pasan las variables de entorno necesarias para Dataform.
    # ------------------------------------------------------------------
    
    def log_compilation_start(**context):
        log_to_bq(context['dag'].dag_id, SAP_ENTITY,
                  "Inicio - Paso 1: Compilación Dataform", get_file_name(context), batch_id=get_batch_id(context))

    log_compilation_task = PythonOperator(
        task_id='log_compilation_start',
        python_callable=log_compilation_start
    )
    
    # Capturamos el batch_id de la misma forma que en Bronze
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
    # Ejecuta los modelos con el tag proj_silver_dev, que incluye
    # el renombrado de columnas a nombres de negocio y posible
    # limpieza de datos.
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
                # Esto es vital: evita que Silver intente ejecutar Bronze o Raw otra vez por error.
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
    
    '''
    # --- LOG FIN DAG ---
    def log_dag_end_callable(**context):
        log_to_bq(context['dag'].dag_id, SAP_ENTITY,
                  f"FIN DAG SILVER - {context['dag'].dag_id}", get_file_name(context))

    end_dag_log = PythonOperator(
        task_id='end_dag_log',
        python_callable=log_dag_end_callable,
        trigger_rule=TriggerRule.ALL_DONE
    )
    '''
    
    
    # ------------------------------------------------------------------
    # TAREA FINAL DE ÉXITO
    # ------------------------------------------------------------------
    def log_success_callable(**context):
        log_to_bq(context['dag'].dag_id, SAP_ENTITY,
                  f"FIN DAG SILVER - {context['dag'].dag_id}", get_file_name(context), batch_id=get_batch_id(context))
        logging.info("✓ DAG SILVER COMPLETADO EXITOSAMENTE")

    success_log = PythonOperator(
        task_id='success_log',
        python_callable=log_success_callable,
        trigger_rule=TriggerRule.ALL_SUCCESS,
    )
    
    
    # ------------------------------------------------------------------
    # TAREA DE FALLO
    # ------------------------------------------------------------------
    def handle_failure_callable(**context):
        ti = context.get('task_instance')
        dag_id = context['dag'].dag_id
        task_id = ti.task_id
        log_url = ti.log_url
        
        # 1. log en BigQuery
        log_to_bq(dag_id, SAP_ENTITY, f"Error - Fallo en tarea: {task_id}", get_file_name(context), batch_id=get_batch_id(context))
        
        # 2. Correo Personalizado
        subject = f"⚠️ ERROR CRÍTICO - Capa Silver: {dag_id}"
        body = f"""
        <html>
            <body style="font-family: Arial, sans-serif;">
                <h2 style="color: #d32f2f;">Fallo en la ejecución del DAG Silver</h2>
                <hr>
                <p><b>DAG:</b> {dag_id}</p>
                <p><b>Tarea afectada:</b> {task_id}</p>
                <p><b>Entidad:</b> {SAP_ENTITY}</p>
                <br>
                <a href="{log_url}" style="background-color: #0288d1; color: white; padding: 10px 15px; text-decoration: none; border-radius: 5px;">
                    Ver Logs Completos en Airflow
                </a>
            </body>
        </html>
        """
        try:
            email_op = EmailOperator(
                task_id='send_failure_email',
                to=RECIPIENTS,
                subject=f"⚠️ ERROR CRÍTICO - Capa Silver: {dag_id}",
                html_content=f"Fallo en {task_id}. <br><a href='{ti.log_url}'>Ver logs</a>"
            )
            email_op.execute(context)
        except Exception as e:
            logging.error(f"Error enviando correo: {e}")
        
        # 3. Forzamos el estado FAILED para que el DAG aparezca en rojo
        raise AirflowFailException(f"Fallo detectado en {task_id}. Notificación enviada.")

    failure_handler = PythonOperator(
        task_id='failure_handler',
        python_callable=handle_failure_callable,
        trigger_rule=TriggerRule.ONE_FAILED,
    )

    



    # ------------------------------------------------------------------
    # FLUJO
    # ------------------------------------------------------------------
    
    # 1. Bloque de Compilación
    log_dag_start >> log_compilation_task >> create_compilation >> log_compilation_end_task
    
    # 2. Bloque de Ejecución
    log_compilation_end_task >> log_invocation_task >> run_dataform >> log_invocation_end_task
    
    # Camino de éxito
    log_invocation_end_task >> success_log
    
    # Camino de fallo (Cualquier tarea crítica conectada al handler)
    [create_compilation, run_dataform] >> failure_handler