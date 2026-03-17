#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pr_comment_lib.sh"

RESULT_DIR="${PR_RESULT_DIR:-/workspace/.cloudbuild/pr-validation}"
RESULT_ENV_FILE="${RESULT_DIR}/result.env"
COMMENT_BODY_FILE="${RESULT_DIR}/comment.md"
CHANGED_FILES_FILE="${RESULT_DIR}/changed_files.txt"
LOG_DIR="${RESULT_DIR}/logs"

mkdir -p "${LOG_DIR}"

BUILD_LOG_URL="$(pr_build_log_url)"
TIMESTAMP_UTC="$(pr_now_utc)"
COMMENT_SCOPE="dataform"
COMMENT_TITLE="Dataform PR Validation"
OVERALL_STATUS="SUCCESS"
COMPILE_STATUS="SKIPPED"
RELEVANT_CHANGES="false"
NOOP_LOG_FILE="${LOG_DIR}/scope.log"

./cloudbuild/scripts/fetch_github_pr_files.sh "${CHANGED_FILES_FILE}"

while IFS= read -r changed_file; do
  case "${changed_file}" in
    definitions/*|includes/*|tests/*|workflow_settings.yaml|package.json|package-lock.json)
      RELEVANT_CHANGES="true"
      break
      ;;
  esac
done <"${CHANGED_FILES_FILE}"

if [ "${RELEVANT_CHANGES}" = "true" ]; then
  set +e
  npx --yes --package=@dataform/cli@3.0.45 dataform compile . 2>&1 | tee "${LOG_DIR}/compile.log"
  rc=${PIPESTATUS[0]}
  set -e

  if [ ! -s "${LOG_DIR}/compile.log" ]; then
    printf 'Command completed without output.\n' >"${LOG_DIR}/compile.log"
  fi

  if [ "${rc}" -eq 0 ]; then
    COMPILE_STATUS="SUCCESS"
  else
    COMPILE_STATUS="FAILED"
    OVERALL_STATUS="FAILED"
  fi
else
  COMPILE_STATUS="SUCCESS"
  printf 'No relevant Dataform changes detected for this PR.\n' >"${NOOP_LOG_FILE}"
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
  printf -- '- `dataform compile`: `%s`\n\n' "${COMPILE_STATUS}"
} >"${COMMENT_BODY_FILE}"

if [ "${RELEVANT_CHANGES}" = "true" ]; then
  pr_append_details_block "${COMMENT_BODY_FILE}" "Dataform compile output" "${LOG_DIR}/compile.log" "text" 12000 "text"
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

echo "Dataform PR validation summary: relevant=${RELEVANT_CHANGES}, compile=${COMPILE_STATUS}, overall=${OVERALL_STATUS}"
