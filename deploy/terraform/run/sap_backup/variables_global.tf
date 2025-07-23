# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

variable "application_tier"             {
                                          description = "Details of the Application layer"
                                                                                  default = {
                                                          enable_deployment        = true
                                                          use_DHCP                 = false
                                                          application_server_count = 0
                                                          dual_nics                = false
                                                        }

                                        }

variable "databases" {
                                          description = "Details of the database node"
                                          default = [
                                            {
                                              use_DHCP = false

                                            }
                                          ]
                                        }

variable "infrastructure"               {
                                          description = "Details of the Azure infrastructure to deploy the SAP landscape into"
                                          default = {}
                                        }

variable "options"                      {
                                          description = "Configuration options"
                                          default     = {
                                                          resource_offset   = 0
                                                          nsg_asg_with_vnet = false
                                                          legacy_nic_order  = false
                                                        }
}

variable "ssh-timeout"                 {
                                          description = "Timeout for connection that is used by provisioner"
                                          default = "30s"
                                       }

variable "key_vault"                   {
                                          description = "Details of keyvault"
                                          default = {}
                                       }
variable "authentication"              {
                                          description = "Defining the SDU credentials"
                                          default     = {}
}

variable "api-version"                 {
                                          description = "IMDS API Version"
                                          default = "2019-04-30"
                                       }

variable "auto-deploy-version"         {
                                          description = "Version for automated deployment"
                                          default = "v2"
                                       }

variable "scenario"                    {
                                          description = "Deployment Scenario"
                                          default = "HANA Database"
                                       }

variable "tfstate_resource_id"         {
                                          description = "Resource id of tfstate storage account"
                                          validation {
                                                       condition = can(provider::azurerm::parse_resource_id(var.tfstate_resource_id)
                                                       )
                                                       error_message = "The Azure Resource ID for the storage account containing the Terraform state files must be provided and be in correct format."
                                                     }

                                       }

variable "deployer_tfstate_key"       {
                                          description = "The key of deployer's remote tfstate file"
                                          default      =  ""
                                      }

variable "landscape_tfstate_key"      {
                                          description = "The key of sap landscape's remote tfstate file"
                                          validation {
                                                       condition = (length(trimspace(try(var.landscape_tfstate_key, ""))) != 0)
                                                       error_message = "The Landscape state file name must be specified."
                                                     }
                                      }

variable "deployment" {
                                          description = "The type of deployment"
                                          default     = "update"
                                      }

variable "terraform_template_version" {
                                          description = "The version of Terraform templates that were identified in the state file"
                                          default     = ""
                                      }

variable "license_type"               {
                                          description = "Specifies the license type for the OS"
                                          default     = ""
                                      }

variable "use_zonal_markers"          {
                                         type         = bool
                                         default      = true
                                      }

variable "subscription_id"                      {
                                                  description = "Target subscription"
                                                  default     = ""
                                                }

variable "management_subscription_id"           {
                                                  description = "This is the management subscription used by the deployment"
                                                  type        = string
                                                  default     = ""
                                                }

variable "data_plane_available"                 {
                                                  description = "Boolean value indicating if storage account access is via data plane"
                                                  default     = true
                                                  type        = bool
                                                }

#########################################################################################
#                                                                                       #
#  Key Vault variables                                                                  #
#                                                                                       #
#########################################################################################

variable "user_keyvault_id"                     {
                                                  description = "If provided, the Azure resource identifier of the credentials keyvault"
                                                  default     = ""
                                                  validation    {
                                                                  condition     = length(var.user_keyvault_id) == 0 ? true : can(provider::azurerm::parse_resource_id(var.user_keyvault_id))
                                                                  error_message = "If specified the 'user_keyvault_id' variable must be a correct Azure resource identifier."
                                                                }

                                                }

variable "spn_keyvault_id"                      {
                                                  description = "If provided, the Azure resource identifier of the deployment credential keyvault"
                                                  default     = ""
                                                  validation    {
                                                                  condition     = length(var.spn_keyvault_id) == 0 ? true : can(provider::azurerm::parse_resource_id(var.spn_keyvault_id))
                                                                  error_message = "If specified the 'spn_keyvault_id' variable must be a correct Azure resource identifier."
                                                                }
                                                }

variable "enable_purge_control_for_keyvaults"   {
                                                  description = "Disables the purge protection for Azure keyvaults."
                                                  default     = false
                                                  type        = bool
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


variable "use_custom_dns_a_registration"        {
                                                  description = "Boolean value indicating if a custom dns a record should be created when using private endpoints"
                                                  default     = false
                                                  type        = bool
                                                }

variable "management_dns_subscription_id"       {
                                                  description = "String value giving the possibility to register custom dns a records in a separate subscription"
                                                  default     = ""
                                                  type        = string
                                                }

variable "management_dns_resourcegroup_name"    {
                                                  description = "String value giving the possibility to register custom dns a records in a separate resourcegroup"
                                                  default     = ""
                                                  type        = string
                                                }

variable "privatelink_dns_subscription_id"         {
                                                     description = "String value giving the possibility to register custom PrivateLink DNS A records in a separate subscription"
                                                     default     = ""
                                                     type        = string
                                                   }

variable "privatelink_dns_resourcegroup_name"      {
                                                     description = "String value giving the possibility to register custom PrivateLink DNS A records in a separate resourcegroup"
                                                     default     = ""
                                                     type        = string
                                                     }


variable "dns_zone_names"                       {
                                                  description = "Private DNS zone names"
                                                  type        = map(string)

                                                  default = {
                                                              "file_dns_zone_name"  = "privatelink.file.core.windows.net"
                                                              "blob_dns_zone_name"  = "privatelink.blob.core.windows.net"
                                                              "vault_dns_zone_name" = "privatelink.vaultcore.azure.net"
                                                            }
                                                }

variable "dns_a_records_for_secondary_names"    {
                                                  description = "Boolean value indicating if dns a records should be created for the secondary DNS names"
                                                  default     = true
                                                  type        = bool
                                                }

variable "register_endpoints_with_dns"          {
                                                  description = "Boolean value indicating if endpoints should be registered to the dns zone"
                                                  default     = true
                                                  type        = bool
                                                }

variable "register_storage_accounts_keyvaults_with_dns" {
                                                     description = "Boolean value indicating if storage accounts and key vaults should be registered to the corresponding dns zones"
                                                     default     = true
                                                     type        = bool
                                                   }
