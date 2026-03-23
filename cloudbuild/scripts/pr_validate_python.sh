#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pr_comment_lib.sh"

RESULT_DIR="${PR_RESULT_DIR:-/workspace/.cloudbuild/pr-validation}"
RESULT_ENV_FILE="${RESULT_DIR}/result.env"
COMMENT_BODY_FILE="${RESULT_DIR}/comment.md"
CHANGED_FILES_FILE="${RESULT_DIR}/changed_files.txt"
LOG_DIR="${RESULT_DIR}/logs"
SELECTED_FILES_FILE="${RESULT_DIR}/selected_python_files.txt"

mkdir -p "${LOG_DIR}"

BUILD_LOG_URL="$(pr_build_log_url)"
TIMESTAMP_UTC="$(pr_now_utc)"
COMMENT_SCOPE="python"
COMMENT_TITLE="Python PR Validation"
OVERALL_STATUS="SUCCESS"
COMPILE_STATUS="SKIPPED"
RUFF_STATUS="SKIPPED"
RELEVANT_CHANGES="false"
NOOP_LOG_FILE="${LOG_DIR}/scope.log"
declare -a PYTHON_FILES=()

./cloudbuild/scripts/fetch_github_pr_files.sh "${CHANGED_FILES_FILE}"

while IFS= read -r changed_file; do
  case "${changed_file}" in
    functions/*)
      if [[ "${changed_file}" == *.py ]] && [ -f "${changed_file}" ]; then
        printf '%s\n' "${changed_file}" >>"${SELECTED_FILES_FILE}"
      fi
      ;;
  esac
done <"${CHANGED_FILES_FILE}"

if [ -f "${SELECTED_FILES_FILE}" ] && [ -s "${SELECTED_FILES_FILE}" ]; then
  sort -u "${SELECTED_FILES_FILE}" -o "${SELECTED_FILES_FILE}"
  mapfile -t PYTHON_FILES <"${SELECTED_FILES_FILE}"
  RELEVANT_CHANGES="true"
fi

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

if [ "${RELEVANT_CHANGES}" = "true" ]; then
  run_phase COMPILE "${LOG_DIR}/compile.log" python -m py_compile "${PYTHON_FILES[@]}"
  run_phase RUFF "${LOG_DIR}/ruff.log" ruff check --select F,E9 "${PYTHON_FILES[@]}"
else
  COMPILE_STATUS="SUCCESS"
  RUFF_STATUS="SUCCESS"
  printf 'No changed Python source files detected under functions/ for this PR.\n' >"${NOOP_LOG_FILE}"
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
  printf -- '- Python files selected: `%s`\n' "${#PYTHON_FILES[@]}"
  printf -- '- `py_compile`: `%s`\n' "${COMPILE_STATUS}"
  printf -- '- `ruff`: `%s`\n\n' "${RUFF_STATUS}"
} >"${COMMENT_BODY_FILE}"

if [ "${RELEVANT_CHANGES}" = "true" ]; then
  pr_append_details_block "${COMMENT_BODY_FILE}" "Python files evaluated" "${SELECTED_FILES_FILE}" "text" 4000 "text"
  printf '\n' >>"${COMMENT_BODY_FILE}"
  pr_append_details_block "${COMMENT_BODY_FILE}" "Python compile output" "${LOG_DIR}/compile.log" "text" 12000 "text"
  printf '\n' >>"${COMMENT_BODY_FILE}"
  pr_append_details_block "${COMMENT_BODY_FILE}" "Ruff output" "${LOG_DIR}/ruff.log" "text" 12000 "text"
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

echo "Python PR validation summary: relevant=${RELEVANT_CHANGES}, compile=${COMPILE_STATUS}, ruff=${RUFF_STATUS}, overall=${OVERALL_STATUS}"
