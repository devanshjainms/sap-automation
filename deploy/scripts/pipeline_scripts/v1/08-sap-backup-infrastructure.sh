#!/bin/bash
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

green="\e[1;32m"
reset="\e[0m"
bold_red="\e[1;31m"

# External helper functions
full_script_path="$(realpath "${BASH_SOURCE[0]}")"
script_directory="$(dirname "${full_script_path}")"
parent_directory="$(dirname "$script_directory")"
grand_parent_directory="$(dirname "$parent_directory")"

SCRIPT_NAME="$(basename "$0")"
banner_title="Deploy SAP Backup Infrastructure"

#call stack has full script name when using source
# shellcheck disable=SC1091
source "${grand_parent_directory}/deploy_utils.sh"

#call stack has full script name when using source
source "${parent_directory}/helper.sh"

echo "##vso[build.updatebuildnumber]Deploying the SAP Backup Infrastructure defined in $BACKUP_CONFIGURATION_FOLDERNAME"
print_banner "$banner_title" "Starting $SCRIPT_NAME" "info"

DEBUG=False

if [ "$SYSTEM_DEBUG" = True ]; then
	set -x
	DEBUG=True
	echo "Environment variables:"
	printenv | sort
fi
export DEBUG
set -eu

# Print the execution environment details
print_header

# Configure DevOps
configure_devops

# Check if running on deployer
if [[ ! -f /etc/profile.d/deploy_server.sh ]]; then
	configureNonDeployer "${tf_version:-1.12.2}"
fi
configure_devops

# Set logon variables
if [ $USE_MSI == "true" ]; then
	unset ARM_CLIENT_SECRET
	ARM_USE_MSI=true
	export ARM_USE_MSI
fi

if [[ ! -f /etc/profile.d/deploy_server.sh ]]; then
	configureNonDeployer "${tf_version:-1.12.2}"
fi

if az account show --query name; then
	echo -e "$green--- Already logged in to Azure ---$reset"
else
	# Check if running on deployer
	echo -e "$green--- az login ---$reset"
	LogonToAzure $USE_MSI
	return_code=$?
	if [ 0 != $return_code ]; then
		echo -e "$bold_red--- Login failed ---$reset"
		echo "##vso[task.logissue type=error]az login failed."
		exit $return_code
	fi
fi

if ! get_variable_group_id "$VARIABLE_GROUP" "VARIABLE_GROUP_ID" ; then
	echo -e "$bold_red--- Variable group $VARIABLE_GROUP not found ---$reset"
	echo "##vso[task.logissue type=error]Variable group $VARIABLE_GROUP not found."
	exit 2
fi
export VARIABLE_GROUP_ID

tfvarsFile="BACKUP/$BACKUP_CONFIGURATION_FOLDERNAME/$BACKUP_CONFIGURATION_FOLDERNAME.tfvars"

cd "${CONFIG_REPO_PATH}" || exit
mkdir -p .sap_deployment_automation
git checkout -q "$BUILD_SOURCEBRANCHNAME"

if [ ! -f "$CONFIG_REPO_PATH/$tfvarsFile" ]; then
	print_banner "$banner_title" "$BACKUP_CONFIGURATION_FOLDERNAME.tfvars was not found" "error"
	echo "##vso[task.logissue type=error]File $BACKUP_CONFIGURATION_FOLDERNAME.tfvars was not found."
	exit 2
fi

BACKUP_CONFIGURATION_NAME=$(echo $BACKUP_CONFIGURATION_FOLDERNAME)


ENVIRONMENT=$(grep -m1 "^environment" "$tfvarsFile" | awk -F'=' '{print $2}' | tr -d ' \t\n\r\f"')
LOCATION=$(grep -m1 "^location" "$tfvarsFile" | awk -F'=' '{print $2}' | tr '[:upper:]' '[:lower:]' | tr -d ' \t\n\r\f"')
NETWORK=$(grep -m1 "^network_logical_name" "$tfvarsFile" | awk -F'=' '{print $2}' | tr -d ' \t\n\r\f"')

# If environment is not in tfvars, extract from backup configuration name
if [ -z "$ENVIRONMENT" ]; then
	ENVIRONMENT=$(echo "$BACKUP_CONFIGURATION_NAME" | cut -d'-' -f1)
fi


ENVIRONMENT_IN_FILENAME=$(echo $BACKUP_CONFIGURATION_FOLDERNAME | awk -F'-' '{print $1}')
LOCATION_CODE_IN_FILENAME=$(echo $BACKUP_CONFIGURATION_FOLDERNAME | awk -F'-' '{print $2}')
NETWORK_IN_FILENAME=$(echo $BACKUP_CONFIGURATION_FOLDERNAME | awk -F'-' '{print $3}')

get_region_code "$LOCATION"

echo "Backup Configuration Name: $BACKUP_CONFIGURATION_NAME"
echo "Environment: $ENVIRONMENT"
echo "Location: $LOCATION"
echo "Region code: $region_code"

# Set up configuration directories
automation_config_directory="$CONFIG_REPO_PATH/.sap_deployment_automation"
generic_config_information="$automation_config_directory/config"
backup_config_information="$automation_config_directory/${ENVIRONMENT}${region_code}BACKUP"

