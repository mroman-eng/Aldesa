from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime

def saludar():
    print("¡El entorno local funciona correctamente!")

with DAG(
    dag_id="dag_prueba_local",
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    tags=["prueba"],
) as dag:

    tarea = PythonOperator(
        task_id="saludar",
        python_callable=saludar,
    )