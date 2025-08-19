# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

#######################################4#######################################8
#                                                                              #
#                           Environment definitions                            #
#                                                                              #
#######################################4#######################################8
variable "environment"                          {
                                                  description = "This is the environment name for the deployment"
                                                  type        = string
                                                  default     = ""
                                                }

variable "codename"                             {
                                                  description = "This is the code name name for the deployment"
                                                  type        = string
                                                  default     = ""
                                                }

variable "location"                             {
                                                  description = "The Azure region for the resources"
                                                  type        = string
                                                  default     = ""
                                                }

variable "name_override_file"                   {
                                                  description = "If provided, contains a json formatted file defining the name overrides"
                                                  default     = ""
                                                }

variable "subscription_id"                      {
                                                  description = "This is the target subscription for the deployment"
                                                  type        = string
                                                  default     = ""
                                                }
variable "management_subscription_id"           {
                                                  description = "This is the management subscription used by the deployment"
                                                  type        = string
                                                  default     = ""
                                                }

variable "management_dns_subscription_id"        {
                                                  description = "This is the management subscription used by the deployment"
                                                  type        = string
                                                  default     = ""
                                                }

variable "privatelink_dns_subscription_id" {
                                                  description = "This is the subscription used for private link DNS management"
                                                  type        = string
                                                  default     = ""
                                                }

variable "use_deployer"                         {
                                                  description = "Use deployer to deploy the resources"
                                                  default     = true
                                                }

variable "place_delete_lock_on_resources"       {
                                                  description = "If defined, a delete lock will be placed on the key resources"
                                                  default     = false
                                                }

variable "prevent_deletion_if_contains_resources" {
                                                    description = "Controls if resource groups are deleted even if they contain resources"
                                                    type        = bool
                                                    default     = true
                                                  }

variable "data_plane_available"                 {
                                                  description = "Boolean value indicating if storage account access is via data plane"
                                                  default     = true
                                                  type        = bool
                                                }

variable "enable_purge_control_for_keyvaults" {
                                                  description = "If defined, enables purge protection for key vaults"
                                                  default     = false
                                                  type        = bool
                                                }

#########################################################################################
#                                                                                       #
#  Authentication variables                                                             #
#                                                                                       #
#########################################################################################

