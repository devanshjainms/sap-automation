/*
 * SAP Library Module — Helper Module for Variable Validation Tests
 *
 * This helper module mirrors variable declarations and their validation logic
 * from the sap_library root module. It isolates tests from provider-dependent
 * resources so that `terraform test` can run without Azure credentials.
 *
 * NOTE: Variables validated with `provider::azurerm::parse_resource_id` are
 * intentionally excluded because mock_provider cannot supply that function.
 *
 * Mirrored validations:
 *   - environment: must be 1-5 characters
 *   - subscription_id: must be 36 characters if provided
 *   - spn_id: must be 36 characters if provided
 *   - management_dns_subscription_id: must be 36 characters if provided
 *   - privatelink_dns_subscription_id: must be 36 characters if provided
 */

terraform {
  required_version = ">= 1.6.0"
}

# --------------------------------------------------------------------------- #
#  environment — required, 1-5 characters
# --------------------------------------------------------------------------- #

variable "environment" {
  description = "This is the environment name of the deployer"
  type        = string
  validation {
    condition     = length(var.environment) <= 5 && length(var.environment) > 0
    error_message = "The 'environment' variable must be specified and at most 5 characters long."
  }
}

# --------------------------------------------------------------------------- #
#  subscription_id — empty or exactly 36 characters
# --------------------------------------------------------------------------- #

variable "subscription_id" {
  description = "Defines the Azure subscription_id"
  type        = string
  default     = ""
  validation {
    condition     = length(var.subscription_id) == 0 ? true : length(var.subscription_id) == 36
    error_message = "If specified the 'subscription_id' variable must be a correct subscription ID."
  }
}

# --------------------------------------------------------------------------- #
#  spn_id — empty or exactly 36 characters
# --------------------------------------------------------------------------- #

variable "spn_id" {
  description = "SPN ID to be used for the deployment"
  type        = string
  nullable    = true
  default     = ""
  validation {
    condition     = length(var.spn_id) == 0 ? true : length(var.spn_id) == 36
    error_message = "If specified the 'spn_id' variable must be a correct service principal ID."
  }
}

# --------------------------------------------------------------------------- #
#  management_dns_subscription_id — empty or exactly 36 characters
# --------------------------------------------------------------------------- #

variable "management_dns_subscription_id" {
  description = "String value giving the possibility to register custom dns a records in a separate subscription"
  type        = string
  default     = ""
  validation {
    condition     = length(var.management_dns_subscription_id) == 0 ? true : length(var.management_dns_subscription_id) == 36
    error_message = "If specified the 'management_dns_subscription_id' variable must be a correct subscription ID."
  }
}

# --------------------------------------------------------------------------- #
#  privatelink_dns_subscription_id — empty or exactly 36 characters
# --------------------------------------------------------------------------- #

variable "privatelink_dns_subscription_id" {
  description = "String value giving the possibility to register custom PrivateLink DNS A records in a separate subscription"
  type        = string
  default     = ""
  validation {
    condition     = length(var.privatelink_dns_subscription_id) == 0 ? true : length(var.privatelink_dns_subscription_id) == 36
    error_message = "If specified the 'privatelink_dns_subscription_id' variable must be a correct subscription ID."
  }
}

# --------------------------------------------------------------------------- #
#  Outputs — expose values for positive test assertions
# --------------------------------------------------------------------------- #

output "environment" {
  value = var.environment
}

output "subscription_id" {
  value = var.subscription_id
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
