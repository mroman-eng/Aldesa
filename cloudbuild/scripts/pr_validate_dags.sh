#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pr_comment_lib.sh"

RESULT_DIR="${PR_RESULT_DIR:-/workspace/.cloudbuild/pr-validation}"
RESULT_ENV_FILE="${RESULT_DIR}/result.env"
COMMENT_BODY_FILE="${RESULT_DIR}/comment.md"
CHANGED_FILES_FILE="${RESULT_DIR}/changed_files.txt"
LOG_DIR="${RESULT_DIR}/logs"
NOOP_LOG_FILE="${LOG_DIR}/scope.log"
AIRFLOW_INSTALL_LOG_FILE="${LOG_DIR}/airflow_install.log"
AIRFLOW_TEST_VERSION_FILE="${LOG_DIR}/airflow_test_version.txt"
AIRFLOW_TEST_HOME="${RESULT_DIR}/.airflow"

mkdir -p "${LOG_DIR}"

BUILD_LOG_URL="$(pr_build_log_url)"
TIMESTAMP_UTC="$(pr_now_utc)"
COMMENT_SCOPE="dags"
COMMENT_TITLE="DAG PR Validation"
OVERALL_STATUS="SUCCESS"
DAG_TEST_STATUS="SKIPPED"
RELEVANT_CHANGES="false"

./cloudbuild/scripts/fetch_github_pr_files.sh "${CHANGED_FILES_FILE}"

while IFS= read -r changed_file; do
  case "${changed_file}" in
    dags/*|tests/dags/*|composer/requirements.txt)
      RELEVANT_CHANGES="true"
      break
      ;;
  esac
done <"${CHANGED_FILES_FILE}"

run_phase() {
  local phase="$1"
  local log_file="$2"
  shift 2

  set +e
  "$@" 2>&1 | tee "${log_file}"
  local rc=${PIPESTATUS[0]}
  set -e

  if [ ! -s "${log_file}" ]; then
    printf 'Command completed without output.\n' >"${log_file}"
  fi

  if [ "${rc}" -eq 0 ]; then
    printf -v "${phase}_STATUS" "%s" "SUCCESS"
  else
    printf -v "${phase}_STATUS" "%s" "FAILED"
    OVERALL_STATUS="FAILED"
  fi
}

resolve_airflow_version() {
  python - <<'PY'
from pathlib import Path
import re
import sys

candidate_files = [
    Path("terraform/envs/pre/30-orchestration/terraform.tfvars"),
    Path("terraform/envs/pro/30-orchestration/terraform.tfvars"),
]

pattern = re.compile(r'image_version\s*=\s*"composer-\d+-airflow-([0-9.]+)-build\.\d+"')

for candidate in candidate_files:
    if not candidate.is_file():
        continue
    match = pattern.search(candidate.read_text())
    if match:
        print(match.group(1))
        sys.exit(0)

raise SystemExit("Unable to determine Airflow version from Terraform tfvars.")
PY
}

install_airflow_test_dependencies() {
  local airflow_version python_version constraint_url

  set +e
  airflow_version="$(resolve_airflow_version 2>&1)"
  local rc=$?
  set -e

  if [ "${rc}" -ne 0 ]; then
    printf '%s\n' "${airflow_version}" >"${AIRFLOW_INSTALL_LOG_FILE}"
    DAG_TEST_STATUS="FAILED"
    OVERALL_STATUS="FAILED"
    return
  fi

  python_version="$(python - <<'PY'
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}")
PY
)"
  constraint_url="https://raw.githubusercontent.com/apache/airflow/constraints-${airflow_version}/constraints-${python_version}.txt"

  printf 'AIRFLOW_VERSION=%s\nPYTHON_VERSION=%s\nCONSTRAINT_URL=%s\n' \
    "${airflow_version}" "${python_version}" "${constraint_url}" >"${AIRFLOW_TEST_VERSION_FILE}"

  mkdir -p "${AIRFLOW_TEST_HOME}"

  run_phase DAG_TEST "${AIRFLOW_INSTALL_LOG_FILE}" \
    bash -ceu "python -m pip install --no-cache-dir --quiet \
      \"apache-airflow==${airflow_version}\" \
      \"apache-airflow-providers-google\" \
      pytest \
      --constraint \"${constraint_url}\" && \
      AIRFLOW_HOME=\"${AIRFLOW_TEST_HOME}\" \
      AIRFLOW__CORE__LOAD_EXAMPLES=False \
      AIRFLOW__CORE__UNIT_TEST_MODE=True \
      pytest tests/dags -q"
}

if [ "${RELEVANT_CHANGES}" = "true" ]; then
  install_airflow_test_dependencies
else
  DAG_TEST_STATUS="SUCCESS"
  printf 'No changed DAG-related files detected under dags/, tests/dags/, or composer/requirements.txt for this PR.\n' >"${NOOP_LOG_FILE}"
fi

{
  printf '<!-- buildtrack-pr-validation:%s -->\n' "${COMMENT_SCOPE}"
  printf '## %s\n\n' "${COMMENT_TITLE}"
  printf 'Result: `%s`\n\n' "$(pr_result_label "${OVERALL_STATUS}")"
  printf -- '- Build: [Cloud Build log](%s)\n' "${BUILD_LOG_URL}"
  printf -- '- Trigger: `%s`\n' "${CB_TRIGGER_NAME}"
  if [ -n "${CB_SHORT_SHA:-}" ]; then
    printf -- '- Commit: `%s`\n' "${CB_SHORT_SHA}"
  fi
  printf -- '- Updated: `%s`\n' "${TIMESTAMP_UTC}"
  printf -- '- Relevant changes detected: `%s`\n' "${RELEVANT_CHANGES}"
  printf -- '- `pytest tests/dags -q`: `%s`\n\n' "${DAG_TEST_STATUS}"
} >"${COMMENT_BODY_FILE}"

if [ "${RELEVANT_CHANGES}" = "true" ]; then
  pr_append_details_block "${COMMENT_BODY_FILE}" "Airflow test dependency resolution" "${AIRFLOW_TEST_VERSION_FILE}" "text" 4000 "text"
  printf '\n' >>"${COMMENT_BODY_FILE}"
  pr_append_details_block "${COMMENT_BODY_FILE}" "Airflow install + DAG pytest output" "${AIRFLOW_INSTALL_LOG_FILE}" "text" 12000 "text"
else
  pr_append_details_block "${COMMENT_BODY_FILE}" "Scope evaluation" "${NOOP_LOG_FILE}" "text" 4000 "text"
fi

cat >"${RESULT_ENV_FILE}" <<EOF
$(printf 'COMMENT_SCOPE=%q\n' "${COMMENT_SCOPE}")
$(printf 'COMMENT_TITLE=%q\n' "${COMMENT_TITLE}")
$(printf 'COMMENT_BODY_FILE=%q\n' "${COMMENT_BODY_FILE}")
$(printf 'OVERALL_STATUS=%q\n' "${OVERALL_STATUS}")
$(printf 'BUILD_LOG_URL=%q\n' "${BUILD_LOG_URL}")
$(printf 'PR_NUMBER=%q\n' "${CB_PR_NUMBER}")
$(printf 'REPO_FULL_NAME=%q\n' "${CB_REPO_FULL_NAME}")
$(printf 'TRIGGER_NAME=%q\n' "${CB_TRIGGER_NAME}")
$(printf 'SHORT_SHA=%q\n' "${CB_SHORT_SHA:-}")
EOF

echo "DAG PR validation summary: relevant=${RELEVANT_CHANGES}, dag_pytest=${DAG_TEST_STATUS}, overall=${OVERALL_STATUS}"
