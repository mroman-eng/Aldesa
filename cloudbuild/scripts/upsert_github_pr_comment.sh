#!/usr/bin/env bash
set -euo pipefail

RESULT_DIR="${PR_RESULT_DIR:-/workspace/.cloudbuild/pr-validation}"
RESULT_ENV_FILE="${RESULT_DIR}/result.env"
MAX_COMMENT_BYTES=60000

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

find_existing_comment() {
  local comments_file="$1"
  local marker="$2"
  jq -c '
    map(select(.body | contains("'"${marker}"'")))
    | sort_by(.updated_at)
    | last // empty
  ' "${comments_file}"
}

if [ -z "${COMMENT_SCOPE:-}" ] || [ -z "${COMMENT_BODY_FILE:-}" ]; then
  echo "COMMENT_SCOPE and COMMENT_BODY_FILE are required in result.env." >&2
  exit 1
fi

if [ ! -f "${COMMENT_BODY_FILE}" ]; then
  echo "Comment body file not found: ${COMMENT_BODY_FILE}" >&2
  exit 1
fi

if [ "$(wc -c <"${COMMENT_BODY_FILE}" | tr -d ' ')" -gt "${MAX_COMMENT_BYTES}" ]; then
  echo "Comment body exceeds GitHub size limits: ${COMMENT_BODY_FILE}" >&2
  exit 1
fi

existing_comments_file="$(mktemp)"
payload_file="$(mktemp)"
verify_file="$(mktemp)"
response_file="$(mktemp)"
trap 'rm -f "${existing_comments_file}" "${payload_file}" "${verify_file}" "${response_file}"' EXIT

for attempt in 1 2 3; do
  comment_marker="<!-- buildtrack-pr-validation:${COMMENT_SCOPE} -->"

  api_request GET "${COMMENTS_API_URL}?per_page=100" >"${existing_comments_file}"
  existing_comment="$(find_existing_comment "${existing_comments_file}" "${comment_marker}")"
  jq -n --rawfile body "${COMMENT_BODY_FILE}" '{body: $body}' >"${payload_file}"

  if [ -n "${existing_comment}" ]; then
    comment_id="$(jq -r '.id' <<<"${existing_comment}")"
    api_request PATCH "https://api.github.com/repos/${REPO_FULL_NAME}/issues/comments/${comment_id}" "${payload_file}" >"${response_file}"
  else
    api_request POST "${COMMENTS_API_URL}" "${payload_file}" >"${response_file}"
    comment_id="$(jq -r '.id' "${response_file}")"
  fi

  api_request GET "https://api.github.com/repos/${REPO_FULL_NAME}/issues/comments/${comment_id}" >"${verify_file}"
  if jq -e --arg marker "${comment_marker}" '.body | contains($marker)' "${verify_file}" >/dev/null; then
    echo "GitHub PR comment updated for ${COMMENT_SCOPE}"
    exit 0
  fi

  echo "GitHub PR comment verification failed for ${COMMENT_SCOPE}; retrying." >&2
  sleep "${attempt}"
done

echo "Failed to upsert the GitHub PR comment after multiple attempts." >&2
exit 1