variable "automation_username"                 {
                                                  description = "The username for the automation account"
                                                  default     = "azureadm"
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

variable "user_assigned_identity_id"            {
                                                  description = "If provided defines the user assigned identity to assign to the virtual machines"
                                                  default     = ""
                                                }

variable "deploy_monitoring_extension"          {
                                                  description = "If defined, will add the Microsoft.Azure.Monitor.AzureMonitorLinuxAgent extension to the virtual machines"
                                                  default     = false
                                                }

variable "deploy_defender_extension"            {
                                                  description = "If defined, will add the Microsoft.Azure.Security.Monitoring extension to the virtual machines"
                                                  default     = false
                                                }


#######################################4#######################################8
#                                                                              #
#                          Resource group definitions                          #
#                                                                              #
#######################################4#######################################8

variable "backup_resourcegroup_name"                   {
                                                  description = "If provided, the name of the resource group to be created"
                                                  default     = ""
                                                }

variable "backup_resourcegroup_arm_id"                 {
                                                  description = "If provided, the Azure resource group id"
                                                  default     = ""
                                                }

variable "backup_resourcegroup_tags"                   {
                                                  description = "Tags to be applied to the resource group"
                                                  default     = {}
                                                }


#######################################4#######################################8
#                                                                              #
#                     Back up Virtual Network variables                        #
#                                                                              #
#######################################4#######################################8

variable "backup_network_name"                  {
                                                  description = "If provided, the name of the Virtual network"
                                                  default     = ""
                                                }

variable "backup_network_logical_name"                 {
                                                  description = "The logical name of the virtual network, used for resource naming"
                                                  default     = ""
                                                }

variable "backup_vnet_address_space"                {
                                                  description = "The address space of the virtual network"
                                                  default     = [""]
                                                  type        = list(string)
                                                }

variable "backup_vnet_arm_id"                       {
                                                  description = "If provided, the Azure resource id of the virtual network"
                                                  default     = ""
                                                  validation    {
                                                                  condition     = length(var.network_arm_id) == 0 ? true : can(provider::azurerm::parse_resource_id(var.network_arm_id))
                                                                  error_message = "If specified the 'network_arm_id' variable must be a correct Azure resource identifier."
                                                                }

                                                }

variable "network_flow_timeout_in_minutes"      {
                                                  description = "The flow timeout in minutes of the virtual network"
                                                  type = number
                                                  nullable = true
                                                  default = null
                                                  validation {
                                                    condition     = var.network_flow_timeout_in_minutes == null ? true : (var.network_flow_timeout_in_minutes >= 4 && var.network_flow_timeout_in_minutes <= 30)
                                                    error_message = "The flow timeout in minutes must be between 4 and 30 if set."
                                                  }
                                                }

variable "network_enable_route_propagation"     {
                                                  description = "Enable network route table propagation"
                                                  type = bool
                                                  nullable = false
                                                  default = true
                                                }

variable "use_private_endpoint"                 {
                                                  description = "Boolean value indicating if private endpoint should be used for the deployment"
                                                  default     = false
                                                  type        = bool
                                                }

variable "use_service_endpoint"                 {
                                                  description = "Boolean value indicating if service endpoints should be used for the deployment"
                                                  default     = false
                                                  type        = bool
                                                }

variable "enable_firewall_for_keyvaults_and_storage" {
                                                       description = "Boolean value indicating if firewall should be enabled for key vaults and storage"
                                                       default     = false
                                                       type        = bool
                                                     }

variable "public_network_access_enabled"        {
                                                  description = "Defines if the public access should be enabled for keyvaults and storage accounts"
                                                  default     = true
                                                  type        = bool
                                                }

variable "peer_with_control_plane_vnet"         {
                                                  description = "Defines in the SAP VNet will be peered with the controlplane VNet"
                                                  type        = bool
                                                  default     = true
                                                }

variable "peer_with_sap_vnet"         {
                                                  description = "Defines in the SAP VNet will be peered with the controlplane VNet"
                                                  type        = bool
                                                  default     = true
                                                }

variable "backup_subnet_arm_id" {
  description               = "Name of existing backup subnet (if use_existing_sap_network is true)"
  type                      = string
  default                   = ""
}

variable "backup_subnet_address_prefixes" {
  description               = "Address prefixes for the backup subnet"
  type                      = list(string)
  default                   = ["10.100.1.0/24"]
}

#######################################4#######################################8
#                                                                              #
#                     SAP Virtual Network variables                            #
#                                                                              #
#######################################4#######################################8

variable "sap_vnet_arm_id" {
  description               = "ID of the SAP VNet to connect backup infrastructure to"
  type                      = string
}

variable "sap_systems" {
  description                     = "List of SAP systems to be backed up"
  type                            = list(object({
    sid                            = string
    environment                     = string
    resource_group_name             = string
    hana_instance_number            = string
    database_names                  = optional(list(string), [])
    exclude_from_backup             = optional(bool, false)
  }))
  default = []
}

variable "target_workload_zones" {
  description                     = "List of workload zone configurations to discover SAP systems from"
  type                            = list(object({
    code                           = string
    environment                    = string
    region                         = string
  }))
  default                           = []
}


#######################################4#######################################8
#                                                                              #
#                     Backup vault configuration                               #
#                                                                              #
#######################################4#######################################8


variable "backup_configuration" {
  description = "Backup infrastructure configuration"
  type = object({
    vault_sku                      = optional(string)
    storage_mode_type              = optional(string)
    cross_region_restore_enabled   = optional(bool)
    soft_delete_enabled            = optional(bool)
    public_network_access_enabled  = optional(bool)
    enable_private_endpoint        = optional(bool)
    create_key_vault               = optional(bool)
    encryption_key_id              = optional(string)
    infrastructure_encryption_enabled = optional(bool)
  })
  default = {}
}

variable "backup_policy" {
  description                     = "SAP HANA backup policy configuration"
  type = object({
    time_zone                     = optional(string)
    compression_enabled           = optional(bool)

    full_backup                   = optional(object({
      frequency                   = optional(string)
      time                        = optional(string)
      weekdays                    = optional(list(string))

      retention_weekly            = optional(object({
        count                     = optional(number)
        weekdays                  = optional(list(string))
      }))

      retention_monthly           = optional(object({
        count                     = optional(number)
        weekdays                  = optional(list(string))
        weeks                     = optional(list(string))
      }))

      retention_yearly            = optional(object({
        count                     = optional(number)
        weekdays                  = optional(list(string))
        weeks                     = optional(list(string))
        months                    = optional(list(string))
      }))
    }))

    incremental_backup            = optional(object({
      frequency                   = optional(string)
      time                        = optional(string)
      weekdays                    = optional(list(string))
      retention_days              = optional(number)
    }))

    log_backup                    = optional(object({
      frequency_in_minutes        = optional(number)
      retention_days              = optional(number)
    }))
  })
  default = {}
}

variable "tags" {
  description                     = "Custom tags to be applied to backup resources"
  type                            = map(string)
  default                           = {}
}

#######################################4#######################################8
variable terraform_storage_account_arm_id {
  description                     = "The ARM ID of the storage account used for Terraform state"
  type                            = string
  default                         = ""
}

#######################################4#######################################8
#                                                                              #
#  Miscellaneous settings                                                      #
#                                                                              #
#######################################4#######################################8

variable "spn_id"                 {
                                    description = "Service Principal Id to be used for the deployment"
                                    default     = ""
                                  }

#######################################4#######################################8
#                                                                              #
#                             Terraform variables                              #
#                                                                              #
#######################################4#######################################8

variable "custom_random_id"                     {
                                                  description = "If provided, the value of the custom random id"
                                                  default     = ""
                                                }

variable "tfstate_resource_id"                   {
                                                    description = "Resource id of tfstate storage account"
                                                    validation {
                                                                condition = can(provider::azurerm::parse_resource_id(var.tfstate_resource_id)
                                                                )
                                                                error_message = "The Azure Resource ID for the storage account containing the Terraform state files must be provided and be in correct format."
                                                              }
                                                  }

variable "deployer_tfstate_key"                   {
                                                    description = "The name of deployer's remote tfstate file"
                                                    type    = string
                                                    default = ""
                                                  }
