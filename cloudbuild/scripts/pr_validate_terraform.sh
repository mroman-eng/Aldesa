#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pr_comment_lib.sh"

RESULT_DIR="${PR_RESULT_DIR:-/workspace/.cloudbuild/pr-validation}"
RESULT_ENV_FILE="${RESULT_DIR}/result.env"
COMMENT_BODY_FILE="${RESULT_DIR}/comment.md"
CHANGED_FILES_FILE="${RESULT_DIR}/changed_files.txt"

mkdir -p "${RESULT_DIR}"

declare -A COMPONENT_TARGET_BY_DIR=(
  ["00-bootstrap"]="bootstrap"
  ["10-foundation"]="foundation"
  ["20-storage-bq"]="storage_bq"
  ["30-orchestration"]="orchestration"
  ["40-governance"]="governance"
  ["50-bi"]="bi"
  ["60-cicd"]="cicd"
)

BUILD_LOG_URL="$(pr_build_log_url)"
TIMESTAMP_UTC="$(pr_now_utc)"
OVERALL_STATUS="SUCCESS"
SELECT_ALL_COMPONENTS="false"
declare -A SELECTED_COMPONENTS=()

VALIDATION_MODE=""
VALIDATION_MODE_LABEL=""
COMMENT_SCOPE=""
COMMENT_TITLE=""
ALL_COMPONENT_DIRS=()

case "${CB_TRIGGER_NAME}" in
  cb-pr-dev-terraform)
    VALIDATION_MODE="dev"
    VALIDATION_MODE_LABEL="DEV"
    COMMENT_SCOPE="terraform-dev"
    COMMENT_TITLE="Terraform PR Validation (DEV)"
    ALL_COMPONENT_DIRS=("dev")
    ;;
  cb-pr-pre-terraform)
    VALIDATION_MODE="pre"
    VALIDATION_MODE_LABEL="PRE"
    COMMENT_SCOPE="terraform-pre"
    COMMENT_TITLE="Terraform PR Validation (PRE)"
    ALL_COMPONENT_DIRS=(
      "shared/00-bootstrap"
      "shared/10-foundation"
      "pre/20-storage-bq"
      "pre/30-orchestration"
      "pre/40-governance"
      "pre/50-bi"
      "pre/60-cicd"
    )
    ;;
  cb-pr-pro-terraform)
    VALIDATION_MODE="pro"
    VALIDATION_MODE_LABEL="PRO"
    COMMENT_SCOPE="terraform-pro"
    COMMENT_TITLE="Terraform PR Validation (PRO)"
    ALL_COMPONENT_DIRS=(
      "pro/00-bootstrap"
      "pro/10-foundation"
      "pro/20-storage-bq"
      "pro/30-orchestration"
      "pro/40-governance"
      "pro/50-bi"
      "pro/60-cicd"
    )
    ;;
  *)
    echo "Unsupported Terraform PR trigger: ${CB_TRIGGER_NAME}" >&2
    exit 1
    ;;
esac

select_all_components() {
  SELECT_ALL_COMPONENTS="true"
  for component_dir in "${ALL_COMPONENT_DIRS[@]}"; do
    SELECTED_COMPONENTS["${component_dir}"]=1
  done
}

run_phase() {
  local phase="$1"
  local log_file="$2"
  local status_var_name="$3"
  shift 3

  set +e
  "$@" 2>&1 | tee "${log_file}"
  local rc=${PIPESTATUS[0]}
  set -e

  if [ ! -s "${log_file}" ]; then
    printf 'Command completed without output.\n' >"${log_file}"
  fi

  if [ "${rc}" -eq 0 ]; then
    printf -v "${status_var_name}" "%s" "SUCCESS"
  else
    printf -v "${status_var_name}" "%s" "FAILED"
  fi

  return "${rc}"
}

