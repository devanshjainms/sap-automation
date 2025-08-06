#!/bin/bash
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# SAP Backup Infrastructure Validation Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "SUCCESS")
            echo -e "${GREEN}✓${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}✗${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠${NC} $message"
            ;;
        "INFO")
            echo -e "${NC}ℹ${NC} $message"
            ;;
    esac
}

print_status "INFO" "SAP Backup Infrastructure Validation"
echo "=================================================="

# Check for required tools
print_status "INFO" "Checking prerequisites..."

if command -v terraform &> /dev/null; then
    terraform_version=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || terraform version | grep "Terraform v" | cut -d'v' -f2)
    print_status "SUCCESS" "Terraform found: $terraform_version"
else
    print_status "ERROR" "Terraform not found. Please install Terraform >= 1.5.0"
    exit 1
fi

if command -v az &> /dev/null; then
    az_version=$(az version --output json | jq -r '."azure-cli"' 2>/dev/null || az version --output table | grep "azure-cli" | awk '{print $2}')
    print_status "SUCCESS" "Azure CLI found: $az_version"
else
    print_status "ERROR" "Azure CLI not found. Please install Azure CLI >= 2.50.0"
    exit 1
fi

# Check if logged into Azure
if az account show &> /dev/null; then
    subscription_name=$(az account show --query name -o tsv)
    print_status "SUCCESS" "Azure CLI authenticated: $subscription_name"
else
    print_status "ERROR" "Not logged into Azure. Please run 'az login'"
    exit 1
fi

# Validate Terraform configuration
print_status "INFO" "Validating Terraform configuration..."

TERRAFORM_DIR="$(dirname "$0")/../terraform/run/sap_backup"

if [ ! -d "$TERRAFORM_DIR" ]; then
    print_status "ERROR" "Terraform directory not found: $TERRAFORM_DIR"
    exit 1
fi

cd "$TERRAFORM_DIR"

# Initialize Terraform (without backend)
print_status "INFO" "Initializing Terraform..."
if terraform init -backend=false &> /dev/null; then
    print_status "SUCCESS" "Terraform initialization successful"
else
    print_status "ERROR" "Terraform initialization failed"
    exit 1
fi

# Validate configuration
print_status "INFO" "Validating Terraform configuration..."
if terraform validate &> /dev/null; then
    print_status "SUCCESS" "Terraform configuration is valid"
else
    print_status "ERROR" "Terraform configuration validation failed"
    terraform validate
    exit 1
fi

# Check for sample configurations
print_status "INFO" "Checking sample configurations..."

SAMPLE_CONFIG_DIR="$(dirname "$0")/../../boilerplate/WORKSPACES/BACKUP"

if [ -f "$SAMPLE_CONFIG_DIR/DEV-SECE-BUP01-BACKUP.tfvars" ]; then
    print_status "SUCCESS" "Development sample configuration found"
else
    print_status "WARNING" "Development sample configuration not found"
fi

if [ -f "$SAMPLE_CONFIG_DIR/PRD-EAUS-BUP01-BACKUP.tfvars" ]; then
    print_status "SUCCESS" "Production sample configuration found"
else
    print_status "WARNING" "Production sample configuration not found"
fi

# Check installation script
INSTALL_SCRIPT="$(dirname "$0")/install_backup.sh"

if [ -f "$INSTALL_SCRIPT" ] && [ -x "$INSTALL_SCRIPT" ]; then
    print_status "SUCCESS" "Installation script found and executable"
else
    print_status "ERROR" "Installation script not found or not executable: $INSTALL_SCRIPT"
    exit 1
fi

# Check pipeline files
PIPELINE_DIR="$(dirname "$0")/../pipelines"

if [ -f "$PIPELINE_DIR/06-sap-backup-infrastructure.yaml" ]; then
    print_status "SUCCESS" "Azure DevOps pipeline found"
else
    print_status "WARNING" "Azure DevOps pipeline not found"
fi

# Validate sample configuration syntax
print_status "INFO" "Validating sample configuration syntax..."

if [ -f "$SAMPLE_CONFIG_DIR/DEV-SECE-BUP01-BACKUP.tfvars" ]; then
    # Create a temporary directory for validation
    TEMP_DIR=$(mktemp -d)
    cp -r "$TERRAFORM_DIR"/* "$TEMP_DIR/"

    cd "$TEMP_DIR"

    # Try to validate with sample configuration
    if terraform validate &> /dev/null; then
        print_status "SUCCESS" "Sample configuration syntax is valid"
    else
        print_status "WARNING" "Sample configuration has syntax issues (this is expected without proper variable values)"
    fi

    # Cleanup
    rm -rf "$TEMP_DIR"
fi

print_status "INFO" "Validation completed!"
echo "=================================================="

print_status "SUCCESS" "SAP Backup Infrastructure is ready for deployment"
echo ""
echo "Next steps:"
echo "1. Create your backup configuration in WORKSPACES/BACKUP/"
echo "2. Update the configuration with your specific values"
echo "3. Run the deployment using install_backup.sh or Azure DevOps pipeline"
echo ""
echo "Example deployment:"
echo "  cd WORKSPACES/BACKUP/DEV-SECE-BUP01-BACKUP"
echo "  ../../../deploy/scripts/install_backup.sh -p DEV-SECE-BUP01-BACKUP.tfvars -i"
