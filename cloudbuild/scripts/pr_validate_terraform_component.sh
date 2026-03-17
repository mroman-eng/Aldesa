#!/usr/bin/env bash
set -u -o pipefail

COMPONENT_TARGET="${1:?component target is required}"
COMPONENT_DIR="${2:?component dir is required}"
ENVIRONMENT="${3:?environment is required}"
RESULT_DIR="${PR_TF_RESULT_DIR:-/workspace/.cloudbuild/pr-tf}"
ENV_DIR="terraform/envs/${ENVIRONMENT}/${COMPONENT_DIR}"
PLAN_RENDER_FILE="${RESULT_DIR}/plan.txt"
RESULT_ENV_FILE="${RESULT_DIR}/result.env"
LOG_DIR="${RESULT_DIR}/logs"

mkdir -p "${LOG_DIR}"
rm -f "${PLAN_RENDER_FILE}" "${RESULT_ENV_FILE}"

FMT_STATUS="SKIPPED"
INIT_STATUS="SKIPPED"
VALIDATE_STATUS="SKIPPED"
PLAN_STATUS="SKIPPED"
OVERALL_STATUS="SUCCESS"

CB_PROJECT_ID="${CB_PROJECT_ID:?CB_PROJECT_ID is required}"
CB_BUILD_ID="${CB_BUILD_ID:?CB_BUILD_ID is required}"
BUILD_LOCATION="${CB_LOCATION:-global}"
BUILD_LOG_URL="https://console.cloud.google.com/cloud-build/builds;region=${BUILD_LOCATION}/${CB_BUILD_ID}?project=${CB_PROJECT_ID}"

run_phase() {
  local phase="$1"
  local log_file="${LOG_DIR}/${phase}.log"
  shift

  echo
  echo "==> ${phase}"

  set +e
  "$@" 2>&1 | tee "${log_file}"
  local rc=${PIPESTATUS[0]}
  set +e

  if [ "${rc}" -eq 0 ]; then
    printf -v "${phase}_STATUS" "%s" "SUCCESS"
  else
    printf -v "${phase}_STATUS" "%s" "FAILED"
    OVERALL_STATUS="FAILED"
  fi

  return 0
}

mark_skipped() {
  local phase="$1"
  local reason="$2"
  local log_file="${LOG_DIR}/${phase}.log"
  printf -v "${phase}_STATUS" "%s" "SKIPPED"
  printf 'Skipped: %s\n' "${reason}" | tee "${log_file}"
}

run_phase FMT terraform fmt -check -recursive "terraform/components/${COMPONENT_DIR}" "${ENV_DIR}"
run_phase INIT terraform -chdir="${ENV_DIR}" init -backend=false -reconfigure -input=false

if [ "${INIT_STATUS}" = "SUCCESS" ]; then
  run_phase VALIDATE terraform -chdir="${ENV_DIR}" validate
else
  mark_skipped VALIDATE "terraform init failed"
  OVERALL_STATUS="FAILED"
fi

if [ "${INIT_STATUS}" = "SUCCESS" ] && [ "${VALIDATE_STATUS}" = "SUCCESS" ]; then
  run_phase PLAN make "${COMPONENT_TARGET}_plan" ENV="${ENVIRONMENT}" CI=true
else
  mark_skipped PLAN "terraform init/validate did not succeed"
  OVERALL_STATUS="FAILED"
fi

if [ "${PLAN_STATUS}" = "SUCCESS" ]; then
  mapfile -t plan_files < <(find "${ENV_DIR}" -maxdepth 1 -type f -name '*.tfplan' | sort)
  if [ "${#plan_files[@]}" -eq 1 ]; then
    if ! terraform show -no-color "${plan_files[0]}" >"${PLAN_RENDER_FILE}"; then
      PLAN_STATUS="FAILED"
      OVERALL_STATUS="FAILED"
      echo "Failed to render Terraform plan file ${plan_files[0]}." | tee -a "${LOG_DIR}/PLAN.log"
      rm -f "${PLAN_RENDER_FILE}"
    fi
  else
    PLAN_STATUS="FAILED"
    OVERALL_STATUS="FAILED"
    {
      echo "Expected exactly one Terraform plan file in ${ENV_DIR}."
      echo "Found ${#plan_files[@]} plan files."
      printf '%s\n' "${plan_files[@]}"
    } | tee -a "${LOG_DIR}/PLAN.log"
    rm -f "${PLAN_RENDER_FILE}"
  fi
fi

cat >"${RESULT_ENV_FILE}" <<EOF
$(printf 'COMPONENT_TARGET=%q\n' "${COMPONENT_TARGET}")
$(printf 'COMPONENT_DIR=%q\n' "${COMPONENT_DIR}")
$(printf 'ENVIRONMENT=%q\n' "${ENVIRONMENT}")
$(printf 'FMT_STATUS=%q\n' "${FMT_STATUS}")
$(printf 'INIT_STATUS=%q\n' "${INIT_STATUS}")
$(printf 'VALIDATE_STATUS=%q\n' "${VALIDATE_STATUS}")
$(printf 'PLAN_STATUS=%q\n' "${PLAN_STATUS}")
$(printf 'OVERALL_STATUS=%q\n' "${OVERALL_STATUS}")
$(printf 'BUILD_LOG_URL=%q\n' "${BUILD_LOG_URL}")
$(printf 'BUILD_ID=%q\n' "${CB_BUILD_ID}")
$(printf 'BUILD_LOCATION=%q\n' "${BUILD_LOCATION}")
$(printf 'PROJECT_ID=%q\n' "${CB_PROJECT_ID}")
$(printf 'PR_NUMBER=%q\n' "${CB_PR_NUMBER:-}")
$(printf 'REPO_FULL_NAME=%q\n' "${CB_REPO_FULL_NAME:-}")
$(printf 'TRIGGER_NAME=%q\n' "${CB_TRIGGER_NAME:-}")
$(printf 'COMMIT_SHA=%q\n' "${CB_COMMIT_SHA:-}")
$(printf 'SHORT_SHA=%q\n' "${CB_SHORT_SHA:-}")
EOF

echo
echo "Validation summary for ${COMPONENT_DIR}: fmt=${FMT_STATUS}, init=${INIT_STATUS}, validate=${VALIDATE_STATUS}, plan=${PLAN_STATUS}, overall=${OVERALL_STATUS}"
