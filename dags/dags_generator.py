# ==========================================
# FICHERO: dags/dags_generator.py
# ==========================================
import os
import yaml
import logging
from airflow import Dataset
from datetime import timedelta

# Importamos las funciones factoría desde el otro fichero
# Asegúrate de que functions_create_dags.py esté en la misma carpeta o en el PYTHONPATH
from utils.functions_create_dags import create_raw_dag, create_bronze_dag, create_silver_dag

# Configurar logging
logger = logging.getLogger(__name__)

# 1. RUTA DEL FICHERO DE CONFIGURACIÓN
# Obtenemos la ruta del directorio donde está ESTE archivo (dags/)
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))

# Construimos la ruta hacia la carpeta config
CONFIG_PATH = os.path.join(CURRENT_DIR, 'config', 'tablas_sap.yml')

# Opcional: Imprimir para debug en los logs de Astro
print(f"--- Intentando cargar YAML desde: {CONFIG_PATH} ---")

def load_config(path):
    """Carga el fichero YAML de configuración."""
    try:
        with open(path, 'r') as f:
            return yaml.safe_load(f)
    except Exception as e:
        logger.error(f"Error cargando el fichero YAML en {path}: {e}")
        return None

# 2. CARGA DE CONFIGURACIÓN
config = load_config(CONFIG_PATH)

if config:
    tablas = config.get('tablas', {})
    globals_conf = config.get('globals', {})

    # 3. BUCLE GENERADOR DE DAGS
    for tabla_id, info in tablas.items():
        
        # --- DEFINICIÓN DE DATASETS (Los puentes entre capas) ---
        # Estos Datasets permiten que los DAGs se comuniquen de forma reactiva
        # Leemos las URIs directamente del YAML para mantener el Single Point of Control
        ds_raw    = Dataset(info['dataset_raw_outlet'])
        ds_bronze = Dataset(info['dataset_bronze_outlet'])
        ds_silver = Dataset(info['dataset_silver_outlet'])

        # --- CAPA 1: GENERACIÓN DE DAG RAW ---
        # No tiene schedule (schedule=None) porque lo lanza la Cloud Function
        dag_raw_id = f"dag_raw_{tabla_id}"
        globals()[dag_raw_id] = create_raw_dag(
            tabla_id=tabla_id,
            config=info,
            globals_conf=globals_conf,
            dataset_salida=ds_raw
        )

        # --- CAPA 2: GENERACIÓN DE DAG BRONZE ---
        # Se lanza automáticamente cuando el DAG RAW actualiza 'ds_raw'
        dag_bronze_id = f"dag_bronze_{tabla_id}"
        globals()[dag_bronze_id] = create_bronze_dag(
            tabla_id=tabla_id,
            config=info,
            globals_conf=globals_conf,
            dataset_entrada=ds_raw,
            dataset_salida=ds_bronze
        )

        # --- CAPA 3: GENERACIÓN DE DAG SILVER ---
        # Se lanza automáticamente cuando el DAG BRONZE actualiza 'ds_bronze'
        dag_silver_id = f"dag_silver_{tabla_id}"
        globals()[dag_silver_id] = create_silver_dag(
            tabla_id=tabla_id,
            config=info,
            globals_conf=globals_conf,
            dataset_entrada=ds_bronze,
            dataset_salida=ds_silver
        )

    logger.info(f"✅ Se han generado dinámicamente los DAGs para {len(tablas)} tablas SAP.")
else:
    logger.error("❌ No se pudo cargar la configuración. Los DAGs no se generarán.")