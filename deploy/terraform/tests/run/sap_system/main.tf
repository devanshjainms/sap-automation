/*
 * SAP System Module — Test Helper Module
 *
 * Mirrors variable declarations and validation logic from the sap_system root module.
 * Used by terraform test to isolate variable validation from provider-dependent resources.
 *
 * IMPORTANT: Validations using provider::azurerm::parse_resource_id are intentionally
 * excluded because mock_provider does not support ephemeral resources or provider
 * functions in helper modules.
 *
 * Testable validations:
 *   - environment: 1-5 characters
 *   - location: must not be empty
 *   - network_logical_name: must not be empty
 *   - database_platform: must not be empty
 *   - sid: must be exactly 3 characters
 *   - landscape_tfstate_key: must not be empty (after trim)
 *   - subscription_id: must be 36 characters if provided
 *   - management_dns_subscription_id: must be 36 characters if provided
 *   - privatelink_dns_subscription_id: must be 36 characters if provided
 *   - database_use_avset: must be a valid boolean
 *   - database_use_ppg: must be a valid boolean
 *   - scs_server_use_avset: must be a valid boolean
 *   - scs_server_use_ppg: must be a valid boolean
 *   - application_server_use_avset: must be a valid boolean
 *   - application_server_use_ppg: must be a valid boolean
 */

terraform {
  required_version = ">= 1.5.0"
}

# ==============================================================================
# Environment & Location
# ==============================================================================

variable "environment" {
  description = "This is the environment name for the deployment"
  type        = string
  validation {
    condition     = length(var.environment) <= 5 && length(var.environment) > 0
    error_message = "The 'environment' variable must be specified and at most 5 characters long."
  }
}

variable "location" {
  description = "The Azure region for the resources"
  type        = string
  validation {
    condition     = length(var.location) != 0
    error_message = "The 'location' variable must not be empty."
  }
}

# ==============================================================================
# Networking
# ==============================================================================

variable "network_logical_name" {
  description = "The logical name of the virtual network, used for resource naming"
  type        = string
  default     = "sap"
  validation {
    condition     = length(var.network_logical_name) != 0
    error_message = "The 'network_logical_name' variable must not be empty."
  }
}

# ==============================================================================
# Database Tier
# ==============================================================================

variable "database_platform" {
  description = "Database platform, supported values are HANA, DB2, ORACLE, ORACLE-ASM, ASE, SQLSERVER or NONE"
  type        = string
  default     = "HANA"
  validation {
    condition     = length(var.database_platform) != 0
    error_message = "The 'database_platform' variable must not be empty."
  }
}

variable "database_use_avset" {
  description = "If true, the database tier will use an availability set"
  default     = true
  validation {
    condition = (
      tobool(var.database_use_avset) != null
    )
    error_message = "The variable 'database_use_avset' is not defined, please define it in your tfvars file."
  }
}

variable "database_use_ppg" {
  description = "If provided, the database tier will be placed in a proximity placement group"
  default     = true
  validation {
    condition = (
      tobool(var.database_use_ppg) != null
    )
    error_message = "The variable 'database_use_ppg is not defined, please define it in your tfvars file."
  }
}

# ==============================================================================
# Application Tier — SID
# ==============================================================================

variable "sid" {
  description = "Application SID"
  type        = string
  validation {
    condition     = length(var.sid) == 3
    error_message = "The 'sid' variable must be exactly 3 characters long."
  }
}

# ==============================================================================
# Application Tier — Availability & PPG
# ==============================================================================

variable "scs_server_use_avset" {
  description = "If true, the SAP Central Services tier will be placed in an availability set"
  default     = true
  validation {
    condition = (
      tobool(var.scs_server_use_avset) != null
    )
    error_message = "scs_server_use_avset is not defined, please define it in your tfvars file."
  }
}

variable "scs_server_use_ppg" {
  description = "If provided, the Central Services will be placed in a proximity placement group"
  default     = true
  validation {
    condition = (
      tobool(var.scs_server_use_ppg) != null
    )
    error_message = "scs_server_use_ppg is not defined, please define it in your tfvars file."
  }
}

variable "application_server_use_avset" {
  description = "If true, the application tier will be placed in an availability set"
  default     = true
  validation {
    condition = (
      tobool(var.application_server_use_avset) != null
    )
    error_message = "The variable 'application_server_use_avset' is not defined, please define it in your tfvars file."
  }
}

variable "application_server_use_ppg" {
  description = "If provided, the application servers will be placed in a proximity placement group"
  default     = true
  validation {
    condition = (
      tobool(var.application_server_use_ppg) != null
    )
    error_message = "The variable 'application_server_use_ppg' is not defined, please define it in your tfvars file."
  }
}

# ==============================================================================
# Terraform State
# ==============================================================================

variable "landscape_tfstate_key" {
  description = "The name of Workload zone terraform state file"
  type        = string
  validation {
    condition     = (length(trimspace(var.landscape_tfstate_key)) != 0)
    error_message = "The Landscape state file name must be specified."
  }
}

# ==============================================================================
# Subscription IDs
# ==============================================================================

variable "subscription_id" {
  description = "Target subscription"
  type        = string
  default     = ""
  validation {
    condition     = length(var.subscription_id) == 0 ? true : length(var.subscription_id) == 36
    error_message = "If specified the 'subscription_id' variable must be a correct subscription ID."
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

# ==============================================================================
# Outputs — used for positive-case assertions
# ==============================================================================

output "environment" {
  value = var.environment
}

output "location" {
  value = var.location
}

output "network_logical_name" {
  value = var.network_logical_name
}

output "database_platform" {
  value = var.database_platform
}

output "sid" {
  value = var.sid
}

output "landscape_tfstate_key" {
  value = var.landscape_tfstate_key
}

output "subscription_id" {
  value = var.subscription_id
}

output "management_dns_subscription_id" {
  value = var.management_dns_subscription_id
}

output "privatelink_dns_subscription_id" {
  value = var.privatelink_dns_subscription_id
}

output "database_use_avset" {
  value = var.database_use_avset
}

output "database_use_ppg" {
  value = var.database_use_ppg
}

output "scs_server_use_avset" {
  value = var.scs_server_use_avset
}

output "scs_server_use_ppg" {
  value = var.scs_server_use_ppg
}

output "application_server_use_avset" {
  value = var.application_server_use_avset
}

output "application_server_use_ppg" {
  value = var.application_server_use_ppg
}
