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
TARGET_FILE="${LOG_DIR}/target.json"
REQUEST_FILE="${LOG_DIR}/compile_request.json"
RESPONSE_FILE="${LOG_DIR}/compile_response.json"
SUMMARY_FILE="${LOG_DIR}/compile_summary.log"
STDERR_FILE="${LOG_DIR}/compile_stderr.log"

./cloudbuild/scripts/fetch_github_pr_files.sh "${CHANGED_FILES_FILE}"

while IFS= read -r changed_file; do
  case "${changed_file}" in
    definitions/*|includes/*|workflow_settings.yaml|package.json|package-lock.json)
      RELEVANT_CHANGES="true"
      break
      ;;
  esac
done <"${CHANGED_FILES_FILE}"

resolve_dataform_target() {
  python3 - <<'PY'
from pathlib import Path
import json
import os
import re
import sys

project_id = os.environ.get("CB_PROJECT_ID")
commit_sha = os.environ.get("CB_COMMIT_SHA")

if not project_id:
    raise SystemExit("CB_PROJECT_ID is required.")
if not commit_sha:
    raise SystemExit("CB_COMMIT_SHA is required.")

env_repo = os.environ.get("DATAFORM_REPOSITORY_NAME")
env_location = os.environ.get("DATAFORM_LOCATION")

candidates = [
    Path("terraform/envs/pre/30-orchestration/terraform.tfvars"),
    Path("terraform/envs/pro/30-orchestration/terraform.tfvars"),
]

patterns = {
    "project_id": re.compile(r'^\s*project_id\s*=\s*"([^"]+)"', re.M),
    "region": re.compile(r'^\s*region\s*=\s*"([^"]+)"', re.M),
    "repository_name": re.compile(r'^\s*repository_name\s*=\s*"([^"]+)"', re.M),
    "assertionSchema": re.compile(r'^\s*assertion_schema\s*=\s*"([^"]+)"', re.M),
    "defaultDatabase": re.compile(r'^\s*default_database\s*=\s*"([^"]+)"', re.M),
    "defaultLocation": re.compile(r'^\s*default_location\s*=\s*"([^"]+)"', re.M),
    "defaultSchema": re.compile(r'^\s*default_schema\s*=\s*"([^"]+)"', re.M),
}

target = None
for candidate in candidates:
    if not candidate.is_file():
        continue
    text = candidate.read_text()
    project_match = patterns["project_id"].search(text)
    if not project_match or project_match.group(1) != project_id:
        continue

    region_match = patterns["region"].search(text)
    repo_match = patterns["repository_name"].search(text)
    if not region_match:
        raise SystemExit(f"Unable to determine region from {candidate}.")
    if not repo_match and not env_repo:
        raise SystemExit(f"Unable to determine Dataform repository name from {candidate}.")

    code_compilation_config = {}
    for field_name in ("assertionSchema", "defaultDatabase", "defaultLocation", "defaultSchema"):
        field_match = patterns[field_name].search(text)
        if field_match:
            code_compilation_config[field_name] = field_match.group(1)

    target = {
        "project_id": project_id,
        "location": env_location or region_match.group(1),
        "repository_name": env_repo or repo_match.group(1),
        "payload": {
            "gitCommitish": commit_sha,
        },
    }
    if code_compilation_config:
        target["payload"]["codeCompilationConfig"] = code_compilation_config
    break

if target is None:
    raise SystemExit(f"Unable to resolve Dataform target for project {project_id}.")

target["parent"] = (
    f"projects/{target['project_id']}/locations/{target['location']}"
    f"/repositories/{target['repository_name']}"
)
print(json.dumps(target))
PY
}

if [ "${RELEVANT_CHANGES}" = "true" ]; then
  printf '{\"note\":\"Target not resolved.\"}\n' >"${TARGET_FILE}"
  printf '{\"note\":\"No compilation request was created.\"}\n' >"${REQUEST_FILE}"
  printf '{\"note\":\"No compilation response was received.\"}\n' >"${RESPONSE_FILE}"
  printf 'Compilation step did not produce a summary.\n' >"${LOG_DIR}/compile.log"
  : >"${STDERR_FILE}"

  set +e
  resolve_dataform_target >"${TARGET_FILE}" 2>"${STDERR_FILE}"
  rc=$?
  set -e

  if [ "${rc}" -eq 0 ]; then
    jq -c '.payload' "${TARGET_FILE}" >"${REQUEST_FILE}"

    set +e
    ACCESS_TOKEN="$(gcloud auth print-access-token 2>>"${STDERR_FILE}")"
    rc=$?
    set -e

    if [ "${rc}" -eq 0 ]; then
      DATAFORM_PARENT="$(jq -r '.parent' "${TARGET_FILE}")"

      set +e
      HTTP_STATUS="$(curl -sS \
        -o "${RESPONSE_FILE}" \
        -w '%{http_code}' \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        -H "Content-Type: application/json" \
        -X POST \
        "https://dataform.googleapis.com/v1/${DATAFORM_PARENT}/compilationResults" \
        --data "@${REQUEST_FILE}" \
        2>>"${STDERR_FILE}")"
      rc=$?
      set -e

      {
        printf 'Repository: %s\n' "$(jq -r '.repository_name' "${TARGET_FILE}")"
        printf 'Location: %s\n' "$(jq -r '.location' "${TARGET_FILE}")"
        printf 'Git commitish: %s\n' "$(jq -r '.payload.gitCommitish' "${TARGET_FILE}")"
        printf 'HTTP status: %s\n' "${HTTP_STATUS:-unknown}"
      } >"${LOG_DIR}/compile.log"

      if [ "${rc}" -eq 0 ] && [[ "${HTTP_STATUS}" =~ ^2 ]]; then
        if jq -e '.compilationErrors? | length > 0' "${RESPONSE_FILE}" >/dev/null 2>&1; then
          COMPILE_STATUS="FAILED"
          OVERALL_STATUS="FAILED"
        else
          COMPILE_STATUS="SUCCESS"
        fi
      else
        COMPILE_STATUS="FAILED"
        OVERALL_STATUS="FAILED"
      fi
    else
      COMPILE_STATUS="FAILED"
      OVERALL_STATUS="FAILED"
    fi
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
  printf -- '- `compilationResults.create`: `%s`\n\n' "${COMPILE_STATUS}"
} >"${COMMENT_BODY_FILE}"

if [ "${RELEVANT_CHANGES}" = "true" ]; then
  {
    printf 'Request target\n'
    jq '.' "${TARGET_FILE}"
  } >"${SUMMARY_FILE}"

  pr_append_details_block "${COMMENT_BODY_FILE}" "Dataform API target" "${SUMMARY_FILE}" "json" 8000 "text"
  printf '\n' >>"${COMMENT_BODY_FILE}"
  pr_append_details_block "${COMMENT_BODY_FILE}" "Compilation request" "${REQUEST_FILE}" "json" 8000 "text"
  printf '\n' >>"${COMMENT_BODY_FILE}"
  pr_append_details_block "${COMMENT_BODY_FILE}" "Compilation response" "${RESPONSE_FILE}" "json" 12000 "text"
  printf '\n' >>"${COMMENT_BODY_FILE}"
  pr_append_details_block "${COMMENT_BODY_FILE}" "Compilation summary" "${LOG_DIR}/compile.log" "text" 4000 "text"
  printf '\n' >>"${COMMENT_BODY_FILE}"
  pr_append_details_block "${COMMENT_BODY_FILE}" "API stderr" "${STDERR_FILE}" "text" 8000 "text"
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
