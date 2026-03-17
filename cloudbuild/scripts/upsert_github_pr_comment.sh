#!/usr/bin/env bash
set -euo pipefail

RESULT_DIR="${PR_TF_RESULT_DIR:-/workspace/.cloudbuild/pr-tf}"
RESULT_ENV_FILE="${RESULT_DIR}/result.env"
FULL_SECTION_FILE="${RESULT_DIR}/section.full.md"
TRUNCATED_SECTION_FILE="${RESULT_DIR}/section.truncated.md"
COMPACT_SECTION_FILE="${RESULT_DIR}/section.compact.md"
MAX_COMMENT_BYTES=60000
COMMENT_MARKER="<!-- buildtrack-tf-plan-comment -->"

if [ ! -f "${RESULT_ENV_FILE}" ]; then
  echo "Result file not found: ${RESULT_ENV_FILE}" >&2
  exit 1
fi

if [ -z "${GITHUB_PR_COMMENT_TOKEN:-}" ]; then
  echo "GITHUB_PR_COMMENT_TOKEN is not set." >&2
  exit 1
fi

source "${RESULT_ENV_FILE}"

if [ -z "${PR_NUMBER:-}" ] || [ -z "${REPO_FULL_NAME:-}" ]; then
  echo "PR metadata is incomplete. REPO_FULL_NAME='${REPO_FULL_NAME:-}' PR_NUMBER='${PR_NUMBER:-}'" >&2
  exit 1
fi

COMMENTS_API_URL="https://api.github.com/repos/${REPO_FULL_NAME}/issues/${PR_NUMBER}/comments"
SECTION_START="<!-- buildtrack-tf-plan-section:${COMPONENT_DIR} -->"
SECTION_END="<!-- /buildtrack-tf-plan-section:${COMPONENT_DIR} -->"

api_request() {
  local method="$1"
  local url="$2"
  local body_file="${3:-}"

  local -a curl_args=(
    curl
    -fsS
    -X "${method}"
    -H "Accept: application/vnd.github+json"
    -H "Authorization: Bearer ${GITHUB_PR_COMMENT_TOKEN}"
    -H "X-GitHub-Api-Version: 2022-11-28"
    "${url}"
  )

  if [ -n "${body_file}" ]; then
    curl_args+=(-H "Content-Type: application/json" --data-binary "@${body_file}")
  fi

  "${curl_args[@]}"
}

comment_header() {
  cat <<EOF
${COMMENT_MARKER}
## Terraform PR Validation

Managed by Cloud Build. Each Terraform component updates its own section in this comment.
EOF
}

strip_current_section() {
  local input_file="$1"
  local output_file="$2"
  awk -v start="${SECTION_START}" -v end="${SECTION_END}" '
    $0 == start { skip = 1; next }
    $0 == end { skip = 0; next }
    !skip { print }
  ' "${input_file}" >"${output_file}"
}

compact_payload_blocks() {
  local input_file="$1"
  local output_file="$2"
  awk '
    /<!-- buildtrack-tf-plan-payload:start -->/ {
      skip = 1
      print "_Payload omitted to keep the shared PR comment within GitHub size limits. See the build link in this section._"
      next
    }
    /<!-- buildtrack-tf-plan-payload:end -->/ {
      skip = 0
      next
    }
    !skip { print }
  ' "${input_file}" >"${output_file}"
}

build_body() {
  local base_file="$1"
  local section_file="$2"
  local output_file="$3"
  local last_char_bytes

  cp "${base_file}" "${output_file}"
  last_char_bytes="$(tail -c 1 "${output_file}" 2>/dev/null | wc -c | tr -d ' ')"
  if [ -s "${output_file}" ] && [ "${last_char_bytes}" -ne 0 ]; then
    printf '\n' >>"${output_file}"
  fi
  printf '\n' >>"${output_file}"
  cat "${section_file}" >>"${output_file}"
  printf '\n' >>"${output_file}"
}

