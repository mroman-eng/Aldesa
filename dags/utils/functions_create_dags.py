from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.google.cloud.hooks.gcs import GCSHook
from airflow.providers.google.cloud.operators.dataform import (
    DataformCreateCompilationResultOperator,
    DataformCreateWorkflowInvocationOperator,
)
from airflow.utils.dates import days_ago
from airflow.utils.trigger_rule import TriggerRule
import pandas as pd
import io
from datetime import timedelta
# Importamos tu log_to_bq desde el mismo directorio utils
from utils.logging import log_to_bq

# --- HELPERS DE LOGGING INTERNOS ---

def _log_step(description, layer, **context):
    """Extrae metadatos del contexto y llama a tu tabla de logs en BQ."""
    dag_id = context['dag'].dag_id
    table_name = dag_id.split('_')[-1].upper()
    batch_id = context['run_id']
    # Solo RAW tiene file_path en la conf
    file_name = context['dag_run'].conf.get('file_path', '') if context.get('dag_run') else ''
    
    log_to_bq(dag_id, table_name, description, layer, file_name, batch_id)

# --- LÓGICA CORE DE RAW ---

def process_parquet_to_bq_logic(tabla_id, config, globals_conf, **context):
    file_path = context['dag_run'].conf.get('file_path')
    bucket_name = globals_conf.get('landing_bucket', "tu-bucket")
    gcs_hook = GCSHook()
    
    # 1. Log Inicio Tarea Procesar
    _log_step("Inicio - Procesar Parquet e Inserción Directa BQ", "raw", **context)
    
    file_data = gcs_hook.download(bucket_name=bucket_name, object_name=file_path)
    df = pd.read_parquet(io.BytesIO(file_data))

    # Añadir Metadatos solicitados
    df['metadata_file_source'] = file_path
    df['metadata_load_timestamp'] = pd.Timestamp.now()
    df['metadata_airflow_run_id'] = context['run_id']

    df.to_gbq(
        destination_table=f"{globals_conf['project_id']}.{globals_conf['bq_dataset_raw']}.{config['table_raw']}",
        project_id=globals_conf['project_id'],
        if_exists='append'
    )
    _log_step("Fin - Procesar Parquet e Inserción Directa BQ", "raw", **context)
    
    # 2. Log Inicio Mover Fichero
    _log_step("Inicio - Mover fichero a processed", "raw", **context)
    new_path = file_path.replace("to_be_processed", "processed")
    gcs_hook.copy(bucket_name, file_path, bucket_name, new_path)
    gcs_hook.delete(bucket_name, file_path)
    _log_step("Fin - Mover fichero a processed", "raw", **context)

# --- FÁBRICAS DE DAGS ---

def create_raw_dag(tabla_id, config, globals_conf, ds_salida):
    default_args = {'retries': 1, 'retry_delay': timedelta(minutes=5)}
    
    with DAG(dag_id=f"dag_raw_{tabla_id}", schedule=None, start_date=days_ago(1), 
             catchup=False, default_args=default_args, tags=config.get('tags_dag_raw')) as dag:
        
        start_dag_log = PythonOperator(
            task_id='start_dag_log',
            python_callable=_log_step,
            op_kwargs={'description': f"INICIO DAG RAW - {tabla_id.upper()}", 'layer': 'raw'}
        )

        process_task = PythonOperator(
            task_id="process_and_move_parquet",
            python_callable=process_parquet_to_bq_logic,
            op_kwargs={'tabla_id': tabla_id, 'config': config, 'globals_conf': globals_conf},
            outlets=[ds_salida]
        )

        end_dag_log = PythonOperator(
            task_id='end_dag_log',
            python_callable=_log_step,
            op_kwargs={'description': f"FIN DAG RAW - {tabla_id.upper()}", 'layer': 'raw'},
            trigger_rule=TriggerRule.ALL_SUCCESS
        )

        start_dag_log >> process_task >> end_dag_log
    return dag

