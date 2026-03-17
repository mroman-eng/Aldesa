#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pr_comment_lib.sh"

RESULT_DIR="${PR_RESULT_DIR:-/workspace/.cloudbuild/pr-validation}"
RESULT_ENV_FILE="${RESULT_DIR}/result.env"
COMMENT_BODY_FILE="${RESULT_DIR}/comment.md"
CHANGED_FILES_FILE="${RESULT_DIR}/changed_files.txt"

mkdir -p "${RESULT_DIR}"

declare -A COMPONENT_TARGET_BY_DIR=(
  ["10-foundation"]="foundation"
  ["20-storage-bq"]="storage_bq"
  ["30-orchestration"]="orchestration"
  ["40-governance"]="governance"
  ["50-bi"]="bi"
  ["60-cicd"]="cicd"
)

ALL_COMPONENT_DIRS=(
  "10-foundation"
  "20-storage-bq"
  "30-orchestration"
  "40-governance"
  "50-bi"
  "60-cicd"
)

BUILD_LOG_URL="$(pr_build_log_url)"
TIMESTAMP_UTC="$(pr_now_utc)"
COMMENT_SCOPE="terraform"
COMMENT_TITLE="Terraform PR Validation"
OVERALL_STATUS="SUCCESS"
SELECT_ALL_COMPONENTS="false"
declare -A SELECTED_COMPONENTS=()

./cloudbuild/scripts/fetch_github_pr_files.sh "${CHANGED_FILES_FILE}"