body_size() {
  wc -c <"$1"
}

find_existing_comment() {
  local comments_file="$1"
  jq -c '
    map(select(.body | contains("'"${COMMENT_MARKER}"'")))
    | sort_by(.updated_at)
    | last // empty
  ' "${comments_file}"
}

existing_comments_file="$(mktemp)"
existing_body_file="$(mktemp)"
base_body_file="$(mktemp)"
compact_base_body_file="$(mktemp)"
candidate_body_file="$(mktemp)"
payload_file="$(mktemp)"
verify_file="$(mktemp)"
response_file="$(mktemp)"
trap 'rm -f "${existing_comments_file}" "${existing_body_file}" "${base_body_file}" "${compact_base_body_file}" "${candidate_body_file}" "${payload_file}" "${verify_file}" "${response_file}"' EXIT

upsert_once() {
  local existing_comment
  local selected_section_file
  local comment_id

  api_request GET "${COMMENTS_API_URL}?per_page=100" >"${existing_comments_file}"
  existing_comment="$(find_existing_comment "${existing_comments_file}")"

  if [ -n "${existing_comment}" ]; then
    jq -r '.body' <<<"${existing_comment}" >"${existing_body_file}"
  else
    comment_header >"${existing_body_file}"
  fi

  strip_current_section "${existing_body_file}" "${base_body_file}"
  compact_payload_blocks "${base_body_file}" "${compact_base_body_file}"

  selected_section_file="${FULL_SECTION_FILE}"
  build_body "${base_body_file}" "${selected_section_file}" "${candidate_body_file}"

  if [ "$(body_size "${candidate_body_file}")" -gt "${MAX_COMMENT_BYTES}" ]; then
    selected_section_file="${FULL_SECTION_FILE}"
    build_body "${compact_base_body_file}" "${selected_section_file}" "${candidate_body_file}"
  fi

  if [ "$(body_size "${candidate_body_file}")" -gt "${MAX_COMMENT_BYTES}" ]; then
    selected_section_file="${TRUNCATED_SECTION_FILE}"
    build_body "${compact_base_body_file}" "${selected_section_file}" "${candidate_body_file}"
  fi

  if [ "$(body_size "${candidate_body_file}")" -gt "${MAX_COMMENT_BYTES}" ]; then
    selected_section_file="${COMPACT_SECTION_FILE}"
    build_body "${compact_base_body_file}" "${selected_section_file}" "${candidate_body_file}"
  fi

  if [ "$(body_size "${candidate_body_file}")" -gt "${MAX_COMMENT_BYTES}" ]; then
    echo "Comment body still exceeds GitHub limits after compaction." >&2
    return 1
  fi

  jq -n --rawfile body "${candidate_body_file}" '{body: $body}' >"${payload_file}"

  if [ -n "${existing_comment}" ]; then
    comment_id="$(jq -r '.id' <<<"${existing_comment}")"
    api_request PATCH "https://api.github.com/repos/${REPO_FULL_NAME}/issues/comments/${comment_id}" "${payload_file}" >"${response_file}"
  else
    api_request POST "${COMMENTS_API_URL}" "${payload_file}" >"${response_file}"
    comment_id="$(jq -r '.id' "${response_file}")"
  fi

  api_request GET "https://api.github.com/repos/${REPO_FULL_NAME}/issues/comments/${comment_id}" >"${verify_file}"
  if ! jq -e --arg marker "${SECTION_START}" '.body | contains($marker)' "${verify_file}" >/dev/null; then
    echo "GitHub PR comment verification failed for ${COMPONENT_DIR}; retrying." >&2
    return 1
  fi

  echo "GitHub PR comment updated for ${COMPONENT_DIR} using $(basename "${selected_section_file}")"
  return 0
}

for attempt in 1 2 3; do
  if upsert_once; then
    exit 0
  fi
  sleep "${attempt}"
done

echo "Failed to upsert the GitHub PR comment after multiple attempts." >&2
exit 1
