#!/bin/bash
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# Ensure that the exit status of a pipeline command is non-zero if any
# stage of the pipefile has a non-zero exit status.
set -o pipefail

bold_red_underscore="\e[1;4;31m"
bold_red="\e[1;31m"
cyan="\e[1;36m"
reset_formatting="\e[0m"

full_script_path="$(realpath "${BASH_SOURCE[0]}")"
script_directory="$(dirname "${full_script_path}")"
parent_caller="${BASH_SOURCE[${#BASH_SOURCE[@]} - 1]}"
parent_caller_directory="$(dirname $(realpath "${parent_caller}"))"

if [[ "${parent_caller_directory}" == *"/v1/"* || "${parent_caller_directory}" == *"/v1" ]]; then
    echo "DEBUG: Detected v1 caller"
		isCallerV1=0
else
		echo "DEBUG: Detected v2 caller"
    isCallerV1=1
fi

#call stack has full script name when using source
# shellcheck disable=SC1091
source "${script_directory}/deploy_utils.sh"

#helper files
# shellcheck disable=SC1091
source "${script_directory}/helpers/script_helpers.sh"

if [ "$DEBUG" = True ]; then
	set -x
	set -o errexit
fi

force=0
called_from_ado=0
deploy_using_msi_only=0

INPUT_ARGUMENTS=$(getopt -n install_backup -o p:d:e:k:o:s:c:n:t:v:aifhm --longoptions parameterfile:,deployer_tfstate_key:,deployer_environment:,subscription:,spn_id:,spn_secret:,tenant_id:,state_subscription:,keyvault:,storageaccountname:,ado,auto-approve,force,help,msi -- "$@")
VALID_ARGUMENTS=$?

if [ "$VALID_ARGUMENTS" != "0" ]; then
  showhelp
fi

eval set -- "$INPUT_ARGUMENTS"
while :
do
  case "$1" in
    -p | --parameterfile)                 parameterfile="$2";                 shift 2 ;;
    -d | --deployer_tfstate_key)          deployer_tfstate_key="$2";          shift 2 ;;
    -e | --deployer_environment)          deployer_environment="$2";          shift 2 ;;
    -k | --keyvault)                      keyvault="$2";                      shift 2 ;;
    -o | --storageaccountname)            REMOTE_STATE_SA="$2";               shift 2 ;;
    -s | --state_subscription)            STATE_SUBSCRIPTION="$2";            shift 2 ;;
    -c | --subscription)                  subscription="$2";                  shift 2 ;;
    -n | --spn_id)                        client_id="$2";                     shift 2 ;;
    -t | --tenant_id)                     tenant_id="$2";                     shift 2 ;;
    -v | --spn_secret)                    client_secret="$2";                 shift 2 ;;
    -a | --ado)                          called_from_ado=1;                  shift ;;
    -i | --auto-approve)                  approve="--auto-approve";           shift ;;
    -f | --force)                        force=1;                            shift ;;
    -h | --help)                         showhelp; exit 3;                   shift ;;
    -m | --msi)                          deploy_using_msi_only=1;            shift ;;
    --) shift; break ;;
  esac
done

deployment_system="sap_backup"
this_ip=$(curl -s ipinfo.io/ip) >/dev/null 2>&1

printf "\n%s\n" "#########################################################################################"
printf "%s\n" "#                                                                                       #"
printf "%s\n" "#                           SAP Backup Infrastructure Deployment                        #"
printf "%s\n" "#                                                                                       #"
printf "%s\n" "#########################################################################################"

parameterfile="${parameterfile:-tfvars}"
deployer_environment="${deployer_environment:-MGMT}"

if [ 1 == $called_from_ado ]; then
    this_ip=$(curl -s ipinfo.io/ip) >/dev/null 2>&1
    export TF_VAR_Agent_IP=$this_ip
    echo "Agent IP:                            $this_ip"
fi

backup_file_parametername=$(basename "${parameterfile}")
param_dirname=$(dirname "${parameterfile}")
export TF_DATA_DIR="${param_dirname}/.terraform"

if [ "$param_dirname" != '.' ]; then
    echo ""
    echo "#########################################################################################"
    echo "#                                                                                       #"
    echo -e "#  $bold_red Please run this command from the folder containing the parameter file$reset_formatting               #"
    echo "#                                                                                       #"
    echo "#########################################################################################"
    exit 3
fi

if [ ! -f "${backup_file_parametername}" ]; then
    printf -v val %-40.40s "$backup_file_parametername"
    echo ""
    echo "#########################################################################################"
    echo "#                                                                                       #"
    echo -e "#                 $bold_red_underscore Parameter file does not exist: ${val}$reset_formatting #"
    echo "#                                                                                       #"
    echo "#########################################################################################"
    exit 3
fi

# Check that the exports ARM_SUBSCRIPTION_ID and SAP_AUTOMATION_REPO_PATH are defined
validate_exports
return_code=$?
if [ 0 != $return_code ]; then
    exit $return_code
fi

# Check that Terraform and Azure CLI is installed
validate_dependencies
return_code=$?
if [ 0 != $return_code ]; then
    exit $return_code
fi

# Check that parameter files have environment and location defined
validate_key_parameters "$backup_file_parametername"
return_code=$?
if [ 0 != $return_code ]; then
    exit $return_code
fi

backup_configuration_name=$(echo "${backup_file_parametername}" | cut -d. -f1)

echo "Backup Configuration Name: ${backup_configuration_name}"

