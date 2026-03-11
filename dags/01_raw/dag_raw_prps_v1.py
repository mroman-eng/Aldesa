# Version Composer 3, Airflow 2.10.5-build.26, google provider 19.0
from airflow import DAG
from datetime import datetime, timedelta
from airflow.providers.google.cloud.hooks.gcs import GCSHook
from airflow.providers.google.cloud.hooks.bigquery import BigQueryHook  # Logs
from airflow.operators.python import PythonOperator
from airflow.operators.trigger_dagrun import TriggerDagRunOperator
from airflow.utils.trigger_rule import TriggerRule
#import time
import os
import logging
import io
import yaml
import pandas as pd
import pandas_gbq 
import uuid
from airflow.utils.email import send_email
from sendgrid.helpers.mail import Mail
from sendgrid import SendGridAPIClient
from airflow.hooks.base import BaseHook


# ----------------------------------------------------------------------
# CONFIGURACIÓN
# ----------------------------------------------------------------------
PROJECT_ID = os.getenv("GCP_PROJECT_ID", "data-buildtrack-dev")
LOCATION   = os.getenv("GCP_LOCATION", "europe-west1")
LAYER_NAME = "raw" # <--- CAMBIA ESTO SEGÚN EL DAG (raw, bronze, silver, gold)

BUCKET           = os.getenv("LANDING_BUCKET", "data-buildtrack-dev-ingesta-sap-europe-west1")
SOURCE_PREFIX    = "raw/sap/prps/to_be_processed/"
PROCESSED_PREFIX = "raw/sap/prps/processed/"
FAILED_PREFIX    = "raw/sap/prps/unprocessed/"

# Configuración de destino en BigQuery
DESTINATION_DATASET = "raw" 
DESTINATION_TABLE   = "prps"       

# Entidad SAP — debe coincidir con la clave 'entity' en el YAML
SAP_ENTITY = "PRPS"

# Ruta al YAML de reglas en el bucket de DAGs de Composer
VALIDATION_RULES_PATH = "/home/airflow/gcs/dags/config/config_validation_rules_global.yaml"


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

    # Intento de log en BigQuery para asegurar trazabilidad aunque fallen los logs de Airflow
    try: 
        log_to_bq(dag_id, SAP_ENTITY, f"CRITICAL_FAILURE en {task_id}: {str(exception)[:200]}") 
    except: 
        pass 
        
    # 2. Email personalizado
    try:
        logging.info("📧 Iniciando proceso de envío de email...")
        conn = BaseHook.get_connection('smtp_default')
        
        if not conn.password: 
             logging.error("❌ ERROR: La conexión 'smtp_default' no tiene Password (API Key)") 
             return
             
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
        
        logging.info(f"📧 Intentando conectar con SendGrid API (Usando conexión: {conn.conn_id})...")
        sg = SendGridAPIClient(conn.password)
        response = sg.send(message)
        logging.info(f"✅ Email enviado correctamente. Status Code: {response.status_code}")
        
    except Exception as e:
        # Esto te dirá en los logs por qué no se mandó (ej. API Key inválida, error de red, etc.)
        #logging.getLogger(__name__).error(f"✗ ERROR ENVIANDO EMAIL: {str(e)}")
        logging.error(f"❌ ERROR DETALLADO SENDGRID: {str(e)}")
        
            

    
    
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
    # RESTAURADO: Alerta de error en logs de Airflow
    'on_failure_callback': custom_failure_callback,
}


