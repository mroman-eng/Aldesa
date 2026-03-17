#!/usr/bin/env bash
set -euo pipefail

RESULT_DIR="${PR_TF_RESULT_DIR:-/workspace/.cloudbuild/pr-tf}"
RESULT_ENV_FILE="${RESULT_DIR}/result.env"

if [ ! -f "${RESULT_ENV_FILE}" ]; then
  echo "Result file not found: ${RESULT_ENV_FILE}" >&2
  exit 1
fi

source "${RESULT_ENV_FILE}"

if [ "${OVERALL_STATUS}" != "SUCCESS" ]; then
  echo "Terraform PR validation failed for ${COMPONENT_DIR}."
  exit 1
fi

echo "Terraform PR validation succeeded for ${COMPONENT_DIR}."