while IFS= read -r changed_file; do
  case "${changed_file}" in
    terraform/modules/*)
      SELECT_ALL_COMPONENTS="true"
      ;;
    terraform/components/10-foundation/*|terraform/envs/dev/10-foundation/*)
      SELECTED_COMPONENTS["10-foundation"]=1
      ;;
    terraform/components/20-storage-bq/*|terraform/envs/dev/20-storage-bq/*)
      SELECTED_COMPONENTS["20-storage-bq"]=1
      ;;
    terraform/components/30-orchestration/*|terraform/envs/dev/30-orchestration/*|functions/*|composer/requirements.txt)
      SELECTED_COMPONENTS["30-orchestration"]=1
      ;;
    terraform/components/40-governance/*|terraform/envs/dev/40-governance/*)
      SELECTED_COMPONENTS["40-governance"]=1
      ;;
    terraform/components/50-bi/*|terraform/envs/dev/50-bi/*)
      SELECTED_COMPONENTS["50-bi"]=1
      ;;
    terraform/components/60-cicd/*|terraform/envs/dev/60-cicd/*|cloudbuild/*)
      SELECTED_COMPONENTS["60-cicd"]=1
      ;;
  esac
done <"${CHANGED_FILES_FILE}"

if [ "${SELECT_ALL_COMPONENTS}" = "true" ]; then
  for component_dir in "${ALL_COMPONENT_DIRS[@]}"; do
    SELECTED_COMPONENTS["${component_dir}"]=1
  done
fi

if [ "${#SELECTED_COMPONENTS[@]}" -eq 0 ]; then
  SELECTED_COMPONENT_DIRS=()
else
  mapfile -t SELECTED_COMPONENT_DIRS < <(printf '%s\n' "${!SELECTED_COMPONENTS[@]}" | sort)
fi

render_component() {
  local component_dir="$1"
  local component_target="${COMPONENT_TARGET_BY_DIR[${component_dir}]}"
  local component_result_dir="${RESULT_DIR}/${component_dir}"
  local env_dir="terraform/envs/dev/${component_dir}"
  local plan_render_file="${component_result_dir}/plan.txt"
  local log_dir="${component_result_dir}/logs"
  local section_file="${component_result_dir}/section.md"
  local fmt_status="SKIPPED"
  local init_status="SKIPPED"
  local validate_status="SKIPPED"
  local plan_status="SKIPPED"
  local component_status="SUCCESS"
  local payload_source=""
  local payload_label=""
  local payload_fence="text"
  local payload_mode="text"

  mkdir -p "${log_dir}"

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
      printf -v "${phase}_status" "%s" "SUCCESS"
    else
      printf -v "${phase}_status" "%s" "FAILED"
      component_status="FAILED"
      OVERALL_STATUS="FAILED"
    fi
  }

  run_phase fmt "${log_dir}/fmt.log" terraform fmt -check -recursive "terraform/components/${component_dir}" "${env_dir}"
  run_phase init "${log_dir}/init.log" terraform -chdir="${env_dir}" init -backend=false -reconfigure -input=false

  if [ "${init_status}" = "SUCCESS" ]; then
    run_phase validate "${log_dir}/validate.log" terraform -chdir="${env_dir}" validate
  else
    validate_status="SKIPPED"
    printf 'Skipped: terraform init failed.\n' >"${log_dir}/validate.log"
    component_status="FAILED"
    OVERALL_STATUS="FAILED"
  fi

  if [ "${init_status}" = "SUCCESS" ] && [ "${validate_status}" = "SUCCESS" ]; then
    run_phase plan "${log_dir}/plan.log" make "${component_target}_plan" ENV=dev CI=true
  else
    plan_status="SKIPPED"
    printf 'Skipped: terraform init/validate did not succeed.\n' >"${log_dir}/plan.log"
    component_status="FAILED"
    OVERALL_STATUS="FAILED"
  fi

  if [ "${plan_status}" = "SUCCESS" ]; then
    mapfile -t plan_files < <(find "${env_dir}" -maxdepth 1 -type f -name '*.tfplan' | sort)
    if [ "${#plan_files[@]}" -eq 1 ]; then
      plan_file_name="$(basename "${plan_files[0]}")"
      if ! terraform -chdir="${env_dir}" show -no-color "${plan_file_name}" >"${plan_render_file}"; then
        plan_status="FAILED"
        component_status="FAILED"
        OVERALL_STATUS="FAILED"
        echo "Failed to render Terraform plan file ${plan_files[0]}." | tee -a "${log_dir}/plan.log"
        rm -f "${plan_render_file}"
      fi
    else
      plan_status="FAILED"
      component_status="FAILED"
      OVERALL_STATUS="FAILED"
      {
        echo "Expected exactly one Terraform plan file in ${env_dir}."
        echo "Found ${#plan_files[@]} plan files."
        printf '%s\n' "${plan_files[@]}"
      } | tee -a "${log_dir}/plan.log"
      rm -f "${plan_render_file}"
    fi
  fi

  if [ "${plan_status}" = "SUCCESS" ] && [ -f "${plan_render_file}" ]; then
    payload_source="${plan_render_file}"
    payload_label="Terraform plan"
    payload_fence="diff"
    payload_mode="terraform_plan"
  elif [ "${plan_status}" = "FAILED" ]; then
    payload_source="${log_dir}/plan.log"
    payload_label="Plan output"
    payload_mode="terraform_plan"
  elif [ "${validate_status}" = "FAILED" ]; then
    payload_source="${log_dir}/validate.log"
    payload_label="Validate output"
  elif [ "${init_status}" = "FAILED" ]; then
    payload_source="${log_dir}/init.log"
    payload_label="Init output"
  else
    payload_source="${log_dir}/fmt.log"
    payload_label="Fmt output"
  fi

  {
    printf '### `%s`\n\n' "${component_dir}"
    printf 'Result: `%s`\n\n' "$(pr_result_label "${component_status}")"
    printf -- '- `fmt`: `%s`\n' "${fmt_status}"
    printf -- '- `init`: `%s`\n' "${init_status}"
    printf -- '- `validate`: `%s`\n' "${validate_status}"
    printf -- '- `plan`: `%s`\n\n' "${plan_status}"
  } >"${section_file}"
  pr_append_details_block "${section_file}" "${payload_label}" "${payload_source}" "${payload_fence}" 16000 "${payload_mode}"
  printf '\n' >>"${section_file}"
}

if [ "${#SELECTED_COMPONENT_DIRS[@]}" -eq 0 ]; then
  noop_log_file="${RESULT_DIR}/scope.log"
  printf 'No relevant Terraform changes detected for DEV.\n' >"${noop_log_file}"
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
    printf -- '- Relevant changes detected: `false`\n\n'
    printf 'Successful: no relevant Terraform changes detected for DEV.\n'
  } >"${COMMENT_BODY_FILE}"
  printf '\n' >>"${COMMENT_BODY_FILE}"
  pr_append_details_block "${COMMENT_BODY_FILE}" "Scope evaluation" "${noop_log_file}" "text" 4000 "text"
else
  for component_dir in "${SELECTED_COMPONENT_DIRS[@]}"; do
    render_component "${component_dir}"
  done

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
    printf -- '- Relevant changes detected: `true`\n'
    printf -- '- Components selected: `%s`\n\n' "$(IFS=', '; echo "${SELECTED_COMPONENT_DIRS[*]}")"
  } >"${COMMENT_BODY_FILE}"

  for component_dir in "${SELECTED_COMPONENT_DIRS[@]}"; do
    cat "${RESULT_DIR}/${component_dir}/section.md" >>"${COMMENT_BODY_FILE}"
  done
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

if [ "${#SELECTED_COMPONENT_DIRS[@]}" -eq 0 ]; then
  echo "Terraform PR validation summary: no relevant changes detected."
else
  echo "Terraform PR validation summary: components=${SELECTED_COMPONENT_DIRS[*]}, overall=${OVERALL_STATUS}"
fi
