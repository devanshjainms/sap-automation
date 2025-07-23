# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

#######################################4#######################################8
#                                                                              #
#                           Environment definitions                            #
#                                                                              #
#######################################4#######################################8


variable "environment"                           {
                                                   description = "This is the environment name for the deployment"
                                                   type        = string
                                                   default     = ""
                                                 }

variable "codename"                              {
                                                   description = "This is the code name for the deployment"
                                                   type        = string
                                                   default     = ""
                                                 }

variable "Description"                           {
                                                   description = "This is the description for the deployment"
                                                   type        = string
                                                   default     = ""
                                                 }

variable "location"                              {
                                                  description = "The Azure region for the resources"
                                                  type        = string
                                                  default     = ""
                                                }

variable "name_override_file"                   {
                                                  description = "If provided, contains a json formatted file defining the name overrides"
                                                  default     = ""
                                                }

variable "custom_prefix"                        {
                                                  description = "Optional custom prefix for the deployment"
                                                  type        = string
                                                  default     = ""
                                                }

variable "use_prefix"                           {
                                                  description = "Defines if the resources are to be prefixed"
                                                  default     = true
                                                }


variable "custom_backup_policy_filename"           {
                                                  description = "Custom backup policy json file for Virtual machines"
                                                  default     = ""
}


#########################################################################################
#                                                                                       #
#  Resource Group variables                                                             #
#                                                                                       #
#########################################################################################

variable "resourcegroup_name"                   {
                                                  description = "If provided, the name of the resource group to be created"
                                                  default     = ""
                                                }

variable "resourcegroup_arm_id"                 {
                                                  description = "If provided, the Azure resource group id"
                                                  default     = ""
                                                  validation    {
                                                                  condition     = length(var.resourcegroup_arm_id) == 0 ? true : can(provider::azurerm::parse_resource_id(var.resourcegroup_arm_id))
                                                                  error_message = "If specified the 'resourcegroup_arm_id' variable must be a correct Azure resource identifier."
                                                                }

                                                }

variable "resourcegroup_tags"                   {
                                                  description = "If provided, tags for the resource group"
                                                  default     = {}
                                                }


variable "prevent_deletion_if_contains_resources" {
                                                    description = "Controls if resource groups are deleted even if they contain resources"
                                                    type        = bool
                                                    default     = true
                                                  }

#########################################################################################
#                                                                                       #
#  Infrastructure variables                                                             #
#                                                                                       #
#########################################################################################

variable "use_private_endpoint"                 {
                                                  description = "Boolean value indicating if private endpoint should be used for the deployment"
                                                  default     = true
                                                  type        = bool
                                                }

variable "custom_random_id"                     {
                                                  description = "If provided, the value of the custom random id"
                                                  default     = ""
                                                }

#########################################################################################
#                                                                                       #
#  Virtual Network variables                                                            #
#                                                                                       #
#########################################################################################

variable "network_logical_name"                 {
                                                  description = "The logical name of the virtual network, used for resource naming"
                                                  default     = ""
                                                }

#######################################4#######################################8
#                                                                              #
#                        Backup Subnet variables                                #
#                                                                              #
#######################################4#######################################8

variable "backup_subnet_address_prefix"          {
                                                  description = "The address prefix for the backup subnet"
                                                  default     = ""
                                                }

variable "backup_subnet_name"                    {
                                                  description = "If provided, the name of the backup subnet"
                                                  default     = ""
                                                }

variable "backup_subnet_arm_id"                  {
                                                  description = "If provided, Azure resource id for the backup subnet"
                                                  default     = ""
                                                  validation    {
                                                                  condition     = length(var.backup_subnet_arm_id) == 0 ? true : can(provider::azurerm::parse_resource_id(var.backup_subnet_arm_id))
                                                                  error_message = "If specified the 'backup_subnet_arm_id' variable must be a correct Azure resource identifier."
                                                                }
                                                }

variable "backup_subnet_nsg_name"                {
                                                  description = "If provided, the name of the backup subnet NSG"
                                                  default     = ""
                                                }

variable "backup_subnet_nsg_arm_id"              {
                                                  description = "If provided, Azure resource id for the backup subnet NSG"
                                                  default     = ""
                                                  validation    {
                                                                  condition     = length(var.backup_subnet_nsg_arm_id) == 0 ? true : can(provider::azurerm::parse_resource_id(var.backup_subnet_nsg_arm_id))
                                                                  error_message = "If specified the 'backup_subnet_nsg_arm_id' variable must be a correct Azure resource identifier."
                                                                }
                                                }

