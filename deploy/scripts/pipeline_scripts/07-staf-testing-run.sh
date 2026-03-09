#!/bin/bash
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# /*---------------------------------------------------------------------------8
# |                                                                            |
# |  Execution script for STAF (SAP Testing Automation Framework)              |
# |  Clones the sap-automation-qa repository and runs the configured           |
# |  test suites against the deployed SAP system.                              |
# |                                                                            |
# +------------------------------------4--------------------------------------*/

full_script_path="$(realpath "${BASH_SOURCE[0]}")"
script_directory="$(dirname "${full_script_path}")"
parent_directory="$(dirname "$script_directory")"

set -e

echo "##########################################################################"
echo "#                                                                        #"
echo "#            STAF Integration - Test Execution                           #"
echo "#                                                                        #"
echo "##########################################################################"

green="\e[1;32m"
reset="\e[0m"
boldred="\e[1;31m"
cyan="\e[1;36m"

# ---------------------------------------------------------------------------
# Validate required environment variables
# ---------------------------------------------------------------------------
required_vars=(
  SAP_PARAMS_FILE
  SID
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var}" ]]; then
    echo -e "${boldred}ERROR: Required environment variable ${var} is not set.${reset}"
    exit 1
  fi
done

# Defaults
STAF_REPO_URL="${STAF_REPO_URL:-https://github.com/Azure/sap-automation-qa.git}"
STAF_REPO_BRANCH="${STAF_REPO_BRANCH:-main}"
STAF_WORKING_DIR="${STAF_WORKING_DIR:-$(pwd)/sap-automation-qa}"
STAF_TEST_SUITES="${STAF_TEST_SUITES:-configuration_checks,db_ha,cs_ha}"
STAF_RESULTS_DIR="${STAF_RESULTS_DIR:-$(pwd)/staf_results}"

# Config repo system directory - where HTML reports and logs are persisted
# Expected structure: <config_repo>/SYSTEM/<SAP_SYSTEM_CONFIGURATION_NAME>/
SYSTEM_CONFIG_DIR="${SYSTEM_CONFIG_DIR:-}"
CONFIG_REPO_PATH="${CONFIG_REPO_PATH:-}"

# ---------------------------------------------------------------------------
# Clone or update the STAF repository
# ---------------------------------------------------------------------------
echo -e "${green}--- Cloning STAF repository ---${reset}"
if [[ -d "${STAF_WORKING_DIR}" ]]; then
  echo "STAF repository already exists at ${STAF_WORKING_DIR}, pulling latest..."
  pushd "${STAF_WORKING_DIR}" > /dev/null
  git fetch origin
  git checkout "${STAF_REPO_BRANCH}"
  git pull origin "${STAF_REPO_BRANCH}"
  popd > /dev/null
else
  git clone --branch "${STAF_REPO_BRANCH}" --single-branch "${STAF_REPO_URL}" "${STAF_WORKING_DIR}"
fi

# ---------------------------------------------------------------------------
# Set up Python virtual environment for STAF
# ---------------------------------------------------------------------------
echo -e "${green}--- Setting up Python environment ---${reset}"
STAF_VENV="${STAF_WORKING_DIR}/.venv"
if [[ ! -d "${STAF_VENV}" ]]; then
  python3 -m venv "${STAF_VENV}"
fi
source "${STAF_VENV}/bin/activate"

if [[ -f "${STAF_WORKING_DIR}/requirements.txt" ]]; then
  pip install --quiet --upgrade pip
  pip install --quiet -r "${STAF_WORKING_DIR}/requirements.txt"
fi

# ---------------------------------------------------------------------------
# Prepare STAF configuration from SAP deployment artifacts
# ---------------------------------------------------------------------------
echo -e "${green}--- Preparing STAF configuration ---${reset}"
mkdir -p "${STAF_RESULTS_DIR}"

