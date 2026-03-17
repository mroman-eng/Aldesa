#!/usr/bin/env bash
set -euo pipefail

RESULT_DIR="${PR_TF_RESULT_DIR:-/workspace/.cloudbuild/pr-tf}"
RESULT_ENV_FILE="${RESULT_DIR}/result.env"
FULL_SECTION_FILE="${RESULT_DIR}/section.full.md"
TRUNCATED_SECTION_FILE="${RESULT_DIR}/section.truncated.md"
COMPACT_SECTION_FILE="${RESULT_DIR}/section.compact.md"
PLAN_RENDER_FILE="${RESULT_DIR}/plan.txt"
SANITIZED_PAYLOAD_FILE="${RESULT_DIR}/payload.sanitized.txt"

if [ ! -f "${RESULT_ENV_FILE}" ]; then
  echo "Result file not found: ${RESULT_ENV_FILE}" >&2
  exit 1
fi

source "${RESULT_ENV_FILE}"

component_title="\`${COMPONENT_DIR}\`"
component_marker_start="<!-- buildtrack-tf-plan-section:${COMPONENT_DIR} -->"
component_marker_end="<!-- /buildtrack-tf-plan-section:${COMPONENT_DIR} -->"
payload_marker_start="<!-- buildtrack-tf-plan-payload:start -->"
payload_marker_end="<!-- buildtrack-tf-plan-payload:end -->"
timestamp_utc="$(date -u +"%Y-%m-%d %H:%M:%SZ")"

if [ "${PLAN_STATUS}" = "SUCCESS" ] && [ -f "${PLAN_RENDER_FILE}" ]; then
  payload_source="${PLAN_RENDER_FILE}"
  payload_label="Terraform plan"
  payload_fence="diff"
elif [ -f "${RESULT_DIR}/logs/PLAN.log" ]; then
  payload_source="${RESULT_DIR}/logs/PLAN.log"
  payload_label="Plan output"
  payload_fence="text"
elif [ -f "${RESULT_DIR}/logs/VALIDATE.log" ] && [ "${VALIDATE_STATUS}" = "FAILED" ]; then
  payload_source="${RESULT_DIR}/logs/VALIDATE.log"
  payload_label="Validate output"
  payload_fence="text"
elif [ -f "${RESULT_DIR}/logs/INIT.log" ] && [ "${INIT_STATUS}" = "FAILED" ]; then
  payload_source="${RESULT_DIR}/logs/INIT.log"
  payload_label="Init output"
  payload_fence="text"
else
  payload_source="${RESULT_DIR}/logs/FMT.log"
  payload_label="Fmt output"
  payload_fence="text"
fi

sanitize_payload() {
  local source_file="$1"
  local destination_file="$2"
  local stripped_file

  stripped_file="$(mktemp)"

  sed -E $'s/\x1B\\[[0-9;?]*[ -/]*[@-~]//g' "${source_file}" >"${stripped_file}"

  if [[ "${payload_source}" == "${PLAN_RENDER_FILE}" || "${payload_source}" == */PLAN.log ]] && grep -Eq '^Terraform (will perform the following actions:|planned the following actions, but then encountered a problem:)$' "${stripped_file}"; then
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

sanitize_payload "${payload_source}" "${SANITIZED_PAYLOAD_FILE}"

write_section() {
  local destination="$1"
  local payload_mode="$2"
  local payload_limit="$3"

  {
    printf '%s\n' "${component_marker_start}"
    printf '### %s\n\n' "${component_title}"
    printf 'Status: `%s`\n\n' "${OVERALL_STATUS}"
    printf -- '- `fmt`: `%s`\n' "${FMT_STATUS}"
    printf -- '- `init`: `%s`\n' "${INIT_STATUS}"
    printf -- '- `validate`: `%s`\n' "${VALIDATE_STATUS}"
    printf -- '- `plan`: `%s`\n' "${PLAN_STATUS}"
    printf -- '- Build: [Cloud Build log](%s)\n' "${BUILD_LOG_URL}"
    if [ -n "${TRIGGER_NAME:-}" ]; then
      printf -- '- Trigger: `%s`\n' "${TRIGGER_NAME}"
    fi
    if [ -n "${SHORT_SHA:-}" ]; then
      printf -- '- Commit: `%s`\n' "${SHORT_SHA}"
    fi
    printf -- '- Updated: `%s`\n\n' "${timestamp_utc}"

    case "${payload_mode}" in
      full)
        printf '%s\n' "${payload_marker_start}"
        printf '<details>\n'
        printf '<summary>%s</summary>\n\n' "${payload_label}"
        printf '```%s\n' "${payload_fence}"
        cat "${SANITIZED_PAYLOAD_FILE}"
        printf '\n```\n\n'
        printf '</details>\n'
        printf '%s\n' "${payload_marker_end}"
        ;;
      truncated)
        printf '%s\n' "${payload_marker_start}"
        printf '<details>\n'
        printf '<summary>%s (truncated)</summary>\n\n' "${payload_label}"
        printf '```%s\n' "${payload_fence}"
        head -c "${payload_limit}" "${SANITIZED_PAYLOAD_FILE}"
        printf '\n...\n```\n\n'
        printf '</details>\n'
        printf '%s\n\n' "${payload_marker_end}"
        printf '_Output truncated to keep the shared PR comment readable. See the build log for the full details._\n'
        ;;
      compact)
        printf '_Payload omitted to keep the shared PR comment within GitHub size limits. See the build log for the full details._\n'
        ;;
      *)
        echo "Unknown payload mode: ${payload_mode}" >&2
        exit 1
        ;;
    esac

    printf '\n%s\n' "${component_marker_end}"
  } >"${destination}"
}

write_section "${FULL_SECTION_FILE}" full 0
write_section "${TRUNCATED_SECTION_FILE}" truncated 12000
write_section "${COMPACT_SECTION_FILE}" compact 0
