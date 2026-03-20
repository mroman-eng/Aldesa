"""
Instructions to run this test locally or in CI/CD:

1. Install Airflow and testing dependencies:
   pip install apache-airflow pytest

2. Make sure to install any extra libraries (e.g. requirements.txt) required by the DAGs.

3. Set the AIRFLOW_HOME environment variable to the root of this project.
   In the console (from the project root):
   export AIRFLOW_HOME=$(pwd)

4. Run the test with pytest:
   pytest tests/dags/test_dag_integrity.py
"""
import os
import pytest
from airflow.models import DagBag

# Setup path for DAGs
DAG_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "dags"))

@pytest.fixture(scope="session")
def dagbag():
    """Returns a DagBag loaded with the DAGs in the repository."""
    return DagBag(dag_folder=DAG_PATH, include_examples=False)

def test_no_import_errors(dagbag):
    """
    Test to check there are no import errors when loading the DAGs.
    This guarantees that there are no syntax errors, missing dependencies,
    or broken imports in our DAG files.
    """
    assert len(dagbag.import_errors) == 0, f"Error importing one or more DAGs:\n{dagbag.import_errors}"

def test_contains_dags(dagbag):
    """
    Test to check if the DagBag contains at least one DAG.
    This ensures that the test setup is correct and reading the correct folder.
    """
    assert len(dagbag.dags) > 0, "No DAGs found in the 'dags' folder."
