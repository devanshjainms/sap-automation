#!/bin/bash
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# /*---------------------------------------------------------------------------8
# |                                                                            |
# |  Preparation script for STAF (SAP Testing Automation Framework)            |
# |  integration pipeline. This script collects deployment artifacts,          |
# |  resolves the SAP system parameters, inventory, and Key Vault secrets      |
# |  needed to trigger STAF validation tests.                                  |
# |                                                                            |
# +------------------------------------4--------------------------------------*/

full_script_path="$(realpath "${BASH_SOURCE[0]}")"
script_directory="$(dirname "${full_script_path}")"
parent_directory="$(dirname "$script_directory")"
SCRIPT_NAME="$(basename "$0")"

source "${parent_directory}/deploy_utils.sh"
set -e

echo "##########################################################################"
echo "#                                                                        #"
echo "#            STAF Integration - Preparation                              #"
echo "#                                                                        #"
echo "##########################################################################"

green="\e[1;32m"
reset="\e[0m"
boldred="\e[1;31m"

# ---------------------------------------------------------------------------
# Validate required environment variables
# ---------------------------------------------------------------------------
required_vars=(
  SAP_SYSTEM_CONFIGURATION_NAME
  CONFIG_REPO_PATH
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var}" ]]; then
    echo -e "${boldred}ERROR: Required environment variable ${var} is not set.${reset}"
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# Derive environment, location, network, and SID from configuration name
# ---------------------------------------------------------------------------
ENVIRONMENT=$(echo "${SAP_SYSTEM_CONFIGURATION_NAME}" | awk -F'-' '{print $1}' | xargs)
LOCATION=$(echo "${SAP_SYSTEM_CONFIGURATION_NAME}" | awk -F'-' '{print $2}' | xargs)
NETWORK=$(echo "${SAP_SYSTEM_CONFIGURATION_NAME}" | awk -F'-' '{print $3}' | xargs)
SID=$(echo "${SAP_SYSTEM_CONFIGURATION_NAME}" | awk -F'-' '{print $4}' | xargs)

echo -e "${green}--- System details ---${reset}"
echo "Environment:    ${ENVIRONMENT}"
echo "Location:       ${LOCATION}"
echo "Network:        ${NETWORK}"
echo "SID:            ${SID}"

# ---------------------------------------------------------------------------
# Resolve system artifacts folder
# ---------------------------------------------------------------------------
SYSTEM_ARTIFACTS_DIR="${CONFIG_REPO_PATH}/SYSTEM/${SAP_SYSTEM_CONFIGURATION_NAME}/artifacts"

if [[ ! -d "${SYSTEM_ARTIFACTS_DIR}" ]]; then
  echo -e "${boldred}ERROR: System artifacts directory not found: ${SYSTEM_ARTIFACTS_DIR}${reset}"
  exit 1
fi

# Locate sap-parameters.yaml
SAP_PARAMS_FILE=$(find "${SYSTEM_ARTIFACTS_DIR}" -name "sap-parameters.yaml" -type f | head -1)
if [[ -z "${SAP_PARAMS_FILE}" ]]; then
  echo -e "${boldred}ERROR: sap-parameters.yaml not found in ${SYSTEM_ARTIFACTS_DIR}${reset}"
  exit 1
fi
echo -e "${green}SAP parameters file: ${SAP_PARAMS_FILE}${reset}"

# Locate the hosts inventory file
HOSTS_FILE=$(find "${SYSTEM_ARTIFACTS_DIR}" -name "${SID}_hosts.yaml" -type f | head -1)
if [[ -z "${HOSTS_FILE}" ]]; then
  HOSTS_FILE=$(find "${SYSTEM_ARTIFACTS_DIR}" -name "*_hosts.yaml" -type f | head -1)
fi
if [[ -z "${HOSTS_FILE}" ]]; then
  echo -e "${boldred}WARNING: Hosts inventory file not found in ${SYSTEM_ARTIFACTS_DIR}${reset}"
fi
echo -e "${green}Hosts file: ${HOSTS_FILE}${reset}"

# ---------------------------------------------------------------------------
# Resolve Key Vault name from sap-parameters.yaml
# ---------------------------------------------------------------------------
KEYVAULT_NAME=$(awk '$1 == "kv_name:" {print $2}' "${SAP_PARAMS_FILE}" | tr -d '"')
if [[ -z "${KEYVAULT_NAME}" && -n "${KEYVAULT}" ]]; then
  KEYVAULT_NAME="${KEYVAULT}"