# Build the configuration JSON for STAF
STAF_CONFIG_FILE="${STAF_RESULTS_DIR}/staf_config.json"
cat > "${STAF_CONFIG_FILE}" << EOF
{
  "sap_sid": "${SID}",
  "sap_params_file": "${SAP_PARAMS_FILE}",
  "hosts_file": "${HOSTS_FILE:-}",
  "keyvault_name": "${KEYVAULT_NAME:-}",
  "environment": "${ENVIRONMENT:-}",
  "location": "${LOCATION:-}",
  "network": "${NETWORK:-}",
  "test_suites": "${STAF_TEST_SUITES}",
  "system_configuration_name": "${SAP_SYSTEM_CONFIGURATION_NAME:-}",
  "subscription_id": "${ARM_SUBSCRIPTION_ID:-}",
  "tenant_id": "${ARM_TENANT_ID:-}"
}
EOF

echo -e "${cyan}STAF configuration:${reset}"
cat "${STAF_CONFIG_FILE}"
echo ""

# ---------------------------------------------------------------------------
# Execute test suites
# ---------------------------------------------------------------------------
echo -e "${green}--- Running STAF test suites ---${reset}"
RETURN_CODE=0
IFS=',' read -ra SUITES <<< "${STAF_TEST_SUITES}"

for suite in "${SUITES[@]}"; do
  suite=$(echo "${suite}" | xargs)  # Trim whitespace
  echo -e "${cyan}=== Running test suite: ${suite} ===${reset}"

  SUITE_DIR="${STAF_WORKING_DIR}/testsuites/${suite}"
  SUITE_RESULTS="${STAF_RESULTS_DIR}/${suite}"
  mkdir -p "${SUITE_RESULTS}"

  if [[ -d "${SUITE_DIR}" ]]; then
    # Check for pytest tests
    if find "${SUITE_DIR}" -name "test_*.py" -o -name "*_test.py" | grep -q .; then
      echo "Running pytest for suite: ${suite}"
      python -m pytest "${SUITE_DIR}" \
        --config-file="${STAF_CONFIG_FILE}" \
        --junitxml="${SUITE_RESULTS}/junit_results.xml" \
        --html="${SUITE_RESULTS}/report.html" \
        --self-contained-html \
        -v \
        2>&1 | tee "${SUITE_RESULTS}/test_output.log" || {
          echo -e "${boldred}Test suite '${suite}' had failures.${reset}"
          RETURN_CODE=1
        }
    # Check for Ansible-based tests
    elif find "${SUITE_DIR}" -name "*.yaml" -o -name "*.yml" | grep -q .; then
      PLAYBOOK=$(find "${SUITE_DIR}" -name "playbook_*.yaml" -o -name "playbook_*.yml" | head -1)
      if [[ -n "${PLAYBOOK}" ]]; then
        echo "Running Ansible playbook for suite: ${suite}"
        ansible-playbook "${PLAYBOOK}" \
          --extra-vars="@${SAP_PARAMS_FILE}" \
          --extra-vars="staf_config_file=${STAF_CONFIG_FILE}" \
          --extra-vars="staf_results_dir=${SUITE_RESULTS}" \
          ${HOSTS_FILE:+--inventory="${HOSTS_FILE}"} \
          -v \
          2>&1 | tee "${SUITE_RESULTS}/test_output.log" || {
            echo -e "${boldred}Test suite '${suite}' had failures.${reset}"
            RETURN_CODE=1
          }
      else
        echo -e "${boldred}WARNING: No playbook found in ${SUITE_DIR}${reset}"
      fi
    # Check for shell-based tests
    elif find "${SUITE_DIR}" -name "run_tests.sh" | grep -q .; then
      echo "Running shell tests for suite: ${suite}"
      bash "${SUITE_DIR}/run_tests.sh" \
        "${STAF_CONFIG_FILE}" \
        "${SUITE_RESULTS}" \
        2>&1 | tee "${SUITE_RESULTS}/test_output.log" || {
          echo -e "${boldred}Test suite '${suite}' had failures.${reset}"
          RETURN_CODE=1
        }
    else
      echo -e "${boldred}WARNING: No runnable tests found in ${SUITE_DIR}${reset}"
    fi
  else
    echo -e "${boldred}WARNING: Test suite directory not found: ${SUITE_DIR}${reset}"
  fi

  echo ""
