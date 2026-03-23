"""
Basic DAG loader tests for PR validation.

These tests intentionally stay lightweight:
- load the repository DAG folder with DagBag
- fail on import errors
- verify at least one DAG is discovered
"""

import os
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
DAGS_PATH = REPO_ROOT / "dags"

os.environ.setdefault("AIRFLOW_HOME", str(REPO_ROOT / ".airflow"))
os.environ.setdefault("AIRFLOW__CORE__LOAD_EXAMPLES", "False")
os.environ.setdefault("AIRFLOW__CORE__UNIT_TEST_MODE", "True")

from airflow.models import DagBag  # noqa: E402


@pytest.fixture(scope="session")
def dagbag():
    return DagBag(dag_folder=str(DAGS_PATH), include_examples=False)


def test_no_import_errors(dagbag):
    assert len(dagbag.import_errors) == 0, (
        "Error importing one or more DAGs:\n"
        f"{dagbag.import_errors}"
    )


def test_contains_dags(dagbag):
    assert len(dagbag.dags) > 0, "No DAGs found in the repository dags/ folder."
