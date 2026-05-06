/*
 * SAP Deployer Module — Variable Validation Tests
 *
 * Tests the input validation logic for the sap_deployer root module.
 * Uses a helper module (tests/setup/main.tf) to isolate variable validations
 * from provider-dependent resources (ephemeral resources, data sources).
 *
 * Coverage:
 *   - environment: must be 1-5 characters (boundary testing)
 *   - subscription_id: must be exactly 36 characters if provided
 *   - management_network_flow_timeout_in_minutes: must be 4-30 if set
 *   - infrastructure object: conditional field validations
 *   - authentication object: username must not be empty
 *   - spn_id: must be exactly 36 characters if provided
 *   - management_dns_subscription_id: must be exactly 36 characters if provided
 *   - privatelink_dns_subscription_id: must be exactly 36 characters if provided
 *   - app_registration_app_id: must be exactly 36 characters if provided
 *
 * Run: cd deploy/terraform/tests/run/sap_deployer && terraform test
 */

# =============================================================================
# environment
# =============================================================================

run "environment_valid_single_char" {
  command = plan
  variables {
    environment = "D"
  }
  assert {
    condition     = output.environment == "D"
    error_message = "Should accept single character environment (minimum boundary)"
  }
}

run "environment_valid_typical" {
  command = plan
  variables {
    environment = "DEV"
  }
  assert {
    condition     = output.environment == "DEV"
    error_message = "Should accept typical 3-character environment"
  }
}

run "environment_valid_max_boundary" {
  command = plan
  variables {
    environment = "ABCDE"
  }
  assert {
    condition     = output.environment == "ABCDE"
    error_message = "Should accept 5-character environment (maximum boundary)"
  }
}

# =============================================================================
# environment
# =============================================================================

run "environment_invalid_empty" {
  command = plan
  variables {
    environment = ""
  }
  expect_failures = [var.environment]
}

run "environment_invalid_six_chars" {
  command = plan
  variables {
    environment = "ABCDEF"
  }
  expect_failures = [var.environment]
}

run "environment_invalid_too_long" {
  command = plan
  variables {
    environment = "TOOLONGENV"
  }
  expect_failures = [var.environment]
}

# =============================================================================
# subscription_id
# =============================================================================

run "subscription_id_valid_empty" {
  command = plan
  variables {
    environment     = "DEV"
    subscription_id = ""
  }
  assert {
    condition     = output.subscription_id == ""
    error_message = "Should accept empty subscription_id"
  }
}

run "subscription_id_valid_uuid" {
  command = plan
  variables {
    environment     = "DEV"
    subscription_id = "12345678-1234-1234-1234-123456789012"
  }
  assert {
    condition     = output.subscription_id == "12345678-1234-1234-1234-123456789012"
    error_message = "Should accept 36-character subscription_id"
  }
}

# =============================================================================
# subscription_id
# =============================================================================

run "subscription_id_invalid_short" {
  command = plan
  variables {
    environment     = "DEV"
    subscription_id = "too-short"
  }
  expect_failures = [var.subscription_id]
}

run "subscription_id_invalid_37_chars" {
  command = plan
  variables {
    environment     = "DEV"
    subscription_id = "12345678-1234-1234-1234-1234567890123"
  }
  expect_failures = [var.subscription_id]
}

# =============================================================================
# management_network_flow_timeout_in_minutes
# =============================================================================

run "flow_timeout_valid_null" {
  command = plan
  variables {
    environment                                = "DEV"
    management_network_flow_timeout_in_minutes = null
  }
  assert {
    condition     = output.management_network_flow_timeout_in_minutes == null
    error_message = "Should accept null flow timeout"
  }
}

run "flow_timeout_valid_min_boundary" {
  command = plan
  variables {
    environment                                = "DEV"
    management_network_flow_timeout_in_minutes = 4
  }
  assert {
    condition     = output.management_network_flow_timeout_in_minutes == 4
    error_message = "Should accept flow timeout of 4 (minimum boundary)"
  }
}

run "flow_timeout_valid_typical" {
  command = plan
  variables {
    environment                                = "DEV"
    management_network_flow_timeout_in_minutes = 15
  }
  assert {
    condition     = output.management_network_flow_timeout_in_minutes == 15
    error_message = "Should accept typical flow timeout of 15"
  }
}

run "flow_timeout_valid_max_boundary" {
  command = plan
  variables {
    environment                                = "DEV"
    management_network_flow_timeout_in_minutes = 30
  }
  assert {
    condition     = output.management_network_flow_timeout_in_minutes == 30
    error_message = "Should accept flow timeout of 30 (maximum boundary)"
  }
}

# =============================================================================
# management_network_flow_timeout_in_minutes
# =============================================================================