#########################################################################################
#                                                                                       #
#  Authentication variables, use these if you want to have SID specific credentials     #
#                                                                                       #
#########################################################################################

variable "automation_username"                  {
                                                  description = "The username for the automation account"
                                                  default     = ""
                                                }

variable "automation_password"                  {
                                                  description = "If provided, the password for the automation account"
                                                  default     = ""
                                                }

variable "automation_path_to_public_key"        {
                                                  description = "If provided, the path to the existing public key for the automation account"
                                                  default     = ""
                                                }

variable "automation_path_to_private_key"       {
                                                  description = "If provided, the path to the existing private key for the automation account"
                                                  default     = ""
                                                }

variable "use_spn"                              {
                                                  description = "Log in using a service principal when performing the deployment"
                                                  default     = false
                                                }

#########################################################################################
#                                                                                       #
#  Miscellaneous settings                                                               #
#                                                                                       #
#########################################################################################

variable "resource_offset"                      {
                                                  description = "Provides an offset for the resource names (Server00 vs Server01)"
                                                  default     = 0
                                                }

variable "deploy_v1_monitoring_extension"       {
                                                  description = "Defines if the Microsoft.AzureCAT.AzureEnhancedMonitoring extension will be deployed"
                                                  default     = true
                                                }

variable "vm_disk_encryption_set_id"            {
                                                  description = "If provided, the VM disks will be encrypted with the specified disk encryption set"
                                                  default     = ""
                                                }

variable "nsg_asg_with_vnet"                    {
                                                  description = "If true, the network security group will be placed in the resource group containing the VNet"
                                                  default     = false
                                                }

variable "legacy_nic_order"                     {
                                                  description = "If defined, will reverse the order of the NICs"
                                                  default     = false
                                                }

variable "use_admin_nic_suffix_for_observer"    {
                                                  description = "If true, the admin nic suffix will be used for the observer"
                                                  default     = false
                                                }

variable "use_admin_nic_for_asg"                {
                                                  description = "If true, the admin nic will be assigned to the ASG instead of the second nic"
                                                  default     = false
                                                }

variable "use_loadbalancers_for_standalone_deployments" {
                                                           description = "If defined, will use load balancers for standalone deployments"
                                                           default     = true
                                                        }

variable "idle_timeout_scs_ers"                 {
                                                  description = "Sets the idle timeout setting for the SCS and ERS loadbalancer"
                                                  default     = 30
                                                }

variable "bom_name"                             {
                                                  description = "Name of the SAP Application Bill of Material file"
                                                  default     = ""
                                                }

variable "Agent_IP"                             {
                                                  description = "If provided, contains the IP address of the agent"
                                                  type        = string
                                                  default     = ""
                                                }
variable "add_Agent_IP"                         {
                                                  description = "Boolean value indicating if the Agent IP should be added to the storage and key vault firewalls"
                                                  default     = true
                                                  type        = bool
                                                }

variable "shared_home"                          {
                                                  description = "If defined provides shared-home support"
                                                  default     = false
                                                }

variable "save_naming_information"              {
                                                  description = "If defined, will save the naming information for the resources"
                                                  default     = false
                                                }

variable "deploy_application_security_groups"   {
                                                  description = "Defines if application security groups should be deployed"
                                                  default     = true
                                                }

variable "user_assigned_identity_id"            {
                                                  description = "If provided defines the user assigned identity to assign to the virtual machines"
                                                  default     = ""
                                                  validation    {
                                                                  condition     = length(var.user_assigned_identity_id) == 0 ? true : can(provider::azurerm::parse_resource_id(var.user_assigned_identity_id))
                                                                  error_message = "If specified the 'user_assigned_identity_id' variable must be a correct Azure resource identifier."
                                                                }
                                                }

variable "disk_controller_type_database_tier"   {
                                                  description = "The disk controller type to use for the virtual machines"
                                                  default     = "SCSI"
                                                }

variable "disk_controller_type_app_tier"        {
                                                  description = "The disk controller type to use for the virtual machines"
                                                  default     = "SCSI"
                                                }

variable "storage_account_replication_type"     {
                                                  description = "Storage account replication type"
                                                  default     = "ZRS"
                                                }