plan_changes_label() {
  local env_dir="$1"
  local plan_file_name="$2"
  local plan_json_file="$3"

  terraform -chdir="${env_dir}" show -json "${plan_file_name}" >"${plan_json_file}"

  jq -r '
    if (
      ([.resource_changes[]?.change.actions[]? | select(. != "no-op")] | length) > 0 or
      ([.output_changes[]?.actions[]? | select(. != "no-op")] | length) > 0
    )
    then "YES"
    else "NO"
    end
  ' "${plan_json_file}"
}

render_standard_component() {
  local component_dir="$1"
  local component_name="${component_dir##*/}"
  local env_name="${component_dir%%/*}"
  local component_target="${COMPONENT_TARGET_BY_DIR[${component_name}]}"
  local component_result_dir="${RESULT_DIR}/${component_dir}"
  local env_dir="terraform/envs/${component_dir}"
  local plan_render_file="${component_result_dir}/plan.txt"
  local plan_json_file="${component_result_dir}/plan.json"
  local log_dir="${component_result_dir}/logs"
  local section_file="${component_result_dir}/section.md"
  local fmt_status="SKIPPED"
  local init_status="SKIPPED"
  local validate_status="SKIPPED"
  local plan_status="SKIPPED"
  local changes_status="SKIPPED"
  local component_status="SUCCESS"
  local payload_source=""
  local payload_label=""
  local payload_fence="text"
  local payload_mode="text"
  local plan_file_name=""

  mkdir -p "${log_dir}"

  if ! run_phase fmt "${log_dir}/fmt.log" fmt_status terraform fmt -check -recursive "terraform/components/${component_name}" "${env_dir}"; then
    component_status="FAILED"
    OVERALL_STATUS="FAILED"
  fi

  if ! run_phase init "${log_dir}/init.log" init_status terraform -chdir="${env_dir}" init -backend=false -reconfigure -input=false; then
    component_status="FAILED"
    OVERALL_STATUS="FAILED"
  fi

  if [ "${init_status}" = "SUCCESS" ]; then
    if ! run_phase validate "${log_dir}/validate.log" validate_status terraform -chdir="${env_dir}" validate; then
      component_status="FAILED"
      OVERALL_STATUS="FAILED"
    fi
  else
    validate_status="SKIPPED"
    printf 'Skipped: terraform init failed.\n' >"${log_dir}/validate.log"
    component_status="FAILED"
    OVERALL_STATUS="FAILED"
  fi

  if [ "${init_status}" = "SUCCESS" ] && [ "${validate_status}" = "SUCCESS" ]; then
    find "${env_dir}" -maxdepth 1 -type f -name '*.tfplan' -delete
    if ! run_phase plan "${log_dir}/plan.log" plan_status make "${component_target}_plan" ENV="${env_name}" CI=true; then
      component_status="FAILED"
      OVERALL_STATUS="FAILED"
    fi
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
        rm -f "${plan_json_file}"
      elif ! changes_status="$(plan_changes_label "${env_dir}" "${plan_file_name}" "${plan_json_file}")"; then
        plan_status="FAILED"
        component_status="FAILED"
        OVERALL_STATUS="FAILED"
        echo "Failed to evaluate Terraform plan changes for ${plan_files[0]}." | tee -a "${log_dir}/plan.log"
        rm -f "${plan_json_file}"
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
      rm -f "${plan_json_file}"
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
    printf -- '- `plan`: `%s`\n' "${plan_status}"
    printf -- '- `changes`: `%s`\n\n' "${changes_status}"
  } >"${section_file}"
  pr_append_details_block "${section_file}" "${payload_label}" "${payload_source}" "${payload_fence}" 16000 "${payload_mode}"
  printf '\n' >>"${section_file}"
}

