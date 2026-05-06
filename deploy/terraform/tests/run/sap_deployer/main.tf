# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

/*
 * SAP Deployer Module — Test Helper Module
 *
 * Mirrors variable declarations and validations from the sap_deployer root module
 * to enable isolated testing without requiring the full Azure provider stack.
 *
 * Validations using provider::azurerm::parse_resource_id are intentionally omitted
 * as they require a real azurerm provider connection.
 */

terraform {
  required_version = ">= 1.13.0"
}

#######################################4#######################################8
#                                                                              #
#                           Environment definitions                            #
#                                                                              #
#######################################4#######################################8

variable "environment" {
  description = "This is the environment name of the deployer"
  type        = string
  validation {
    condition     = length(var.environment) <= 5 && length(var.environment) > 0
    error_message = "The 'environment' variable must be specified and at most 5 characters long."
  }
}

variable "location" {
  description = "Defines the Azure location where the resources will be deployed"
  type        = string
  default     = "eastus"
}

variable "subscription_id" {
  description = "Defines the Azure subscription_id"
  type        = string
  default     = ""
  validation {
    condition     = length(var.subscription_id) == 0 ? true : length(var.subscription_id) == 36
    error_message = "If specified the 'subscription_id' variable must be a correct subscription ID."
  }
}

#######################################4#######################################8
#                                                                              #
#                     Virtual Network variables                                #
#                                                                              #
#######################################4#######################################8

variable "management_network_flow_timeout_in_minutes" {
  description = "The flow timeout in minutes of the virtual network"
  type        = number
  nullable    = true
  default     = null
  validation {
    condition     = var.management_network_flow_timeout_in_minutes == null ? true : (var.management_network_flow_timeout_in_minutes >= 4 && var.management_network_flow_timeout_in_minutes <= 30)
    error_message = "The flow timeout in minutes must be between 4 and 30 if set."
  }
}

#######################################4#######################################8
#                                                                              #
#                          Infrastructure definitions                          #
#                                                                              #
#######################################4#######################################8

variable "infrastructure" {
  description = "Details of the Azure infrastructure to deploy the deployer into"
  default     = {}

  validation {
    condition = (
      contains(keys(var.infrastructure), "region") ? (
        length(trimspace(var.infrastructure.region)) != 0) : (
        true
      )
    )
    error_message = "The region must be specified in the infrastructure.region field."
  }

  validation {
    condition = (
      contains(keys(var.infrastructure), "environment") ? (
        length(trimspace(var.infrastructure.environment)) != 0) : (
        true
      )
    )
    error_message = "The environment must be specified in the infrastructure.environment field."
  }

  validation {
    condition = (
      contains(keys(var.infrastructure), "virtual_network") ? (
        length(trimspace(try(var.infrastructure.virtual_network.management.arm_id, ""))) != 0 || length(trimspace(try(var.infrastructure.virtual_network.management.address_space, ""))) != 0) : (
        true
      )
    )
    error_message = "Either the arm_id or address_space of the VNet must be specified in the infrastructure.virtual_network.management block."
  }

  validation {
    condition = (
      contains(keys(var.infrastructure), "virtual_network") ? (
        length(trimspace(try(var.infrastructure.virtual_network.management.subnet_mgmt.arm_id, ""))) != 0 || length(trimspace(try(var.infrastructure.virtual_network.management.subnet_mgmt.prefix, ""))) != 0) : (
        true
      )
    )
    error_message = "Either the arm_id or prefix of the subnet must be specified in the infrastructure.virtual_network.management.subnet_management block."
  }
}

#######################################4#######################################8
#                                                                              #
#                          Authentication definitions                          #
#                                                                              #
#######################################4#######################################8

variable "authentication" {
  description = "Authentication details"
  default = {
    username            = "azureadm",
    path_to_public_key  = "",
    path_to_private_key = ""
  }

  validation {
    condition = (
      length(var.authentication) >= 1
    )
    error_message = "Either ssh keys or user credentials must be specified."
  }
  validation {
    condition = (
      length(trimspace(var.authentication.username)) != 0
    )
    error_message = "The default username for the Virtual machines must be specified."
  }
}

#######################################4#######################################8
#                                                                              #
#                          SPN and DNS definitions                             #
#                                                                              #
#######################################4#######################################8

variable "spn_id" {
  description = "SPN ID to be used for the deployment"
  nullable    = true
  default     = ""
  validation {
    condition     = length(var.spn_id) == 0 ? true : length(var.spn_id) == 36
    error_message = "If specified the 'spn_id' variable must be a correct subscription ID."
  }
}

variable "management_dns_subscription_id" {
  description = "String value giving the possibility to register custom dns a records in a separate subscription"
  default     = ""
  type        = string
  validation {
    condition     = length(var.management_dns_subscription_id) == 0 ? true : length(var.management_dns_subscription_id) == 36
    error_message = "If specified the 'management_dns_subscription_id' variable must be a correct subscription ID."
  }
}

variable "privatelink_dns_subscription_id" {
  description = "String value giving the possibility to register custom PrivateLink DNS A records in a separate subscription"
  default     = ""
  type        = string
  validation {
    condition     = length(var.privatelink_dns_subscription_id) == 0 ? true : length(var.privatelink_dns_subscription_id) == 36
    error_message = "If specified the 'privatelink_dns_subscription_id' variable must be a correct subscription ID."
  }
}

variable "app_registration_app_id" {
  description = "The app registration id to be used for the webapp"
  default     = ""
  validation {
    condition     = length(var.app_registration_app_id) == 0 ? true : length(var.app_registration_app_id) == 36
    error_message = "If specified the 'app_registration_app_id' variable must be a correct Azure resource identifier."
  }
}

#######################################4#######################################8
#                                                                              #
#                                   Outputs                                    #
#                                                                              #
#######################################4#######################################8

output "environment" {
  value = var.environment
}

output "location" {
  value = var.location
}

output "subscription_id" {
  value = var.subscription_id
}

output "management_network_flow_timeout_in_minutes" {
  value = var.management_network_flow_timeout_in_minutes
}

output "infrastructure" {
  value = var.infrastructure
}

output "authentication" {
  value = var.authentication
}

output "spn_id" {
  value = var.spn_id
}

output "management_dns_subscription_id" {
  value = var.management_dns_subscription_id
}

output "privatelink_dns_subscription_id" {
  value = var.privatelink_dns_subscription_id
}

output "app_registration_app_id" {
  value = var.app_registration_app_id
}