run "flow_timeout_invalid_below_min" {
  command = plan
  variables {
    environment                                = "DEV"
    management_network_flow_timeout_in_minutes = 3
  }
  expect_failures = [var.management_network_flow_timeout_in_minutes]
}

run "flow_timeout_invalid_above_max" {
  command = plan
  variables {
    environment                                = "DEV"
    management_network_flow_timeout_in_minutes = 31
  }
  expect_failures = [var.management_network_flow_timeout_in_minutes]
}

run "flow_timeout_invalid_zero" {
  command = plan
  variables {
    environment                                = "DEV"
    management_network_flow_timeout_in_minutes = 0
  }
  expect_failures = [var.management_network_flow_timeout_in_minutes]
}

# =============================================================================
# infrastructure
# =============================================================================

run "infrastructure_valid_empty" {
  command = plan
  variables {
    environment    = "DEV"
    infrastructure = {}
  }
  assert {
    condition     = output.infrastructure == {}
    error_message = "Should accept empty infrastructure object"
  }
}

run "infrastructure_valid_region" {
  command = plan
  variables {
    environment    = "DEV"
    infrastructure = { region = "eastus" }
  }
  assert {
    condition     = output.infrastructure.region == "eastus"
    error_message = "Should accept infrastructure with valid region"
  }
}

run "infrastructure_valid_env_and_region" {
  command = plan
  variables {
    environment    = "DEV"
    infrastructure = { environment = "DEV", region = "eastus" }
  }
  assert {
    condition     = output.infrastructure.environment == "DEV"
    error_message = "Should accept infrastructure with valid environment and region"
  }
}

run "infrastructure_valid_vnet_with_arm_id" {
  command = plan
  variables {
    environment = "DEV"
    infrastructure = {
      region = "eastus"
      virtual_network = {
        management = {
          arm_id        = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet"
          address_space = ""
          subnet_mgmt = {
            arm_id = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/subnet"
            prefix = ""
          }
        }
      }
    }
  }
  assert {
    condition     = output.infrastructure.region == "eastus"
    error_message = "Should accept infrastructure with valid virtual_network arm_id"
  }
}

run "infrastructure_valid_vnet_with_address_space" {
  command = plan
  variables {
    environment = "DEV"
    infrastructure = {
      region = "eastus"
      virtual_network = {
        management = {
          arm_id        = ""
          address_space = "10.0.0.0/16"
          subnet_mgmt = {
            arm_id = ""
            prefix = "10.0.1.0/24"
          }
        }
      }
    }
  }
  assert {
    condition     = output.infrastructure.region == "eastus"
    error_message = "Should accept infrastructure with valid virtual_network address_space"
  }
}

# =============================================================================
# infrastructure
# =============================================================================

run "infrastructure_invalid_empty_region" {
  command = plan
  variables {
    environment    = "DEV"
    infrastructure = { region = "" }
  }
  expect_failures = [var.infrastructure]
}

run "infrastructure_invalid_whitespace_region" {
  command = plan
  variables {
    environment    = "DEV"
    infrastructure = { region = "   " }
  }
  expect_failures = [var.infrastructure]
}

run "infrastructure_invalid_empty_environment" {
  command = plan
  variables {
    environment    = "DEV"
    infrastructure = { environment = "" }
  }
  expect_failures = [var.infrastructure]
}

run "infrastructure_invalid_vnet_no_arm_id_or_address_space" {
  command = plan
  variables {
    environment = "DEV"
    infrastructure = {
      region = "eastus"
      virtual_network = {
        management = {
          arm_id        = ""
          address_space = ""
          subnet_mgmt = {
            arm_id = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/subnet"
            prefix = ""
          }
        }
      }
    }
  }
  expect_failures = [var.infrastructure]
}

run "infrastructure_invalid_vnet_no_subnet_arm_id_or_prefix" {
  command = plan
  variables {
    environment = "DEV"
    infrastructure = {
      region = "eastus"
      virtual_network = {
        management = {
          arm_id        = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet"
          address_space = ""
          subnet_mgmt = {
            arm_id = ""
            prefix = ""
          }
        }
      }
    }
  }
  expect_failures = [var.infrastructure]
}

# =============================================================================
# authentication
# =============================================================================

run "authentication_valid_default_user" {
  command = plan
  variables {
    environment = "DEV"
    authentication = {
      username            = "azureadm"
      path_to_public_key  = ""
      path_to_private_key = ""
    }
  }
  assert {
    condition     = output.authentication.username == "azureadm"
    error_message = "Should accept valid authentication with username"
  }
}

run "authentication_valid_custom_user" {
  command = plan
  variables {
    environment = "DEV"
    authentication = {
      username            = "deployer-admin"
      path_to_public_key  = "/path/to/key.pub"
      path_to_private_key = "/path/to/key"
    }
  }
  assert {
    condition     = output.authentication.username == "deployer-admin"
    error_message = "Should accept authentication with custom username"
  }
}

