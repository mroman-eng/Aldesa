#!/usr/bin/env bash
set -euo pipefail

RESULT_DIR="${PR_RESULT_DIR:-/workspace/.cloudbuild/pr-validation}"
RESULT_ENV_FILE="${RESULT_DIR}/result.env"

if [ ! -f "${RESULT_ENV_FILE}" ]; then
  echo "Result file not found: ${RESULT_ENV_FILE}" >&2
  exit 1
fi

source "${RESULT_ENV_FILE}"

if [ "${OVERALL_STATUS}" != "SUCCESS" ]; then
  echo "PR validation failed for ${COMMENT_SCOPE:-unknown}."
  exit 1
fi

echo "PR validation succeeded for ${COMMENT_SCOPE:-unknown}."