done

# ---------------------------------------------------------------------------
# Generate summary
# ---------------------------------------------------------------------------
echo -e "${green}--- Test Execution Summary ---${reset}"
SUMMARY_FILE="${STAF_RESULTS_DIR}/summary.md"
cat > "${SUMMARY_FILE}" << SUMMARY_EOF
# STAF Test Results Summary

| Property | Value |
|----------|-------|
| **SAP SID** | ${SID} |
| **Environment** | ${ENVIRONMENT:-N/A} |
| **Location** | ${LOCATION:-N/A} |
| **System Configuration** | ${SAP_SYSTEM_CONFIGURATION_NAME:-N/A} |
| **Test Suites** | ${STAF_TEST_SUITES} |
| **Overall Result** | $([ ${RETURN_CODE} -eq 0 ] && echo "PASSED ✅" || echo "FAILED ❌") |
| **Timestamp** | $(date -u +"%Y-%m-%dT%H:%M:%SZ") |

## Test Suite Results
SUMMARY_EOF

for suite in "${SUITES[@]}"; do
  suite=$(echo "${suite}" | xargs)
  SUITE_RESULTS="${STAF_RESULTS_DIR}/${suite}"
  if [[ -f "${SUITE_RESULTS}/junit_results.xml" ]]; then
    TESTS=$(grep -oP 'tests="\K[^"]+' "${SUITE_RESULTS}/junit_results.xml" 2>/dev/null | head -1 || echo "N/A")
    FAILURES=$(grep -oP 'failures="\K[^"]+' "${SUITE_RESULTS}/junit_results.xml" 2>/dev/null | head -1 || echo "N/A")
    echo "| ${suite} | Tests: ${TESTS}, Failures: ${FAILURES} |" >> "${SUMMARY_FILE}"
  else
    echo "| ${suite} | See logs |" >> "${SUMMARY_FILE}"
  fi
done

cat "${SUMMARY_FILE}"
echo ""