# =============================================================================
# authentication
# =============================================================================

run "authentication_invalid_empty_username" {
  command = plan
  variables {
    environment = "DEV"
    authentication = {
      username            = ""
      path_to_public_key  = ""
      path_to_private_key = ""
    }
  }
  expect_failures = [var.authentication]
}

run "authentication_invalid_whitespace_username" {
  command = plan
  variables {
    environment = "DEV"
    authentication = {
      username            = "   "
      path_to_public_key  = ""
      path_to_private_key = ""
    }
  }
  expect_failures = [var.authentication]
}

# =============================================================================
# spn_id
# =============================================================================

run "spn_id_valid_empty" {
  command = plan
  variables {
    environment = "DEV"
    spn_id      = ""
  }
  assert {
    condition     = output.spn_id == ""
    error_message = "Should accept empty spn_id"
  }
}

run "spn_id_valid_uuid" {
  command = plan
  variables {
    environment = "DEV"
    spn_id      = "12345678-1234-1234-1234-123456789012"
  }
  assert {
    condition     = output.spn_id == "12345678-1234-1234-1234-123456789012"
    error_message = "Should accept 36-character spn_id"
  }
}

# =============================================================================
# spn_id
# =============================================================================

run "spn_id_invalid_short" {
  command = plan
  variables {
    environment = "DEV"
    spn_id      = "short"
  }
  expect_failures = [var.spn_id]
}

# =============================================================================
# management_dns_subscription_id
# =============================================================================

run "mgmt_dns_sub_id_valid_empty" {
  command = plan
  variables {
    environment                    = "DEV"
    management_dns_subscription_id = ""
  }
  assert {
    condition     = output.management_dns_subscription_id == ""
    error_message = "Should accept empty management_dns_subscription_id"
  }
}

run "mgmt_dns_sub_id_valid_uuid" {
  command = plan
  variables {
    environment                    = "DEV"
    management_dns_subscription_id = "abcdefab-abcd-abcd-abcd-abcdefabcdef"
  }
  assert {
    condition     = output.management_dns_subscription_id == "abcdefab-abcd-abcd-abcd-abcdefabcdef"
    error_message = "Should accept 36-character management_dns_subscription_id"
  }
}

# =============================================================================
# management_dns_subscription_id
# =============================================================================

run "mgmt_dns_sub_id_invalid_length" {
  command = plan
  variables {
    environment                    = "DEV"
    management_dns_subscription_id = "invalid-length"
  }
  expect_failures = [var.management_dns_subscription_id]
}

# =============================================================================
# privatelink_dns_subscription_id
# =============================================================================

run "privatelink_dns_sub_id_valid_empty" {
  command = plan
  variables {
    environment                     = "DEV"
    privatelink_dns_subscription_id = ""
  }
  assert {
    condition     = output.privatelink_dns_subscription_id == ""
    error_message = "Should accept empty privatelink_dns_subscription_id"
  }
}

run "privatelink_dns_sub_id_valid_uuid" {
  command = plan
  variables {
    environment                     = "DEV"
    privatelink_dns_subscription_id = "12345678-abcd-efab-cdef-123456789abc"
  }
  assert {
    condition     = output.privatelink_dns_subscription_id == "12345678-abcd-efab-cdef-123456789abc"
    error_message = "Should accept 36-character privatelink_dns_subscription_id"
  }
}

# =============================================================================
# privatelink_dns_subscription_id
# =============================================================================

run "privatelink_dns_sub_id_invalid_length" {
  command = plan
  variables {
    environment                     = "DEV"
    privatelink_dns_subscription_id = "not-valid"
  }
  expect_failures = [var.privatelink_dns_subscription_id]
}

# =============================================================================
# app_registration_app_id
# =============================================================================

run "app_reg_id_valid_empty" {
  command = plan
  variables {
    environment             = "DEV"
    app_registration_app_id = ""
  }
  assert {
    condition     = output.app_registration_app_id == ""
    error_message = "Should accept empty app_registration_app_id"
  }
}

run "app_reg_id_valid_uuid" {
  command = plan
  variables {
    environment             = "DEV"
    app_registration_app_id = "aabbccdd-1122-3344-5566-778899aabbcc"
  }
  assert {
    condition     = output.app_registration_app_id == "aabbccdd-1122-3344-5566-778899aabbcc"
    error_message = "Should accept 36-character app_registration_app_id"
  }
}

# =============================================================================
# app_registration_app_id
# =============================================================================

run "app_reg_id_invalid_length" {
  command = plan
  variables {
    environment             = "DEV"
    app_registration_app_id = "too-short-id"
  }
  expect_failures = [var.app_registration_app_id]
}
