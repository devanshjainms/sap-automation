/*
 * SAP Landscape Module — Test Helper Module
 *
 * This module mirrors the variable declarations and validation blocks from
 * the sap_landscape root module for variables that do NOT depend on
 * provider::azurerm::parse_resource_id. It allows Terraform native tests
 * to exercise validation logic in isolation without requiring a real provider.
 *
 * Variables covered:
 *   - environment
 *   - subscription_id
 *   - management_subscription_id
 *   - network_flow_timeout_in_minutes
 *   - management_dns_subscription_id
 *   - privatelink_dns_subscription_id
 *   - spn_id
 */

terraform {
  required_version = ">= 1.13.0"
}

# ------------------------------------------------------------------------------
# environment
# ------------------------------------------------------------------------------

variable "environment" {
  description = "This is the environment name for the deployment"
  type        = string
  default     = "DEV"
  validation {
    condition     = length(var.environment) <= 5 && length(var.environment) > 0
    error_message = "The 'environment' variable must be specified and at most 5 characters long."
  }
}

# ------------------------------------------------------------------------------
# subscription_id
# ------------------------------------------------------------------------------

variable "subscription_id" {
  description = "This is the target subscription for the deployment"
  type        = string
  default     = ""
  validation {
    condition     = length(var.subscription_id) == 0 ? true : length(var.subscription_id) == 36
    error_message = "If specified the 'subscription_id' variable must be a correct subscription ID."
  }
}

# ------------------------------------------------------------------------------
# management_subscription_id
# ------------------------------------------------------------------------------

variable "management_subscription_id" {
  description = "This is the management subscription used by the deployment"
  type        = string
  default     = ""
  validation {
    condition     = length(var.management_subscription_id) == 0 ? true : length(var.management_subscription_id) == 36
    error_message = "If specified the 'management_subscription_id' variable must be a correct subscription ID."
  }
}

# ------------------------------------------------------------------------------
# network_flow_timeout_in_minutes
# ------------------------------------------------------------------------------

variable "network_flow_timeout_in_minutes" {
  description = "The flow timeout in minutes of the virtual network"
  type        = number
  nullable    = true
  default     = null
  validation {
    condition     = var.network_flow_timeout_in_minutes == null ? true : (var.network_flow_timeout_in_minutes >= 4 && var.network_flow_timeout_in_minutes <= 30)
    error_message = "The flow timeout in minutes must be between 4 and 30 if set."
  }
}

# ------------------------------------------------------------------------------
# management_dns_subscription_id
# ------------------------------------------------------------------------------

variable "management_dns_subscription_id" {
  description = "String value giving the possibility to register custom dns a records in a separate subscription"
  default     = ""
  type        = string
  validation {
    condition     = length(var.management_dns_subscription_id) == 0 ? true : length(var.management_dns_subscription_id) == 36
    error_message = "If specified the 'management_dns_subscription_id' variable must be a correct subscription ID."
  }
}

# ------------------------------------------------------------------------------
# privatelink_dns_subscription_id
# ------------------------------------------------------------------------------

variable "privatelink_dns_subscription_id" {
  description = "String value giving the possibility to register custom PrivateLink DNS A records in a separate subscription"
  default     = ""
  type        = string
  validation {
    condition     = length(var.privatelink_dns_subscription_id) == 0 ? true : length(var.privatelink_dns_subscription_id) == 36
    error_message = "If specified the 'privatelink_dns_subscription_id' variable must be a correct subscription ID."
  }
}

# ------------------------------------------------------------------------------
# spn_id
# ------------------------------------------------------------------------------

variable "spn_id" {
  description = "Service Principal Id to be used for the deployment"
  default     = ""
  type        = string
  validation {
    condition     = length(var.spn_id) == 0 ? true : length(var.spn_id) == 36
    error_message = "If specified the 'spn_id' variable must be a correct service principal ID."
  }
}

# ------------------------------------------------------------------------------
# Outputs — used by positive tests to assert values pass through correctly
# ------------------------------------------------------------------------------

output "environment" {
  value = var.environment
}

output "subscription_id" {
  value = var.subscription_id
}

output "management_subscription_id" {
  value = var.management_subscription_id
}

output "network_flow_timeout_in_minutes" {
  value = var.network_flow_timeout_in_minutes
}

output "management_dns_subscription_id" {
  value = var.management_dns_subscription_id
}

output "privatelink_dns_subscription_id" {
  value = var.privatelink_dns_subscription_id
}

output "spn_id" {
  value = var.spn_id
}