# ---------------------------------------------------------------------------
# Persist results to the configuration repository
# ---------------------------------------------------------------------------
if [[ -n "${SYSTEM_CONFIG_DIR}" && -d "${SYSTEM_CONFIG_DIR}" ]]; then
  echo -e "${green}--- Persisting results to configuration repository ---${reset}"

  TIMESTAMP=$(date -u +"%Y%m%d_%H%M%S")

  # Create sap-automation-qa directory for HTML reports
  CONFIG_QA_DIR="${SYSTEM_CONFIG_DIR}/sap-automation-qa"
  mkdir -p "${CONFIG_QA_DIR}"

  # Create logs directory for log files
  CONFIG_LOGS_DIR="${SYSTEM_CONFIG_DIR}/logs"
  mkdir -p "${CONFIG_LOGS_DIR}"

  for suite in "${SUITES[@]}"; do
    suite=$(echo "${suite}" | xargs)
    SUITE_RESULTS="${STAF_RESULTS_DIR}/${suite}"

    # Copy HTML reports to sap-automation-qa/<suite>/
    QA_SUITE_DIR="${CONFIG_QA_DIR}/${suite}"
    mkdir -p "${QA_SUITE_DIR}"
    if [[ -f "${SUITE_RESULTS}/report.html" ]]; then
      cp "${SUITE_RESULTS}/report.html" "${QA_SUITE_DIR}/report_${TIMESTAMP}.html"
      # Also keep a latest copy
      cp "${SUITE_RESULTS}/report.html" "${QA_SUITE_DIR}/report.html"
    fi
    if [[ -f "${SUITE_RESULTS}/junit_results.xml" ]]; then
      cp "${SUITE_RESULTS}/junit_results.xml" "${QA_SUITE_DIR}/junit_results_${TIMESTAMP}.xml"
      cp "${SUITE_RESULTS}/junit_results.xml" "${QA_SUITE_DIR}/junit_results.xml"
    fi

    # Copy log files to logs/<suite>/
    LOGS_SUITE_DIR="${CONFIG_LOGS_DIR}/${suite}"
    mkdir -p "${LOGS_SUITE_DIR}"
    if [[ -f "${SUITE_RESULTS}/test_output.log" ]]; then
      cp "${SUITE_RESULTS}/test_output.log" "${LOGS_SUITE_DIR}/test_output_${TIMESTAMP}.log"
      # Also keep a latest copy
      cp "${SUITE_RESULTS}/test_output.log" "${LOGS_SUITE_DIR}/test_output.log"
    fi
  done

  # Copy the summary to sap-automation-qa/
  if [[ -f "${STAF_RESULTS_DIR}/summary.md" ]]; then
    cp "${STAF_RESULTS_DIR}/summary.md" "${CONFIG_QA_DIR}/summary.md"
    cp "${STAF_RESULTS_DIR}/summary.md" "${CONFIG_QA_DIR}/summary_${TIMESTAMP}.md"
  fi
  if [[ -f "${STAF_RESULTS_DIR}/staf_config.json" ]]; then
    cp "${STAF_RESULTS_DIR}/staf_config.json" "${CONFIG_QA_DIR}/staf_config.json"
  fi

  echo -e "${green}HTML reports: ${CONFIG_QA_DIR}${reset}"
  echo -e "${green}Log files:    ${CONFIG_LOGS_DIR}${reset}"

  # ---------------------------------------------------------------------------
  # Commit and push results to the configuration repository
  # ---------------------------------------------------------------------------
  # Determine the config repo root (walk up from SYSTEM_CONFIG_DIR to find .git)
  CONFIG_REPO_ROOT="${SYSTEM_CONFIG_DIR}"
  while [[ "${CONFIG_REPO_ROOT}" != "/" && ! -d "${CONFIG_REPO_ROOT}/.git" ]]; do
    CONFIG_REPO_ROOT="$(dirname "${CONFIG_REPO_ROOT}")"
  done

  if [[ -d "${CONFIG_REPO_ROOT}/.git" ]]; then
    echo -e "${green}--- Committing results to config repository ---${reset}"
    pushd "${CONFIG_REPO_ROOT}" > /dev/null

    git add "${SYSTEM_CONFIG_DIR}/sap-automation-qa/" "${SYSTEM_CONFIG_DIR}/logs/" 2>/dev/null || true

    # Only commit if there are staged changes
    if git diff --cached --quiet 2>/dev/null; then
      echo "No new changes to commit."
    else
      git commit -m "STAF results for ${SAP_SYSTEM_CONFIGURATION_NAME:-${SID}} [${TIMESTAMP}]" \
                 -m "Test suites: ${STAF_TEST_SUITES}" \
                 -m "Result: $([ ${RETURN_CODE} -eq 0 ] && echo 'PASSED' || echo 'FAILED')" \
                 --author="STAF Pipeline <staf@azure.com>" || {
        echo -e "${boldred}WARNING: git commit failed.${reset}"
      }

      git push || {
        echo -e "${boldred}WARNING: git push failed. Results saved locally but not pushed to remote.${reset}"
      }
    fi

    popd > /dev/null
  else
    echo -e "${boldred}WARNING: Config repo root not found (no .git directory). Results saved locally only.${reset}"
  fi
else
  echo -e "${cyan}NOTE: SYSTEM_CONFIG_DIR not set. Test results stored in ${STAF_RESULTS_DIR} only (not persisted to config repo).${reset}"
fi

# Deactivate virtual environment
deactivate 2>/dev/null || true

echo "##########################################################################"
echo "#                                                                        #"
echo "#  STAF Integration - Test Execution complete (exit code: ${RETURN_CODE})         #"
echo "#                                                                        #"
echo "##########################################################################"

exit ${RETURN_CODE}