IFS='-' read -ra NAME_PARTS <<< "${backup_configuration_name}"
if [ ${#NAME_PARTS[@]} -lt 4 ]; then
    printf "%b%s%b\n" "${bold_red_underscore}" "Invalid backup configuration name format. Expected: ENV-REGION-LOGICAL_BACKUP_NAME-BACKUP" "${reset_formatting}"
    exit 1
fi

environment="${NAME_PARTS[0]}"
region_code="${NAME_PARTS[1]}"
backup_name="${NAME_PARTS[2]}"

# Convert the region to the correct code
get_region_code "$region"

if [ "${region_code}" == 'UNKN' ]; then
    LOCATION_CODE_IN_FILENAME=$(echo "$backup_file_parametername" | awk -F'-' '{print $2}')
    region_code=$(echo "${LOCATION_CODE_IN_FILENAME}" | tr "[:lower:]" "[:upper:]" | xargs)
fi

echo "Environment: ${environment}"
echo "Region Code: ${region_code}"
echo "Backup Name: ${backup_name}"
echo "Region:                              $region"

automation_config_directory=$CONFIG_REPO_PATH/.sap_deployment_automation
generic_config_information="${automation_config_directory}"/config
backup_config_information="${automation_config_directory}/${environment}${region_code}${backup_name}"

touch "${backup_config_information}"
deployer_config_information="${automation_config_directory}/${deployer_environment}${region_code}"

save_config_vars "${backup_config_information}" \
    STATE_SUBSCRIPTION REMOTE_STATE_SA subscription

if [ "${force}" == 1 ]; then
    if [ -f "${backup_config_information}" ]; then
        rm "${backup_config_information}"
    fi
    rm -Rf .terraform terraform.tfstate*
fi

echo ""
echo "Configuration file:                  $backup_config_information"
echo "Deployment region:                   $region"
echo "Deployment region code:              $region_code"
echo "Deployment environment:              $deployer_environment"
echo "Target Subscription:                 $subscription"

terraform_module_directory="${script_directory}/../terraform/run/sap_backup"
export TF_DATA_DIR="${terraform_module_directory}/.terraform"

deployment_id=$(echo "${backup_configuration_name}" | sha256sum | cut -c1-7)
tfstate_backup="terraform-${environment}-${region_code}-${backup_name}-backup.tfstate"

echo "State file: ${tfstate_backup}"

# Deployer configuration
deployer_tfstate_key_backup="${deployer_tfstate_key:-${deployer_environment}-${region_code}-DEPLOYER-infrastructure.tfstate}"

#Plugins
if checkIfCloudShell; then
    mkdir -p "${HOME}/.terraform.d/plugin-cache"
    export TF_PLUGIN_CACHE_DIR="${HOME}/.terraform.d/plugin-cache"
else
    if [ ! -d /opt/terraform/.terraform.d/plugin-cache ]; then
        sudo mkdir -p /opt/terraform/.terraform.d/plugin-cache
        sudo chown -R "$USER" /opt/terraform
    fi
    export TF_PLUGIN_CACHE_DIR=/opt/terraform/.terraform.d/plugin-cache
fi

if [ ! -f "${backup_config_information}" ]; then
    # Ask for deployer environment name and try to read the deployer state file and resource group details from the configuration file
    if [ -z "$deployer_environment" ]; then
        read -r -p "Deployer environment name: " deployer_environment
    fi

    deployer_config_information="${automation_config_directory}"/"${deployer_environment}""${region_code}"
    if [ -f "$deployer_config_information" ]; then
        if [ -z "${keyvault}" ]; then
            load_config_vars "${deployer_config_information}" "keyvault"
        fi

        load_config_vars "${deployer_config_information}" "REMOTE_STATE_RG"
        if [ -z "${REMOTE_STATE_SA}" ]; then
            load_config_vars "${deployer_config_information}" "REMOTE_STATE_SA"
        fi
        load_config_vars "${deployer_config_information}" "tfstate_resource_id"
        load_config_vars "${deployer_config_information}" "deployer_tfstate_key"

        save_config_vars "${backup_config_information}" \
            keyvault \
            subscription \
            deployer_tfstate_key \
            tfstate_resource_id \
            REMOTE_STATE_SA \
            REMOTE_STATE_RG
    fi
fi

if [ -z "$tfstate_resource_id" ]; then
    echo "No tfstate_resource_id"
    if [ -n "$deployer_environment" ]; then
        deployer_config_information="${automation_config_directory}"/"${deployer_environment}""${region_code}"
        echo "Deployer config file:                $deployer_config_information"
        if [ -f "$deployer_config_information" ]; then
            load_config_vars "${deployer_config_information}" "keyvault"
            load_config_vars "${deployer_config_information}" "REMOTE_STATE_RG"
            load_config_vars "${deployer_config_information}" "REMOTE_STATE_SA"
            load_config_vars "${deployer_config_information}" "tfstate_resource_id"
            load_config_vars "${deployer_config_information}" "deployer_tfstate_key"

            save_config_vars "${backup_config_information}" \
                tfstate_resource_id

            save_config_vars "${backup_config_information}" \
                keyvault \
                subscription \
                deployer_tfstate_key \
                REMOTE_STATE_SA \
                REMOTE_STATE_RG
        fi
    fi
else
    echo "Terraform Storage Account Id:        $tfstate_resource_id"
    save_config_vars "${backup_config_information}" \
        tfstate_resource_id
fi

echo ""
init "${automation_config_directory}" "${generic_config_information}" "${backup_config_information}"

param_dirname=$(pwd)
var_file="${param_dirname}"/"${parameterfile}"
export TF_DATA_DIR="${param_dirname}/.terraform"

extra_vars=""
if [ -f terraform.tfvars ]; then
    extra_vars=" -var-file=${param_dirname}/terraform.tfvars "
fi

if [ -n "$subscription" ]; then
    if is_valid_guid "$subscription"; then
        echo ""
        export ARM_SUBSCRIPTION_ID="${subscription}"
    else
        printf -v val %-40.40s "$subscription"
        echo "#########################################################################################"
        echo "#                                                                                       #"
        echo -e "#   The provided subscription is not valid:$bold_red ${val} $reset_formatting#   "
        echo "#                                                                                       #"
        echo "#########################################################################################"
        echo "The provided subscription is not valid: ${val}" >"${backup_config_information}".err
        exit 65
    fi
fi

if [ 0 = "${deploy_using_msi_only:-}" ]; then
    if [ -n "$client_id" ]; then
        if is_valid_guid "$client_id"; then
            echo ""
        else
            printf -v val %-40.40s "$client_id"
            echo "#########################################################################################"
            echo "#                                                                                       #"
            echo -e "#         The provided spn_id is not valid:$bold_red ${val} $reset_formatting   #"
            echo "#                                                                                       #"
            echo "#########################################################################################"
            exit 65
        fi
    fi

    if [ -n "$tenant_id" ]; then
        if is_valid_guid "$tenant_id"; then
            echo ""
        else
            printf -v val %-40.40s "$tenant_id"
            echo "#########################################################################################"
            echo "#                                                                                       #"
            echo -e "#       The provided tenant_id is not valid:$bold_red ${val} $reset_formatting  #"
            echo "#                                                                                       #"
            echo "#########################################################################################"
            exit 65
        fi
    fi
fi

if [[ -z ${REMOTE_STATE_SA} ]]; then
    load_config_vars "${backup_config_information}" "REMOTE_STATE_SA"
fi

load_config_vars "${backup_config_information}" "REMOTE_STATE_RG"
load_config_vars "${backup_config_information}" "tfstate_resource_id"

if [[ -z ${STATE_SUBSCRIPTION} ]]; then
    load_config_vars "${backup_config_information}" "STATE_SUBSCRIPTION"
fi

if [[ -z ${subscription} ]]; then
    load_config_vars "${backup_config_information}" "subscription"
fi

if [[ -z ${deployer_tfstate_key} ]]; then
    load_config_vars "${backup_config_information}" "deployer_tfstate_key"
fi

if [ -n "$tfstate_resource_id" ]; then
    REMOTE_STATE_RG=$(echo "$tfstate_resource_id" | cut -d / -f5)
    REMOTE_STATE_SA=$(echo "$tfstate_resource_id" | cut -d / -f9)
    STATE_SUBSCRIPTION=$(echo "$tfstate_resource_id" | cut -d / -f3)

    save_config_vars "${backup_config_information}" \
        REMOTE_STATE_SA \
        REMOTE_STATE_RG \
        STATE_SUBSCRIPTION
else
    getAndStoreTerraformStateStorageAccountDetails "${REMOTE_STATE_SA}" "${backup_config_information}"
fi

if [ -z "$subscription" ]; then
    subscription="${STATE_SUBSCRIPTION}"
fi

if [ -z "$REMOTE_STATE_SA" ]; then
    if [ -z "$REMOTE_STATE_RG" ]; then
        load_config_vars "${backup_config_information}" "tfstate_resource_id"
        if [ -n "${tfstate_resource_id}" ]; then
            REMOTE_STATE_RG=$(echo "$tfstate_resource_id" | cut -d / -f5)
            REMOTE_STATE_SA=$(echo "$tfstate_resource_id" | cut -d / -f9)
            STATE_SUBSCRIPTION=$(echo "$tfstate_resource_id" | cut -d / -f3)
        fi
    fi

    tfstate_parameter=" -var tfstate_resource_id=${tfstate_resource_id}"
    export TF_VAR_tfstate_resource_id=${tfstate_resource_id}
else
    if [ -z "$REMOTE_STATE_RG" ]; then
        getAndStoreTerraformStateStorageAccountDetails "${REMOTE_STATE_SA}" "${backup_config_information}"
        load_config_vars "${backup_config_information}" "STATE_SUBSCRIPTION"
        load_config_vars "${backup_config_information}" "REMOTE_STATE_RG"
        load_config_vars "${backup_config_information}" "tfstate_resource_id"
    fi
fi

useSAS=$(az storage account show --name "${REMOTE_STATE_SA}" --query allowSharedKeyAccess --subscription "${STATE_SUBSCRIPTION}" --out tsv)

if [ "$useSAS" = "true" ]; then
    echo "Storage Account authentication:       key"
    export ARM_USE_AZUREAD=false
else
    echo "Storage Account authentication:       Entra ID"
    export ARM_USE_AZUREAD=true
fi

if [ 1 = "${deploy_using_msi_only:-}" ]; then
    if [ -n "${keyvault}" ]; then
        echo "Setting the secrets"

        echo "Calling set_secrets with:             --backup --environment ${environment} --region ${region_code} --vault ${keyvault} \
    --keyvault_subscription ${STATE_SUBSCRIPTION} --subscription ${ARM_SUBSCRIPTION_ID} --msi"

        "${SAP_AUTOMATION_REPO_PATH}"/deploy/scripts/set_secrets.sh --backup --environment "${environment}" --region "${region_code}" \
            --vault "${keyvault}" --keyvault_subscription "${STATE_SUBSCRIPTION}" --subscription "${ARM_SUBSCRIPTION_ID}" --msi

        if [ -f secret.err ]; then
            error_message=$(cat secret.err)
            echo "##vso[task.logissue type=error]${error_message}"
            rm secret.err
            exit 65
        fi
    fi
else
    if [ -n "${keyvault}" ]; then
        echo "Setting the secrets"

        save_config_var "client_id" "${backup_config_information}"
        save_config_var "tenant_id" "${backup_config_information}"

        if [ -n "$client_secret" ]; then
            fixed_allParameters=$(printf " --backup --environment %s --region %s --vault %s  --subscription %s --spn_secret ***** --keyvault_subscription %s --spn_id %s --tenant_id %s " "${environment}" "${region_code}" "${keyvault}" "${ARM_SUBSCRIPTION_ID}" "${STATE_SUBSCRIPTION}" "${client_id}" "${tenant_id}")

            echo "Calling set_secrets with:             ${fixed_allParameters}"

            "${SAP_AUTOMATION_REPO_PATH}/deploy/scripts/set_secrets.sh" --backup --environment "${environment}" --region "${region_code}" --vault "${keyvault}" --subscription "$ARM_SUBSCRIPTION_ID" --keyvault_subscription "${STATE_SUBSCRIPTION}" --spn_id "${client_id}" --tenant_id "${tenant_id}" --spn_secret "${client_secret}"

            if [ -f secret.err ]; then
                error_message=$(cat secret.err)
                echo "##vso[task.logissue type=error]${error_message}"
                exit 65
            fi
        else
            read -r -p "Do you want to specify the Backup SPN Details Y/N? " ans
            answer=${ans^^}
            if [ "${answer}" == 'Y' ]; then
                allParameters=$(printf " --backup --environment %s --region %s --vault %s --subscription %s  --spn_id %s " "${environment}" "${region_code}" "${keyvault}" "${STATE_SUBSCRIPTION}" "${client_id}")

                "${SAP_AUTOMATION_REPO_PATH}/deploy/scripts/set_secrets.sh ${allParameters}"
                if [ $? -eq 255 ]; then
                    exit $?
                fi
            fi
        fi

        if [ -f kv.log ]; then
            rm kv.log
        fi
    fi
fi

if [ -z "${deployer_tfstate_key}" ]; then
    load_config_vars "${backup_config_information}" "deployer_tfstate_key"
    if [ -n "${deployer_tfstate_key}" ]; then
        # Deployer state was specified in $CONFIG_REPO_PATH/.sap_deployment_automation library config
        deployer_tfstate_key_parameter=" -var deployer_tfstate_key=${deployer_tfstate_key}"
        export TF_VAR_deployer_tfstate_key_parameter=${deployer_tfstate_key}
    fi
else
    deployer_tfstate_key_parameter=" -var deployer_tfstate_key=${deployer_tfstate_key}"
    export TF_VAR_deployer_tfstate_key_parameter=${deployer_tfstate_key}
    save_config_vars "${backup_config_information}" deployer_tfstate_key
fi

if [ -z "${REMOTE_STATE_SA}" ]; then
    read -r -p "Terraform state storage account name: " REMOTE_STATE_SA
    getAndStoreTerraformStateStorageAccountDetails "${REMOTE_STATE_SA}" "${backup_config_information}"
    load_config_vars "${backup_config_information}" "STATE_SUBSCRIPTION"
    load_config_vars "${backup_config_information}" "REMOTE_STATE_RG"
    load_config_vars "${backup_config_information}" "tfstate_resource_id"

    tfstate_parameter=" -var tfstate_resource_id=${tfstate_resource_id}"
    export TF_VAR_tfstate_resource_id=${tfstate_resource_id}

    if [ -n "${STATE_SUBSCRIPTION}" ]; then
        if [ "$account_set" == 0 ]; then
            az account set --sub "${STATE_SUBSCRIPTION}"
            account_set=1
        fi
    fi
fi

if [ -z "${REMOTE_STATE_RG}" ]; then
    if [ -n "${REMOTE_STATE_SA}" ]; then
        getAndStoreTerraformStateStorageAccountDetails "${REMOTE_STATE_SA}" "${backup_config_information}"
        load_config_vars "${backup_config_information}" "STATE_SUBSCRIPTION"
        load_config_vars "${backup_config_information}" "REMOTE_STATE_RG"
        load_config_vars "${backup_config_information}" "tfstate_resource_id"

        tfstate_parameter=" -var tfstate_resource_id=${tfstate_resource_id}"
    else
        option="REMOTE_STATE_RG"
        read -r -p "Remote state resource group name: " REMOTE_STATE_RG
        save_config_vars "${backup_config_information}" REMOTE_STATE_RG
    fi
fi

if [ -n "${tfstate_resource_id}" ]; then
    tfstate_parameter=" -var tfstate_resource_id=${tfstate_resource_id}"
    export TF_VAR_tfstate_resource_id=${tfstate_resource_id}
else
    getAndStoreTerraformStateStorageAccountDetails "${REMOTE_STATE_SA}" "${backup_config_information}"
    load_config_vars "${backup_config_information}" "tfstate_resource_id"
    tfstate_parameter=" -var tfstate_resource_id=${tfstate_resource_id}"
    export TF_VAR_tfstate_resource_id=${tfstate_resource_id}
fi

terraform_module_directory="$(realpath "${SAP_AUTOMATION_REPO_PATH}"/deploy/terraform/run/"${deployment_system}")"

if [ ! -d "${terraform_module_directory}" ]; then
    printf -v val %-40.40s "$deployment_system"
    echo "#########################################################################################"
    echo "#                                                                                       #"
    echo -e "#  $bold_red Incorrect system deployment type specified: ${val}$reset_formatting#"
    echo "#                                                                                       #"
    echo "#     Valid options are:                                                                #"
    echo "#       sap_backup                                                                      #"
    echo "#                                                                                       #"
    echo "#########################################################################################"
    echo ""
    exit 1
fi

apply_needed=false

echo ""
echo "Terraform details"
echo "-------------------------------------------------------------------------"
echo "Subscription:                        ${STATE_SUBSCRIPTION}"
echo "Storage Account:                     ${REMOTE_STATE_SA}"
echo "Resource Group:                      ${REMOTE_STATE_RG}"
echo "State file:                          ${tfstate_backup}"
echo "Target subscription:                 $ARM_SUBSCRIPTION_ID"

TF_VAR_subscription_id="$ARM_SUBSCRIPTION_ID"
export TF_VAR_subscription_id

# Set Terraform variables
export TF_VAR_backup_configuration_name="${backup_configuration_name}"

printf "%s\n" ""
printf "%s\n" "#########################################################################################"
printf "%s\n" "#                                                                                       #"
printf "%s\n" "#                                    Initialization                                     #"
printf "%s\n" "#                                                                                       #"
printf "%s\n" "#########################################################################################"

# Initialize Terraform
init_ret_code=0
echo "Initializing Terraform for backup deployment..."

if [ ! -d .terraform/ ]; then
    if ! terraform -chdir="${terraform_module_directory}" init -upgrade=true \
        --backend-config "subscription_id=${STATE_SUBSCRIPTION}" \
        --backend-config "resource_group_name=${REMOTE_STATE_RG}" \
        --backend-config "storage_account_name=${REMOTE_STATE_SA}" \
        --backend-config "container_name=tfstate" \
        --backend-config "key=${tfstate_backup}"; then
        return_value=$?
        echo ""
        echo -e "${bold_red}Terraform init:                        failed$reset_formatting"
        echo ""
        exit $return_value
    else
        return_value=0
        echo ""
        echo -e "${cyan}Terraform init:                        succeeded$reset_formatting"
        echo ""
    fi
else
    check_output=1
    local_backend=$(grep "\"type\": \"local\"" .terraform/terraform.tfstate || true)
    if [ -n "${local_backend}" ]; then
        if ! terraform -chdir="${terraform_module_directory}" init -upgrade=true -force-copy \
            --backend-config "subscription_id=${STATE_SUBSCRIPTION}" \
            --backend-config "resource_group_name=${REMOTE_STATE_RG}" \
            --backend-config "storage_account_name=${REMOTE_STATE_SA}" \
            --backend-config "container_name=tfstate" \
            --backend-config "key=${tfstate_backup}"; then
            return_value=$?
            echo ""
            echo -e "${bold_red}Terraform init:                        failed$reset_formatting"
            echo ""
            exit $return_value
        else
            return_value=0
            echo ""
            echo -e "${cyan}Terraform init:                        succeeded$reset_formatting"
            echo ""
        fi
    else
        if ! terraform -chdir="${terraform_module_directory}" init -upgrade=true; then
            return_value=$?
            echo ""
            echo -e "${bold_red}Terraform init:                        failed$reset_formatting"
            echo ""
            exit $return_value
        else
            return_value=0
            echo ""
            echo -e "${cyan}Terraform init:                        succeeded$reset_formatting"
            echo ""
        fi
    fi
fi

if [ 0 != $return_value ]; then
    echo "#########################################################################################"
    echo "#                                                                                       #"
    echo -e "#                            $bold_red_underscore!!! Error when Initializing !!!$reset_formatting                            #"
    echo "#                                                                                       #"
    echo "#########################################################################################"
    echo ""
    echo "Terraform initialization failed"
    exit $return_value
fi

if ! terraform -chdir="${terraform_module_directory}" output | grep "No outputs"; then
    check_output=1
else
    check_output=0
fi

save_config_var "REMOTE_STATE_SA" "${backup_config_information}"
save_config_var "subscription" "${backup_config_information}"
save_config_var "STATE_SUBSCRIPTION" "${backup_config_information}"
save_config_var "tfstate_resource_id" "${backup_config_information}"

allParameters=$(printf " -var-file=%s %s %s %s " "${var_file}" "${extra_vars}" "${tfstate_parameter}" "${deployer_tfstate_key_parameter}")

if [ 1 == $check_output ]; then
    if terraform -chdir="${terraform_module_directory}" output | grep "No outputs"; then
        check_output=0
        apply_needed=1
        echo "#########################################################################################"
        echo "#                                                                                       #"
        echo -e "#                                  $cyan New deployment $reset_formatting                                     #"
        echo "#                                                                                       #"
        echo "#########################################################################################"
    else
        echo ""
        echo "#########################################################################################"
        echo "#                                                                                       #"
        echo -e "#                          $cyan Existing deployment was detected $reset_formatting                           #"
        echo "#                                                                                       #"
        echo "#########################################################################################"
        echo ""

        deployed_using_version=$(terraform -chdir="${terraform_module_directory}" output -no-color -raw automation_version)
        if [ -z "${deployed_using_version}" ]; then
            echo ""
            echo "#########################################################################################"
            echo "#                                                                                       #"
            echo -e "#   $bold_red The environment was deployed using an older version of the Terraform templates $reset_formatting    #"
            echo "#                                                                                       #"
            echo "#                               !!! Risk for Data loss !!!                              #"
            echo "#                                                                                       #"
            echo "#        Please inspect the output of Terraform plan carefully before proceeding        #"
            echo "#                                                                                       #"
            echo "#########################################################################################"
            if [ 1 == $called_from_ado ]; then
                unset TF_DATA_DIR
                echo "The environment was deployed using an older version of the Terraform templates, Risk for data loss" >"${backup_config_information}".err
                exit 1
            fi

            read -r -p "Do you want to continue Y/N? " ans
            answer=${ans^^}
            if [ "$answer" == 'Y' ]; then
                apply_needed=1
            else
                unset TF_DATA_DIR
                exit 1
            fi
        else
            printf -v val %-.20s "$deployed_using_version"
            echo ""
            echo "#########################################################################################"
            echo "#                                                                                       #"
            echo -e "#             $cyan Deployed using the Terraform templates version: $val $reset_formatting               #"
            echo "#                                                                                       #"
            echo "#########################################################################################"
            echo ""
        fi
    fi
fi

export TF_VAR_tfstate_resource_id="${tfstate_resource_id}"
export TF_VAR_subscription="${subscription}"
export TF_VAR_management_subscription="${STATE_SUBSCRIPTION}"

printf "%s\n" ""
printf "%s\n" "#########################################################################################"
printf "%s\n" "#                                                                                       #"
printf "%s\n" "#                                      Planning                                         #"
printf "%s\n" "#                                                                                       #"
printf "%s\n" "#########################################################################################"

# Generate Terraform plan
plan_ret_code=0
echo "Creating Terraform plan for backup infrastructure..."

# shellcheck disable=SC2086
if ! terraform -chdir="$terraform_module_directory" plan -detailed-exitcode $allParameters -input=false | tee plan_output.log; then
    return_value=${PIPESTATUS[0]}
else
    return_value=${PIPESTATUS[0]}
fi

if [ $return_value -eq 1 ]; then
    echo ""
    echo -e "${bold_red}Terraform plan:                        failed$reset_formatting"
    echo ""
    echo "#########################################################################################"
    echo "#                                                                                       #"
    echo -e "#                           $bold_red_underscore !!! Error when running plan !!! $reset_formatting                           #"
    echo "#                                                                                       #"
    echo "#########################################################################################"
    echo ""
    if [ -f plan_output.log ]; then
        rm plan_output.log
    fi
    exit $return_value
else
    echo ""
    echo -e "${cyan}Terraform plan:                        succeeded$reset_formatting"
    echo ""
fi

if [ $check_output == 0 ]; then
    if [ -f plan_output.log ]; then
        rm plan_output.log
    fi
    return_code=2
fi

echo "Terraform Plan return code:          $return_value"
apply_needed=1

if [ "${TEST_ONLY}" == "True" ]; then
    echo ""
    echo "#########################################################################################"
    echo "#                                                                                       #"
    echo -e "#                                 $cyan Running plan only. $reset_formatting                                  #"
    echo "#                                                                                       #"
    echo "#                                  No deployment performed.                             #"
    echo "#                                                                                       #"
    echo "#########################################################################################"
    echo ""
    if [ -f plan_output.log ]; then
        rm plan_output.log
    fi
    exit 0
fi

if [ -f plan_output.log ]; then
    cat plan_output.log
    LASTERROR=$(grep -m1 'Error: ' plan_output.log || true)

    if [ -n "${LASTERROR}" ]; then
        if [ 1 == $called_from_ado ]; then
            echo "##vso[task.logissue type=error]$LASTERROR"
        fi
        return_value=1
    fi

    if [ 1 != $return_value ]; then
        test=$(grep -m1 "replaced" plan_output.log | grep backup || true)
        if [ -n "${test}" ]; then
            echo ""
            echo "#########################################################################################"
            echo "#                                                                                       #"
            echo -e "#                              $bold_red !!! Risk for Data loss !!! $reset_formatting                             #"
            echo "#                                                                                       #"
            echo "#        Please inspect the output of Terraform plan carefully before proceeding        #"
            echo "#                                                                                       #"
            echo "#########################################################################################"
            echo ""
            if [ 1 == $called_from_ado ]; then
                unset TF_DATA_DIR
                exit 11
            fi
            read -n 1 -r -s -p $'Press enter to continue...\n'

            cat plan_output.log
            read -r -p "Do you want to continue with the deployment Y/N? " ans
            answer=${ans^^}
            if [ "${answer}" == 'Y' ]; then
                apply_needed=1
            else
                unset TF_DATA_DIR
                exit 0
            fi
        else
            apply_needed=1
        fi
    fi
fi

if [ 0 == $return_value ]; then
    if ! terraform -chdir="${terraform_module_directory}" output | grep "No outputs"; then
        # Save backup configuration state
        save_config_vars "backup_tfstate_key" "${backup_config_information}"
    fi
fi

printf "%s\n" ""
printf "%s\n" "#########################################################################################"
printf "%s\n" "#                                                                                       #"
printf "%s\n" "#                                      Deployment                                       #"
printf "%s\n" "#                                                                                       #"
printf "%s\n" "#########################################################################################"

# Apply Terraform plan
if [ 1 == $apply_needed ]; then
    echo ""
    echo "#########################################################################################"
    echo "#                                                                                       #"
    echo -e "#                            $cyan Running Terraform apply $reset_formatting                                  #"
    echo "#                                                                                       #"
    echo "#########################################################################################"
    echo ""

    parallelism=10

    #Provide a way to limit the number of parallel tasks for Terraform
    if [[ -n "${TF_PARALLELLISM}" ]]; then
        parallelism=$TF_PARALLELLISM
    fi

    allImportParameters=$(printf " -var-file=%s %s %s %s" "${var_file}" "${extra_vars}" "${tfstate_parameter}" "${deployer_tfstate_key_parameter}")

    # shellcheck disable=SC2086
    if [ -n "${approve}" ]; then
        # Using if so that no zero return codes don't fail -o errexit
        if ! terraform -chdir="${terraform_module_directory}" apply "${approve}" -parallelism="${parallelism}" -no-color -json $allParameters -input=false | tee apply_output.json; then
            return_value=${PIPESTATUS[0]}
        else
            return_value=${PIPESTATUS[0]}
        fi
        echo    "Return value:                        $return_value"
        if [ $return_value -eq 1 ]; then
            echo ""
            echo -e "${bold_red}Terraform apply:                       failed$reset_formatting"
            echo ""
            exit $return_value
        else
            # return code 2 is ok
            echo ""
            echo -e "${cyan}Terraform apply:                     succeeded$reset_formatting"
            echo ""
            return_value=0
        fi
    else
        # Using if so that no zero return codes don't fail -o errexit
        terraform -chdir="${terraform_module_directory}" apply -parallelism="${parallelism}" $allParameters
        return_value=$?

        echo    "Return value:                        $return_value"
        if [ $return_value -ne 1 ]; then
            echo ""
            echo -e "${cyan}Terraform apply:                     succeeded$reset_formatting"
            echo ""
        else
            echo ""
            echo -e "${bold_red}Terraform apply:                       failed$reset_formatting"
            echo ""
            exit $return_value
        fi
    fi

    if [ -f apply_output.json ]; then
        errors_occurred=$(jq 'select(."@level" == "error") | length' apply_output.json)

        if [[ -n $errors_occurred ]]; then
            return_value=10
            if [ -n "${approve}" ]; then
                echo -e "${cyan}Retrying Terraform apply:$reset_formatting"

                # shellcheck disable=SC2086
                if ! ImportAndReRunApply "apply_output.json" "${terraform_module_directory}" "$allImportParameters" "$allParameters" $parallelism; then
                    return_value=$?
                fi

                sleep 10

                if [ -f apply_output.json ]; then
                    echo -e "${cyan}Retrying Terraform apply:$reset_formatting"
                    # shellcheck disable=SC2086
                    if ! ImportAndReRunApply "apply_output.json" "${terraform_module_directory}" "$allImportParameters" "$allParameters" $parallelism; then
                        return_value=$?
                    fi
                fi
            else
                return_value=10
            fi
        fi
    fi

    if [ -f apply_output.json ]; then
        rm apply_output.json
    fi

    echo "Backup infrastructure deployment completed successfully"

    # Output deployment summary
    echo "Getting deployment outputs..."

    if ! terraform -chdir="${terraform_module_directory}" output | grep "No outputs"; then
        # Save backup configuration state
        save_config_var "backup_tfstate_key" "${backup_config_information}"
    fi

    if [ -f plan_output.log ]; then
        rm plan_output.log
    fi
else
    echo "No changes to apply for backup infrastructure"
fi

save_config_var "backup_tfstate_key" "${backup_config_information}"

if ! terraform -chdir="${terraform_module_directory}" output | grep "No outputs"; then
    backup_vault_name=$(terraform -chdir="${terraform_module_directory}" output -no-color -raw recovery_services_vault_name | tr -d \")
    backup_policy_name=$(terraform -chdir="${terraform_module_directory}" output -no-color -raw backup_policy_name | tr -d \")
    backup_resource_group=$(terraform -chdir="${terraform_module_directory}" output -no-color -raw backup_resource_group_name | tr -d \")

    if [ -n "${backup_vault_name}" ] && [ "${backup_vault_name}" != "null" ]; then
        save_config_var "backup_vault_name" "${backup_config_information}"
        printf -v val %-.40s "$backup_vault_name"
        echo ""
        echo "#########################################################################################"
        echo "#                                                                                       #"
        echo -e "#             Recovery Services Vault:         $cyan $val $reset_formatting               #"
        echo "#                                                                                       #"
        echo "#########################################################################################"
        echo ""
    fi

    if [ -n "${backup_policy_name}" ] && [ "${backup_policy_name}" != "null" ]; then
        save_config_var "backup_policy_name" "${backup_config_information}"
    fi

    if [ -n "${backup_resource_group}" ] && [ "${backup_resource_group}" != "null" ]; then
        save_config_var "backup_resource_group" "${backup_config_information}"
    fi
fi

if [ 0 != $return_value ]; then
    unset TF_DATA_DIR
    exit $return_value
fi

printf "%s\n" ""
printf "%s\n" "#########################################################################################"
printf "%s\n" "#                                                                                       #"
printf "%s\n" "#                              Backup Infrastructure Deployed                           #"
printf "%s\n" "#                                                                                       #"
printf "%s\n" "#########################################################################################"

echo ""
echo "#########################################################################################"
echo "#                                                                                       #"
echo -e "#                            $cyan Creating deployment summary $reset_formatting                               #"
echo "#                                                                                       #"
echo "#########################################################################################"
echo ""

full_script_path="$(realpath "${BASH_SOURCE[0]}")"
script_directory="$(dirname "${full_script_path}")"

if [ -n "${backup_resource_group}" ]; then
    az deployment group create --resource-group "${backup_resource_group}" --name "SAP-BACKUP-INFRASTRUCTURE_${backup_resource_group}" --subscription "$ARM_SUBSCRIPTION_ID" \
        --template-file "${script_directory}/templates/empty-deployment.json" --output none --only-show-errors --no-wait
fi

now=$(date)
cat <<EOF >"${backup_configuration_name}".md
# SAP Backup Infrastructure Deployment #

Date : "${now}"

## Configuration details ##

| Item                    | Name                     |
| ----------------------- | ------------------------ |
| Environment             | $environment             |
| Location                | $region                  |
| Backup Configuration    | ${backup_configuration_name} |
| Recovery Services Vault | ${backup_vault_name}     |
| Backup Policy           | ${backup_policy_name}    |

EOF

if [ -n "${backup_vault_name}" ]; then
    printf -v vaultname '%-40s' "${backup_vault_name}"
    echo ""
    echo "#########################################################################################"
    echo "#                                                                                       #"
    echo -e "# $cyan Please save these values: $reset_formatting                                                           #"
    echo "#     - Recovery Services Vault: ${vaultname}                       #"
    echo "#                                                                                       #"
    echo "#########################################################################################"
fi

if [ -f "${backup_config_information}".err ]; then
    cat "${backup_config_information}".err
fi

unset TF_DATA_DIR

#################################################################################
#                                                                               #
#                           Copy tfvars to storage account                      #
#                                                                               #
#                                                                               #
#################################################################################

if [ "$useSAS" = "true" ]; then
    container_exists=$(az storage container exists --subscription "${STATE_SUBSCRIPTION}" --account-name "${REMOTE_STATE_SA}" --name tfvars --only-show-errors --query exists)
else
    container_exists=$(az storage container exists --subscription "${STATE_SUBSCRIPTION}" --account-name "${REMOTE_STATE_SA}" --name tfvars --only-show-errors --query exists --auth-mode login)
fi

if [ "${container_exists}" == "false" ]; then
    if [ "$useSAS" = "true" ]; then
        az storage container create --subscription "${STATE_SUBSCRIPTION}" --account-name "${REMOTE_STATE_SA}" --name tfvars --only-show-errors
    else
        az storage container create --subscription "${STATE_SUBSCRIPTION}" --account-name "${REMOTE_STATE_SA}" --name tfvars --auth-mode login --only-show-errors
    fi
fi

backup_config_key=$(echo "${backup_configuration_name}" | cut -d. -f1)

if [ "$useSAS" = "true" ]; then
    az storage blob upload --file "${parameterfile}" --container-name tfvars/BACKUP/"${backup_config_key}" --name "${backup_file_parametername}" \
        --subscription "${STATE_SUBSCRIPTION}" --account-name "${REMOTE_STATE_SA}" --no-progress --overwrite --only-show-errors --output none
else
    az storage blob upload --file "${parameterfile}" --container-name tfvars/BACKUP/"${backup_config_key}" --name "${backup_file_parametername}" \
        --subscription "${STATE_SUBSCRIPTION}" --account-name "${REMOTE_STATE_SA}" --no-progress --overwrite --auth-mode login --only-show-errors --output none
fi

echo "Backup infrastructure deployment completed."
echo "Next steps:"
echo "1. Configure HANA backup agent on target SAP systems"
echo "2. Register SAP systems with the Recovery Services Vault: ${backup_vault_name}"
echo "3. Configure backup schedules as per the deployed policy: ${backup_policy_name}"

exit $return_value

# Function to show help
showhelp() {
    echo ""
    echo "#########################################################################################"
    echo "#                                                                                       #"
    echo "#                               SAP Backup Infrastructure                               #"
    echo "#                                                                                       #"
    echo "#########################################################################################"
    echo ""
    echo "This script deploys backup infrastructure for SAP workloads using Azure Backup."
    echo ""
    echo "Usage: install_backup.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --parameterfile PARAMETERFILE        Terraform variables file"
    echo "  -d, --deployer_tfstate_key TFSTATE_KEY   Deployer Terraform state file key"
    echo "  -e, --deployer_environment ENVIRONMENT   Deployer environment name"
    echo "  -k, --keyvault KEYVAULT                   Key vault name for secrets"
    echo "  -o, --storageaccountname STORAGE_ACCOUNT Storage account for Terraform state"
    echo "  -s, --state_subscription SUBSCRIPTION    Subscription for Terraform state"
    echo "  -c, --subscription SUBSCRIPTION          Target subscription for deployment"
    echo "  -n, --spn_id SPN_ID                      Service Principal ID"
    echo "  -t, --tenant_id TENANT_ID                Tenant ID"
    echo "  -v, --spn_secret SPN_SECRET              Service Principal secret"
    echo "  -a, --ado                                Called from Azure DevOps"
    echo "  -i, --auto-approve                       Automatically approve Terraform apply"
    echo "  -f, --force                              Force deployment even if no changes"
    echo "  -m, --msi                                Use Managed Service Identity"
    echo "  -h, --help                               Show this help message"
    echo ""
    echo "Example:"
    echo "  install_backup.sh -p backup.tfvars -i"
    echo ""
}