render_dev_component() {
  local component_dir="dev"
  local component_result_dir="${RESULT_DIR}/${component_dir}"
  local env_dir="terraform/envs/dev"
  local plan_render_file="${component_result_dir}/plan.txt"
  local plan_json_file="${component_result_dir}/plan.json"
  local log_dir="${component_result_dir}/logs"
  local section_file="${component_result_dir}/section.md"
  local fmt_status="SKIPPED"
  local init_status="SKIPPED"
  local validate_status="SKIPPED"
  local plan_status="SKIPPED"
  local changes_status="SKIPPED"
  local component_status="SUCCESS"
  local payload_source=""
  local payload_label=""
  local payload_fence="text"
  local payload_mode="text"
  local plan_file_name=""

  mkdir -p "${log_dir}"

  if ! run_phase fmt "${log_dir}/fmt.log" fmt_status terraform fmt -check -recursive "terraform/components/20-storage-bq" "terraform/components/30-orchestration" "${env_dir}"; then
    component_status="FAILED"
    OVERALL_STATUS="FAILED"
  fi

  if ! run_phase init "${log_dir}/init.log" init_status terraform -chdir="${env_dir}" init -backend=false -reconfigure -input=false; then
    component_status="FAILED"
    OVERALL_STATUS="FAILED"
  fi

  if [ "${init_status}" = "SUCCESS" ]; then
    if ! run_phase validate "${log_dir}/validate.log" validate_status terraform -chdir="${env_dir}" validate; then
      component_status="FAILED"
      OVERALL_STATUS="FAILED"
    fi
  else
    validate_status="SKIPPED"
    printf 'Skipped: terraform init failed.\n' >"${log_dir}/validate.log"
    component_status="FAILED"
    OVERALL_STATUS="FAILED"
  fi

  if [ "${init_status}" = "SUCCESS" ] && [ "${validate_status}" = "SUCCESS" ]; then
    find "${env_dir}" -maxdepth 1 -type f -name '*.tfplan' -delete
    if ! run_phase plan "${log_dir}/plan.log" plan_status make dev_plan ENV=dev CI=true; then
      component_status="FAILED"
      OVERALL_STATUS="FAILED"
    fi
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
        rm -f "${plan_json_file}"
      elif ! changes_status="$(plan_changes_label "${env_dir}" "${plan_file_name}" "${plan_json_file}")"; then
        plan_status="FAILED"
        component_status="FAILED"
        OVERALL_STATUS="FAILED"
        echo "Failed to evaluate Terraform plan changes for ${plan_files[0]}." | tee -a "${log_dir}/plan.log"
        rm -f "${plan_json_file}"
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
      rm -f "${plan_json_file}"
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
    printf -- '- `plan`: `%s`\n' "${plan_status}"
    printf -- '- `changes`: `%s`\n\n' "${changes_status}"
  } >"${section_file}"
  pr_append_details_block "${section_file}" "${payload_label}" "${payload_source}" "${payload_fence}" 16000 "${payload_mode}"
  printf '\n' >>"${section_file}"
}

./cloudbuild/scripts/fetch_github_pr_files.sh "${CHANGED_FILES_FILE}"