def create_bronze_dag(tabla_id, config, globals_conf, ds_entrada, ds_salida):
    with DAG(dag_id=f"dag_bronze_{tabla_id}", schedule=[ds_entrada], start_date=days_ago(1), 
             catchup=False, tags=config.get('tags_dag_bronze')) as dag:
        
        start_log = PythonOperator(task_id='start_dag_log', python_callable=_log_step, 
                                   op_kwargs={'description': f"INICIO DAG BRONZE - {tabla_id.upper()}", 'layer': 'bronze'})

        # Bloque Compilación
        log_comp_start = PythonOperator(task_id='log_compilation_start', python_callable=_log_step,
                                        op_kwargs={'description': "Inicio - Compilación Dataform", 'layer': 'bronze'})
        compile_df = DataformCreateCompilationResultOperator(
            task_id="create_compilation",
            project_id=globals_conf['project_id'],
            region=globals_conf.get('region', 'europe-west1'),
            repository_id=globals_conf.get('dataform_repo', 'repo-sap'),
            compilation_result={"git_commitish": "main"}
        )
        log_comp_end = PythonOperator(task_id='log_compilation_end', python_callable=_log_step,
                                      op_kwargs={'description': "Fin - Compilación Dataform", 'layer': 'bronze'})

        # Bloque Invocación
        log_invoc_start = PythonOperator(task_id='log_invocation_start', python_callable=_log_step,
                                         op_kwargs={'description': "Inicio - Ejecución Dataform", 'layer': 'bronze'})
        run_df = DataformCreateWorkflowInvocationOperator(
            task_id="run_dataform",
            project_id=globals_conf['project_id'],
            region=globals_conf.get('region', 'europe-west1'),
            repository_id=globals_conf.get('dataform_repo', 'repo-sap'),
            workflow_invocation={
                "invocation_config": {"included_tags": [config['dataform_bronze']]}
            },
            outlets=[ds_salida]
        )
        log_invoc_end = PythonOperator(task_id='log_invocation_end', python_callable=_log_step,
                                       op_kwargs={'description': "Fin - Ejecución Dataform", 'layer': 'bronze'})

        end_log = PythonOperator(task_id='end_dag_log', python_callable=_log_step,
                                 op_kwargs={'description': f"FIN DAG BRONZE - {tabla_id.upper()}", 'layer': 'bronze'})

        start_log >> log_comp_start >> compile_df >> log_comp_end >> log_invoc_start >> run_df >> log_invoc_end >> end_log
    return dag

def create_silver_dag(tabla_id, config, globals_conf, ds_entrada, ds_salida):
    # Lógica idéntica a Bronze pero con tags y layers de Silver
    with DAG(dag_id=f"dag_silver_{tabla_id}", schedule=[ds_entrada], start_date=days_ago(1), 
             catchup=False, tags=config.get('tags_dag_silver')) as dag:
        
        start_log = PythonOperator(task_id='start_dag_log', python_callable=_log_step, 
                                   op_kwargs={'description': f"INICIO DAG SILVER - {tabla_id.upper()}", 'layer': 'silver'})

        log_comp_start = PythonOperator(task_id='log_compilation_start', python_callable=_log_step,
                                        op_kwargs={'description': "Inicio - Compilación Dataform", 'layer': 'silver'})
        compile_df = DataformCreateCompilationResultOperator(
            task_id="create_compilation",
            project_id=globals_conf['project_id'],
            region=globals_conf.get('region', 'europe-west1'),
            repository_id=globals_conf.get('dataform_repo', 'repo-sap'),
            compilation_result={"git_commitish": "main"}
        )
        log_comp_end = PythonOperator(task_id='log_compilation_end', python_callable=_log_step,
                                      op_kwargs={'description': "Fin - Compilación Dataform", 'layer': 'silver'})

        log_invoc_start = PythonOperator(task_id='log_invocation_start', python_callable=_log_step,
                                         op_kwargs={'description': "Inicio - Ejecución Dataform", 'layer': 'silver'})
        run_df = DataformCreateWorkflowInvocationOperator(
            task_id="run_dataform",
            project_id=globals_conf['project_id'],
            region=globals_conf.get('region', 'europe-west1'),
            repository_id=globals_conf.get('dataform_repo', 'repo-sap'),
            workflow_invocation={
                "invocation_config": {"included_tags": [config['dataform_silver']]}
            },
            outlets=[ds_salida]
        )
        log_invoc_end = PythonOperator(task_id='log_invocation_end', python_callable=_log_step,
                                       op_kwargs={'description': "Fin - Ejecución Dataform", 'layer': 'silver'})

        end_log = PythonOperator(task_id='end_dag_log', python_callable=_log_step,
                                 op_kwargs={'description': f"FIN DAG SILVER - {tabla_id.upper()}", 'layer': 'silver'})

        start_log >> log_comp_start >> compile_df >> log_comp_end >> log_invoc_start >> run_df >> log_invoc_end >> end_log
    return dag