key="$BACKUP_CONFIGURATION_NAME"
deployer_environment="${DEPLOYER_ENVIRONMENT:-MGMT}"
deployer_config_information="$automation_config_directory/${deployer_environment}${region_code}"

echo "Backup Configuration file: $backup_config_information"
echo "Deployer Configuration file: $deployer_config_information"

# Load deployer configuration
if [ -f "$deployer_config_information" ]; then
	echo "Loading deployer configuration from $deployer_config_information"
	# Source the deployer configuration to get keyvault and state info
	source "$deployer_config_information" || true
fi

# Set up Terraform state file name
tfstate_backup="${BACKUP_CONFIGURATION_NAME}.terraform.tfstate"

echo ""
print_banner "$banner_title" "Deploying backup infrastructure" "info"

# Change to the tfvars file directory
config_file_dir=$(dirname "$CONFIG_REPO_PATH/$tfvarsFile")
cd "$config_file_dir" || exit

if [ "$TEST_ONLY" == "True" ]; then
	export TEST_ONLY
	echo "##vso[task.logissue type=warning]Test only deployment, not applying changes"
fi

extra_params=""
if [ -n "${KEYVAULT:-}" ]; then
	extra_params="$extra_params -v $KEYVAULT"
fi

if [ -n "${TERRAFORM_STATE_STORAGE_ACCOUNT:-}" ]; then
	extra_params="$extra_params -o $TERRAFORM_STATE_STORAGE_ACCOUNT"
fi

if [ -n "${ARM_SUBSCRIPTION_ID:-}" ]; then
	extra_params="$extra_params -c $ARM_SUBSCRIPTION_ID"
fi

if [ -n "${deployer_environment:-}" ]; then
	extra_params="$extra_params -e $deployer_environment"
fi

if [ "$USE_MSI" == "true" ]; then
	extra_params="$extra_params -m"
fi

# Auto-approve in pipeline
extra_params="$extra_params -i"

echo ""
echo "##vso[section]Installing SAP Backup Infrastructure"
echo ""
echo "Calling install_backup.sh with parameters:"
echo "  Parameter file: $BACKUP_CONFIGURATION_FOLDERNAME.tfvars"
echo "  Extra parameters: $extra_params"
echo ""

# Add deployer tfstate key retrieval
deployer_tfstate_key=$(getVariableFromVariableGroup "${VARIABLE_GROUP_ID}" "DEPLOYER_STATE_FILENAME" "${backup_config_information}" "deployer_tfstate_key")
export deployer_tfstate_key

# Add terraform storage account details
Terraform_Remote_Storage_Account_Name=$(getVariableFromVariableGroup "${VARIABLE_GROUP}" "TERRAFORM_STATE_STORAGE_ACCOUNT" "${backup_config_information}" "REMOTE_STATE_SA")
terraform_storage_account_subscription_id=$(getVariableFromVariableGroup "${VARIABLE_GROUP}" "ARM_SUBSCRIPTION_ID" "${backup_config_information}" "STATE_SUBSCRIPTION")

# Call the install_backup.sh script
if "$SAP_AUTOMATION_REPO_PATH/deploy/scripts/installer.sh" --parameterfile "$BACKUP_CONFIGURATION_FOLDERNAME.tfvars" --type sap_backup \
    --deployer_tfstate_key "${deployer_tfstate_key}" --storageaccountname "$TERRAFORM_STATE_STORAGE_ACCOUNT"  \
    --state_subscription "${terraform_storage_account_subscription_id}" \
    --ado --auto-approve ; then
	return_code=$?
	print_banner "$banner_title" "Deployment of $BACKUP_CONFIGURATION_NAME completed successfully" "success"
else
	return_code=$?
	print_banner "$banner_title" "Deployment of $BACKUP_CONFIGURATION_NAME failed" "error"
	echo -e "$bold_red--- Deployment failed ---$reset"
	echo "##vso[task.logissue type=error]Deployment failed."
fi
echo "Return code from deployment:         ${return_code}"

return_code=$?

if [ 0 != $return_code ]; then
	echo "##vso[task.logissue type=error]Backup infrastructure deployment failed."
	print_banner "$banner_title" "Backup infrastructure deployment failed" "error"
else
	echo "##vso[task.logissue type=info]Backup infrastructure deployment completed successfully."
	print_banner "$banner_title" "Backup infrastructure deployment completed" "success"
fi

cd "${CONFIG_REPO_PATH}" || exit

git config --global user.email "$BUILD_REQUESTEDFOREMAIL"
git config --global user.name "$BUILD_REQUESTEDFOR"
git add -A

if [ -n "$(git status --porcelain)" ]; then
	echo "##vso[section]Updating configuration repository"
	git commit -m "Added backup configuration updates from backup infrastructure deployment [$BUILD_BUILDNUMBER] ***NO_CI***"

	echo "##vso[section]Pushing changes to configuration repository"
	git -c http.extraheader="AUTHORIZATION: bearer $SYSTEM_ACCESSTOKEN" push
fi

exit $return_code