while IFS= read -r changed_file; do
  case "${VALIDATION_MODE}" in
    dev)
      case "${changed_file}" in
        Makefile|mk/*|cloudbuild/*|terraform/modules/*|terraform/components/20-storage-bq/*|terraform/components/30-orchestration/*|terraform/envs/dev/*|composer/requirements.txt)
          SELECTED_COMPONENTS["dev"]=1
          ;;
      esac
      ;;
    pre)
      case "${changed_file}" in
        Makefile|mk/*|cloudbuild/*|terraform/modules/*)
          select_all_components
          ;;
        terraform/components/00-bootstrap/*|terraform/envs/shared/00-bootstrap/*)
          SELECTED_COMPONENTS["shared/00-bootstrap"]=1
          ;;
        terraform/components/10-foundation/*|terraform/envs/shared/10-foundation/*)
          SELECTED_COMPONENTS["shared/10-foundation"]=1
          ;;
        terraform/components/20-storage-bq/*|terraform/envs/pre/20-storage-bq/*)
          SELECTED_COMPONENTS["pre/20-storage-bq"]=1
          ;;
        terraform/components/30-orchestration/*|terraform/envs/pre/30-orchestration/*|functions/*|composer/requirements.txt)
          SELECTED_COMPONENTS["pre/30-orchestration"]=1
          ;;
        terraform/components/40-governance/*|terraform/envs/pre/40-governance/*)
          SELECTED_COMPONENTS["pre/40-governance"]=1
          ;;
        terraform/components/50-bi/*|terraform/envs/pre/50-bi/*)
          SELECTED_COMPONENTS["pre/50-bi"]=1
          ;;
        terraform/components/60-cicd/*|terraform/envs/pre/60-cicd/*)
          SELECTED_COMPONENTS["pre/60-cicd"]=1
          ;;
      esac
      ;;
    pro)
      case "${changed_file}" in
        Makefile|mk/*|cloudbuild/*|terraform/modules/*)
          select_all_components
          ;;
        terraform/components/00-bootstrap/*|terraform/envs/pro/00-bootstrap/*)
          SELECTED_COMPONENTS["pro/00-bootstrap"]=1
          ;;
        terraform/components/10-foundation/*|terraform/envs/pro/10-foundation/*)
          SELECTED_COMPONENTS["pro/10-foundation"]=1
          ;;
        terraform/components/20-storage-bq/*|terraform/envs/pro/20-storage-bq/*)
          SELECTED_COMPONENTS["pro/20-storage-bq"]=1
          ;;
        terraform/components/30-orchestration/*|terraform/envs/pro/30-orchestration/*|functions/*|composer/requirements.txt)
          SELECTED_COMPONENTS["pro/30-orchestration"]=1
          ;;
        terraform/components/40-governance/*|terraform/envs/pro/40-governance/*)
          SELECTED_COMPONENTS["pro/40-governance"]=1
          ;;
        terraform/components/50-bi/*|terraform/envs/pro/50-bi/*)
          SELECTED_COMPONENTS["pro/50-bi"]=1
          ;;
        terraform/components/60-cicd/*|terraform/envs/pro/60-cicd/*)
          SELECTED_COMPONENTS["pro/60-cicd"]=1
          ;;
      esac
      ;;
  esac
done <"${CHANGED_FILES_FILE}"

if [ "${SELECT_ALL_COMPONENTS}" = "true" ]; then
  select_all_components
fi

if [ "${#SELECTED_COMPONENTS[@]}" -eq 0 ]; then
  SELECTED_COMPONENT_DIRS=()
else
  mapfile -t SELECTED_COMPONENT_DIRS < <(printf '%s\n' "${!SELECTED_COMPONENTS[@]}" | sort)
fi

if [ "${#SELECTED_COMPONENT_DIRS[@]}" -eq 0 ]; then
  noop_log_file="${RESULT_DIR}/scope.log"
  printf 'No relevant Terraform changes detected for %s.\n' "${VALIDATION_MODE_LABEL}" >"${noop_log_file}"
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
    printf 'Successful: no relevant Terraform changes detected for %s.\n' "${VALIDATION_MODE_LABEL}"
  } >"${COMMENT_BODY_FILE}"
  printf '\n' >>"${COMMENT_BODY_FILE}"
  pr_append_details_block "${COMMENT_BODY_FILE}" "Scope evaluation" "${noop_log_file}" "text" 4000 "text"
else
  for component_dir in "${SELECTED_COMPONENT_DIRS[@]}"; do
    if [ "${component_dir}" = "dev" ]; then
      render_dev_component
    else
      render_standard_component "${component_dir}"
    fi
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
  echo "Terraform PR validation summary: no relevant changes detected for ${VALIDATION_MODE}."
else
  echo "Terraform PR validation summary: components=${SELECTED_COMPONENT_DIRS[*]}, overall=${OVERALL_STATUS}"
fi
