#!/usr/bin/env bash
set -euo pipefail

OUTPUT_FILE="${1:?output file is required}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

if [ -n "${PR_CHANGED_FILES_FILE:-}" ]; then
  awk 'NF { print }' "${PR_CHANGED_FILES_FILE}" | sort -u >"${OUTPUT_FILE}"
  exit 0
fi

if [ -z "${GITHUB_PR_COMMENT_TOKEN:-}" ]; then
  echo "GITHUB_PR_COMMENT_TOKEN is required to fetch PR files." >&2
  exit 1
fi

if [ -z "${CB_REPO_FULL_NAME:-}" ] || [ -z "${CB_PR_NUMBER:-}" ]; then
  echo "CB_REPO_FULL_NAME and CB_PR_NUMBER are required to fetch PR files." >&2
  exit 1
fi

page=1
>"${TMP_DIR}/files.txt"

while true; do
  response_file="${TMP_DIR}/page-${page}.json"
  curl -fsS \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${GITHUB_PR_COMMENT_TOKEN}" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/${CB_REPO_FULL_NAME}/pulls/${CB_PR_NUMBER}/files?per_page=100&page=${page}" \
    >"${response_file}"

  if [ "$(jq 'length' "${response_file}")" -eq 0 ]; then
    break
  fi

  jq -r '.[] | .filename, (.previous_filename // empty)' "${response_file}" >>"${TMP_DIR}/files.txt"
  page=$((page + 1))
done

awk 'NF { print }' "${TMP_DIR}/files.txt" | sort -u >"${OUTPUT_FILE}"