# ----------------------------------------------------------------------
# DAG
# ----------------------------------------------------------------------
with DAG(
    dag_id='dag_raw_prps', 
    default_args=default_args,
    schedule_interval=None,  # Lo ejecuta la Cloud Function al detectar fichero en GCS
    catchup=False,
    max_active_runs=1,
    tags=['raw', 'prps'],
) as dag:


    # ------------------------------------------------------------------
    # LOG DE INICIO
    # ------------------------------------------------------------------
        
    def log_dag_start_callable(**context):
        batch_id = context['run_id'] 
        log_to_bq(context['dag_run'].dag_id, SAP_ENTITY, f"INICIO DAG RAW - {context['dag_run'].dag_id}", batch_id=batch_id)

    start_dag_log = PythonOperator(
        task_id='start_dag_log',
        python_callable=log_dag_start_callable,
    )

    
    # ------------------------------------------------------------------
    # PASO 1. VALIDAR PARQUET
    # Lee las reglas desde el YAML y construye el schema de Pandera
    # dinámicamente. Para añadir nuevas reglas o columnas solo hay
    # que tocar el YAML, nunca este código.
    # NO corta el flujo si falla.
    # El fichero se carga en raw siempre, bueno o malo.
    # Ahora captura errores detallados por fila para el campo 'error_description'
    # ------------------------------------------------------------------
    def validate_parquet_callable(**context):
        # Log de inicio — file_name todavía desconocido
        batch_id = context['run_id'] 
        log_to_bq(context['dag'].dag_id, SAP_ENTITY, "Inicio - Validar Parquet", batch_id=batch_id)
        ti = context['ti']
        
        import pandera as pa
        from pandera import Column, DataFrameSchema, Check

        # 1. Leer reglas YAML 
        with open(VALIDATION_RULES_PATH, 'r') as f:
            config = yaml.safe_load(f)
        
        entities_list = config.get('entities', [])
        
        # Buscamos la entidad PRPS dentro de la lista
        columns_config = {}
        for ent in entities_list:
            if ent.get('entity') == SAP_ENTITY:
                columns_config = ent.get('columns', {})
                break

        if not columns_config:
            raise Exception(f"No se encontró configuración para la entidad {SAP_ENTITY} en el YAML")
        
        # 2. Leer fichero de GCS
        hook = GCSHook()
        files = hook.list(bucket_name=BUCKET, prefix=SOURCE_PREFIX)
        files = [f for f in files if not f.endswith('/')]

        if not files:
            log_to_bq(context['dag'].dag_id, SAP_ENTITY, "Fin - Validar Parquet (Error: No hay ficheros)", batch_id=batch_id)
            raise Exception("No se encontró ningún fichero para validar")

        file_path = files[0]
        file_name = file_path.split('/')[-1]  # A partir de aquí ya conocemos el fichero — lo incluimos en todos los logs

        # 3. Leer parquet
        file_bytes = hook.download(bucket_name=BUCKET, object_name=file_path)
        df = pd.read_parquet(io.BytesIO(file_bytes))

        # 4. Construir esquema Pandera con TODAS las validaciones
        pandera_columns = {}
        dtype_map = {
            'str': str, 
            'int64': 'int64', 
            'float64': 'float64', 
            'bool': bool, 
            'datetime64[ns]': 'datetime64[ns]'
        }
        
        for col_name, col_rules in columns_config.items():
            checks = []
            p_dtype = dtype_map.get(col_rules.get('dtype'))
            
            # Validación de Longitud
            if 'min_length' in col_rules: 
                checks.append(Check(lambda x, v=col_rules['min_length']: x.str.len() >= v, name="incorrect_length_min"))
            if 'max_length' in col_rules: 
                checks.append(Check(lambda x, v=col_rules['max_length']: x.str.len() <= v, name="incorrect_length_max"))
            
            # Validación de Rangos Numéricos
            if 'min_val' in col_rules: 
                checks.append(Check.greater_than_or_equal_to(col_rules['min_val'], name="incorrect_range_min"))
            if 'max_val' in col_rules: 
                checks.append(Check.less_than_or_equal_to(col_rules['max_val'], name="incorrect_range_max"))
            
            # Validación Regex
            if 'regex' in col_rules: 
                checks.append(Check.str_matches(col_rules['regex'], name="regex_exp_not_match"))
            
            # Validación de Valores Permitidos
            if 'allowed_values' in col_rules:
                allowed = col_rules['allowed_values']
                checks.append(Check(lambda x, v=allowed: x.isin(v), name="value_not_allowed"))

            pandera_columns[col_name] = Column(
                dtype=p_dtype, 
                checks=checks, 
                nullable=not col_rules.get('not_null', False),
                unique=col_rules.get('unique', False),
                required=True
            )

        schema = DataFrameSchema(columns=pandera_columns, strict=False)
        row_errors = {}
        row_fields = {} # Nuevo diccionario para rastrear qué campos fallan
        validation_passed = True

        # 5. Ejecución de la validación
        try:
            schema.validate(df, lazy=True)            
            log_to_bq(context['dag'].dag_id, SAP_ENTITY, "Fin - Validar Parquet (OK)", file_name, batch_id=batch_id) 
        except pa.errors.SchemaErrors as e:
            validation_passed = False
            
            for _, row in e.failure_cases.iterrows():
                idx = int(row['index']) if pd.notnull(row['index']) else None
                column = str(row['column'])
                raw_check = str(row['check'])
                
                # Traducción de error
                err_msg = "not_null_error" if raw_check == 'not_nullable' else raw_check
                
                if idx is not None:
                    # Concatenación de Errores
                    if idx in row_errors:
                        if err_msg not in row_errors[idx].split(', '): row_errors[idx] += f", {err_msg}"
                    else: row_errors[idx] = err_msg
                    
                    # Concatenación de Campos afectados (NUEVA COLUMNA)
                    if idx in row_fields:
                        if column not in row_fields[idx].split(', '): row_fields[idx] += f", {column}"
                    else: row_fields[idx] = column
            
            log_to_bq(context['dag'].dag_id, SAP_ENTITY,
                      f"Fin - Validar Parquet ({len(row_errors)} filas erróneas)", file_name, batch_id=batch_id)

        # 6. Comprobar columnas críticas — si alguna falla, abortar pipeline
        if not validation_passed:
            critical_columns = [
                col for col, rules in columns_config.items()
                if rules.get('critical', False)
            ]
            # Obtener todas las columnas con errores del mapa row_fields
            all_failed_columns = set()
            for fields_str in row_fields.values():
                for col in fields_str.split(', '):
                    all_failed_columns.add(col)

            failed_critical = [col for col in critical_columns if col in all_failed_columns]

            if failed_critical:
                log_to_bq(context['dag'].dag_id, SAP_ENTITY, f"AVISO CRÍTICO - Columnas críticas con errores: {failed_critical} — Bronze no se lanzará", file_name, batch_id=batch_id)
                ti.xcom_push(key='critical_validation_failed', value=True)
            else:
                ti.xcom_push(key='critical_validation_failed', value=False)
        else:
            ti.xcom_push(key='critical_validation_failed', value=False)

        # 7. Envío de metadatos por XCom
        ti.xcom_push(key='validation_passed', value=validation_passed)
        ti.xcom_push(key='row_errors_map', value=row_errors)
        ti.xcom_push(key='row_fields_map', value=row_fields)
        ti.xcom_push(key='full_file_path', value=file_path)
        ti.xcom_push(key='file_name',      value=file_name)
        return True

    validate_parquet = PythonOperator(
        task_id='validate_parquet',
        python_callable=validate_parquet_callable,
    )

    # ------------------------------------------------------------------
    # PASO 2. INSERCIÓN DIRECTA EN BIGQUERY
    # Incluye metadatos: file_name, load_date, is_valid y error_description
    # ------------------------------------------------------------------
    def load_direct_to_bq_callable(**context):
        ti = context['ti']
        file_path = ti.xcom_pull(task_ids='validate_parquet', key='full_file_path')
        file_name = ti.xcom_pull(task_ids='validate_parquet', key='file_name')
        batch_id = context['run_id']
        log_to_bq(context['dag'].dag_id, SAP_ENTITY, "Inicio - Inserción Directa BQ", file_name, batch_id=batch_id)

        raw_errors = ti.xcom_pull(task_ids='validate_parquet', key='row_errors_map') or {}
        raw_fields = ti.xcom_pull(task_ids='validate_parquet', key='row_fields_map') or {}
        
        # RE-MAPEADO CRÍTICO: Airflow convierte las llaves del dict en strings al serializar
        # Las convertimos de nuevo a int para que coincidan con el índice del DataFrame
        row_errors_map = {int(k): v for k, v in raw_errors.items()}
        row_fields_map = {int(k): v for k, v in raw_fields.items()}
        
        hook = GCSHook()
        file_bytes = hook.download(bucket_name=BUCKET, object_name=file_path)
        df = pd.read_parquet(io.BytesIO(file_bytes))

        # --- AÑADIR NUEVAS COLUMNAS DE METADATOS ---
        
        # Generamos un UUID único para cada fila (el "DNI" del dato)
        df['row_uuid'] = [str(uuid.uuid4()) for _ in range(len(df))]
    
        # Insertamos el ID de ejecución de Airflow (el "Hilo Conductor") como una columna física en RAW
        # El 'batch_id' de Raw indica cuándo se leyó el Parquet.
        df['batch_id'] = context['run_id'] 

        # Metadatos de origen y tiempo
        df['file_name'] = file_name
        df['ingestion_timestamp_raw'] = datetime.utcnow()
        
        # Mapeamos los errores a cada fila
        # Agregamos la descripción técnica del error
        df['error_description'] = df.index.map(row_errors_map).fillna("no_error")
        df['fields_with_errors'] = df.index.map(row_fields_map).fillna("none")
        
        # Si el índice no está en el mapa, está OK
        df['is_valid'] = df['error_description'] == "no_error"
        
        

        destination_table_id = f"{DESTINATION_DATASET}.{DESTINATION_TABLE}"
        
        pandas_gbq.to_gbq(
            df, 
            destination_table_id, 
            project_id=PROJECT_ID, 
            if_exists='append',
            location=LOCATION
        )

        log_to_bq(context['dag'].dag_id, SAP_ENTITY, "Fin - Inserción Directa BQ", file_name, batch_id=batch_id)
        return True

    insert_to_raw = PythonOperator(
        task_id='insert_to_raw',
        python_callable=load_direct_to_bq_callable,
    )

    # ------------------------------------------------------------------
    # PASO 3A. MOVER A PROCESSED (solo si todo fue bien)
    # ------------------------------------------------------------------
    def move_to_processed_callable(**context):        
        ti = context['ti']
        source_file_path = ti.xcom_pull(task_ids='validate_parquet', key='full_file_path')
        file_name        = ti.xcom_pull(task_ids='validate_parquet', key='file_name')
        batch_id = context['run_id'] 
        log_to_bq(context['dag'].dag_id, SAP_ENTITY, "Inicio - Mover fichero a processed", file_name, batch_id=batch_id)
        
        hook = GCSHook()
        dest_file_path = source_file_path.replace(SOURCE_PREFIX, PROCESSED_PREFIX, 1)
        hook.copy(BUCKET, source_file_path, BUCKET, dest_file_path)
        hook.delete(BUCKET, source_file_path)
        log_to_bq(context['dag'].dag_id, SAP_ENTITY, "Fin - Mover fichero a processed", file_name, batch_id=batch_id)

    move_to_processed = PythonOperator(
        task_id="move_to_processed",
        python_callable=move_to_processed_callable,
        trigger_rule=TriggerRule.ALL_SUCCESS,
    )

    # ------------------------------------------------------------------
    # PASO 3B. MOVER A UNPROCESSED (si cualquier tarea anterior falló)
    # Se ejecuta si validate_parquet o insert_to_raw lanzaron excepción.
    # Después re-lanza la excepción para que el DAG quede en FAILED.
    # ------------------------------------------------------------------
    def move_to_unprocessed_callable(**context):        
        ti = context['ti']
        # Intentamos recuperar la ruta del fichero por XCom
        source_file_path = ti.xcom_pull(task_ids='validate_parquet', key='full_file_path')
        file_name        = ti.xcom_pull(task_ids='validate_parquet', key='file_name') or 'unknown_file'
        batch_id = context['run_id'] 
        log_to_bq(context['dag'].dag_id, SAP_ENTITY, "Inicio - Mover fichero a unprocessed", file_name, batch_id=batch_id) 
        
        hook = GCSHook() 
        
        # SI XCOM FALLÓ (ej. validate_parquet no terminó): Buscamos archivos en SOURCE_PREFIX manualmente
        if not source_file_path: 
            logging.warning("XCom no disponible. Rescatando archivo manualmente de SOURCE_PREFIX...") 
            files = hook.list(bucket_name=BUCKET, prefix=SOURCE_PREFIX) 
            files = [f for f in files if not f.endswith('/')] 
            if files: 
                source_file_path = files[0] 
                file_name = source_file_path.split('/')[-1] 
                
        if source_file_path:            
            dest_file_path = source_file_path.replace(SOURCE_PREFIX, FAILED_PREFIX, 1)
            hook.copy(BUCKET, source_file_path, BUCKET, dest_file_path)
            hook.delete(BUCKET, source_file_path)
            log_to_bq(context['dag'].dag_id, SAP_ENTITY, "Fin - Mover fichero a unprocessed", file_name, batch_id=batch_id)
        else:
            log_to_bq(context['dag'].dag_id, SAP_ENTITY, "ERROR - No se pudo recuperar el path del fichero para mover a unprocessed", file_name, batch_id=batch_id)
        # Re-lanzamos excepción para que el DAG quede en estado FAILED
        raise Exception(f"DAG RAW FAILED — El fichero {file_name} se ha movido a unprocessed.")

    move_to_unprocessed = PythonOperator(
        task_id="move_to_unprocessed",
        python_callable=move_to_unprocessed_callable,
        trigger_rule=TriggerRule.ONE_FAILED,
    )

    # ------------------------------------------------------------------
    # PASO 4. TRIGGER DAG BRONZE (pendiente de activar)
    # Tras la validación Pandera, si validation_passed = False recoge todas las columnas con errores
    # Las cruza con las columnas marcadas como critical: true en el YAML
    # Si alguna columna crítica tiene errores → loguea en BQ + lanza excepción → move_to_unprocessed → Bronze no se lanza
    # ------------------------------------------------------------------
    
    def check_critical_callable(**context):
        ti = context['ti']
        critical_failed = ti.xcom_pull(task_ids='validate_parquet', key='critical_validation_failed')
        if critical_failed:
            raise Exception("Validación crítica fallida — Bronze no se lanza, fichero en processed")

    check_critical = PythonOperator(
        task_id='check_critical',
        python_callable=check_critical_callable,
        trigger_rule=TriggerRule.ALL_SUCCESS,
    )

    def log_trigger_start(**context):
        ti        = context['ti']
        file_name = ti.xcom_pull(task_ids='validate_parquet', key='file_name')
        batch_id  = context['run_id']
        log_to_bq(context['dag'].dag_id, SAP_ENTITY, "INICIO - Trigger DAG Bronze", file_name, batch_id=batch_id)

    log_trigger_start_task = PythonOperator(
        task_id='log_trigger_start',
        python_callable=log_trigger_start
    )

    trigger_bronze = TriggerDagRunOperator(
        task_id='trigger_bronze',
        trigger_dag_id='dag_bronze_prps',
        trigger_rule=TriggerRule.ALL_SUCCESS,
        wait_for_completion=False,
        conf={
            'batch_id': "{{ run_id }}",
            'file_name': "{{ ti.xcom_pull(task_ids='validate_parquet', key='file_name') }}",
        },
    )

    def log_trigger_end(**context):
        ti        = context['ti']
        file_name = ti.xcom_pull(task_ids='validate_parquet', key='file_name')
        batch_id  = context['run_id']
        log_to_bq(context['dag'].dag_id, SAP_ENTITY, "FIN - Trigger DAG Bronze", file_name, batch_id=batch_id)

    log_trigger_end_task = PythonOperator(
        task_id='log_trigger_end',
        python_callable=log_trigger_end
    )
    

    # --- LOG FIN DAG RAW ---
    def log_dag_end_callable(**context):
        ti        = context['ti']
        file_name = ti.xcom_pull(task_ids='validate_parquet', key='file_name') or ''
        batch_id  = context['run_id']
        log_to_bq(context['dag'].dag_id, SAP_ENTITY, f"FIN DAG RAW {context['dag'].dag_id}", file_name, batch_id=batch_id) 

    end_dag_log = PythonOperator(
        task_id='end_dag_log',
        python_callable=log_dag_end_callable,
        trigger_rule=TriggerRule.ALL_SUCCESS,
    )

    # ------------------------------------------------------------------
    # FLUJO
    # Ruta éxito total:         start >> validate >> insert >> move_to_processed >> check_critical >> log_trigger_start >> trigger_bronze >> log_trigger_end >> end_dag_log
    # Ruta crítica Pandera:     validate >> insert >> move_to_processed >> check_critical(falla) >> end_dag_log (sin Bronze, DAG failed)
    # Ruta fallo técnico:       validate o insert fallan >> move_to_unprocessed (DAG FAILED)
    # ------------------------------------------------------------------
    start_dag_log >> validate_parquet >> insert_to_raw >> move_to_processed >> check_critical >> log_trigger_start_task >> trigger_bronze >> log_trigger_end_task >> end_dag_log
    [validate_parquet, insert_to_raw] >> move_to_unprocessed