fi

echo -e "${green}Key Vault: ${KEYVAULT_NAME}${reset}"

# ---------------------------------------------------------------------------
# Resolve the STAF QA repository details
# ---------------------------------------------------------------------------
STAF_REPO_URL="${STAF_REPO_URL:-https://github.com/Azure/sap-automation-qa.git}"
STAF_REPO_BRANCH="${STAF_REPO_BRANCH:-main}"

echo -e "${green}STAF repository: ${STAF_REPO_URL} (branch: ${STAF_REPO_BRANCH})${reset}"

# ---------------------------------------------------------------------------
# Set output variables for pipeline consumption
# ---------------------------------------------------------------------------
echo "##vso[task.setvariable variable=SAP_PARAMS_FILE;isOutput=true]${SAP_PARAMS_FILE}"
echo "##vso[task.setvariable variable=HOSTS_FILE;isOutput=true]${HOSTS_FILE}"
echo "##vso[task.setvariable variable=KEYVAULT_NAME;isOutput=true]${KEYVAULT_NAME}"
echo "##vso[task.setvariable variable=STAF_REPO_URL;isOutput=true]${STAF_REPO_URL}"
echo "##vso[task.setvariable variable=STAF_REPO_BRANCH;isOutput=true]${STAF_REPO_BRANCH}"
echo "##vso[task.setvariable variable=SID;isOutput=true]${SID}"
echo "##vso[task.setvariable variable=ENVIRONMENT;isOutput=true]${ENVIRONMENT}"
echo "##vso[task.setvariable variable=LOCATION;isOutput=true]${LOCATION}"
echo "##vso[task.setvariable variable=NETWORK;isOutput=true]${NETWORK}"
echo "##vso[task.setvariable variable=SYSTEM_ARTIFACTS_DIR;isOutput=true]${SYSTEM_ARTIFACTS_DIR}"

# Resolve the system configuration directory (parent of artifacts)
SYSTEM_CONFIG_DIR="${CONFIG_REPO_PATH}/SYSTEM/${SAP_SYSTEM_CONFIGURATION_NAME}"
echo "##vso[task.setvariable variable=SYSTEM_CONFIG_DIR;isOutput=true]${SYSTEM_CONFIG_DIR}"

# Export for GitHub Actions compatibility
echo "SAP_PARAMS_FILE=${SAP_PARAMS_FILE}" >> "${GITHUB_OUTPUT:-/dev/null}" 2>/dev/null || true
echo "HOSTS_FILE=${HOSTS_FILE}" >> "${GITHUB_OUTPUT:-/dev/null}" 2>/dev/null || true
echo "KEYVAULT_NAME=${KEYVAULT_NAME}" >> "${GITHUB_OUTPUT:-/dev/null}" 2>/dev/null || true
echo "STAF_REPO_URL=${STAF_REPO_URL}" >> "${GITHUB_OUTPUT:-/dev/null}" 2>/dev/null || true
echo "STAF_REPO_BRANCH=${STAF_REPO_BRANCH}" >> "${GITHUB_OUTPUT:-/dev/null}" 2>/dev/null || true
echo "SID=${SID}" >> "${GITHUB_OUTPUT:-/dev/null}" 2>/dev/null || true
echo "ENVIRONMENT=${ENVIRONMENT}" >> "${GITHUB_OUTPUT:-/dev/null}" 2>/dev/null || true
echo "LOCATION=${LOCATION}" >> "${GITHUB_OUTPUT:-/dev/null}" 2>/dev/null || true
echo "NETWORK=${NETWORK}" >> "${GITHUB_OUTPUT:-/dev/null}" 2>/dev/null || true
echo "SYSTEM_ARTIFACTS_DIR=${SYSTEM_ARTIFACTS_DIR}" >> "${GITHUB_OUTPUT:-/dev/null}" 2>/dev/null || true
echo "SYSTEM_CONFIG_DIR=${SYSTEM_CONFIG_DIR}" >> "${GITHUB_OUTPUT:-/dev/null}" 2>/dev/null || true

echo ""
echo "##########################################################################"
echo "#                                                                        #"
echo "#            STAF Integration - Preparation complete                     #"
echo "#                                                                        #"
echo "##########################################################################"
