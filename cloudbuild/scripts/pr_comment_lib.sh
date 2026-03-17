#!/usr/bin/env bash

pr_build_log_url() {
  local location="${CB_LOCATION:-global}"
  printf 'https://console.cloud.google.com/cloud-build/builds;region=%s/%s?project=%s' \
    "${location}" \
    "${CB_BUILD_ID}" \
    "${CB_PROJECT_ID}"
}

pr_now_utc() {
  date -u +"%Y-%m-%d %H:%M:%SZ"
}

pr_result_label() {
  case "$1" in
    SUCCESS) printf 'Successful' ;;
    FAILED) printf 'Failed' ;;
    SKIPPED) printf 'Skipped' ;;
    *) printf '%s' "$1" ;;
  esac
}

pr_sanitize_output() {
  local source_file="$1"
  local destination_file="$2"
  local mode="${3:-text}"
  local stripped_file

  stripped_file="$(mktemp)"

  sed -E $'s/\x1B\\[[0-9;?]*[ -/]*[@-~]//g' "${source_file}" >"${stripped_file}"

  if [ "${mode}" = "terraform_plan" ] && grep -Eq '^Terraform (will perform the following actions:|planned the following actions, but then encountered a problem:)$' "${stripped_file}"; then
    awk '
      found || /^Terraform will perform the following actions:$/ || /^Terraform planned the following actions, but then encountered a problem:$/ {
        found = 1
        print
      }
    ' "${stripped_file}" >"${destination_file}"
  else
    cp "${stripped_file}" "${destination_file}"
  fi

  rm -f "${stripped_file}"
}

pr_append_details_block() {
  local destination_file="$1"
  local summary_label="$2"
  local source_file="$3"
  local fence="${4:-text}"
  local max_chars="${5:-12000}"
  local mode="${6:-text}"
  local sanitized_file
  local size_bytes

  sanitized_file="$(mktemp)"
  pr_sanitize_output "${source_file}" "${sanitized_file}" "${mode}"
  size_bytes="$(wc -c <"${sanitized_file}" | tr -d ' ')"

  {
    printf '<details>\n'
    if [ "${size_bytes}" -gt "${max_chars}" ]; then
      printf '<summary>%s (truncated)</summary>\n\n' "${summary_label}"
      printf '```%s\n' "${fence}"
      head -c "${max_chars}" "${sanitized_file}"
      printf '\n...\n```\n\n'
      printf '_Output truncated to keep the PR comment readable. See the build log for the full details._\n'
    else
      printf '<summary>%s</summary>\n\n' "${summary_label}"
      printf '```%s\n' "${fence}"
      cat "${sanitized_file}"
      printf '\n```\n'
    fi
    printf '</details>\n'
  } >>"${destination_file}"

  rm -f "${sanitized_file}"
}
