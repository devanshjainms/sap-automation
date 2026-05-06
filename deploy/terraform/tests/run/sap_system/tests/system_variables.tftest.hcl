/*
 * SAP System Module — Variable Validation Tests
 *
 * Tests input validation logic for the sap_system root module.
 * This is the most complex module — it deploys DB, app tier, and common infra.
 * Uses a helper module (tests/setup) to isolate from provider-dependent resources.
 *
 * Coverage:
 *   - environment: must be 1-5 characters
 *   - location: must not be empty
 *   - network_logical_name: must not be empty
 *   - database_platform: must not be empty
 *   - sid: must be exactly 3 characters
 *   - landscape_tfstate_key: must not be empty (after trimming whitespace)
 *   - subscription_id: must be 36 characters if provided
 *   - management_dns_subscription_id: must be 36 characters if provided
 *   - privatelink_dns_subscription_id: must be 36 characters if provided
 *   - database_use_avset: must be a valid boolean (not null)
 *   - database_use_ppg: must be a valid boolean (not null)
 *   - scs_server_use_avset: must be a valid boolean (not null)
 *   - scs_server_use_ppg: must be a valid boolean (not null)
 *   - application_server_use_avset: must be a valid boolean (not null)
 *   - application_server_use_ppg: must be a valid boolean (not null)
 *
 * Validations using provider::azurerm::parse_resource_id are excluded because
 * mock_provider in Terraform 1.13.2 does not support provider functions in
 * helper modules. This includes ARM ID format checks for resource group,
 * subnet, NSG, key vault, and user-assigned identity variables.
 *
 * Run: cd deploy/terraform/tests/run/sap_system && terraform test
 */

# ==============================================================================
# Positive Tests — Valid Inputs
# ==============================================================================

run "valid_minimum_inputs" {
  command = plan

  variables {
    environment           = "DEV"
    location              = "eastus"
    network_logical_name  = "sap"
    database_platform     = "HANA"
    sid                   = "HD1"
    landscape_tfstate_key = "DEV-WEEU-SAP01-INFRASTRUCTURE.terraform.tfstate"
  }

  assert {
    condition     = output.environment == "DEV"
    error_message = "Expected environment to be 'DEV'."
  }

  assert {
    condition     = output.location == "eastus"
    error_message = "Expected location to be 'eastus'."
  }

  assert {
    condition     = output.sid == "HD1"
    error_message = "Expected sid to be 'HD1'."
  }

  assert {
    condition     = output.database_platform == "HANA"
    error_message = "Expected database_platform to be 'HANA'."
  }
}

run "valid_environment_single_char" {
  command = plan

  variables {
    environment           = "D"
    location              = "westeurope"
    sid                   = "S4D"
    landscape_tfstate_key = "state.tfstate"
  }

  assert {
    condition     = output.environment == "D"
    error_message = "Single character environment should be valid."
  }
}

run "valid_environment_max_length" {
  command = plan

  variables {
    environment           = "ABCDE"
    location              = "westus2"
    sid                   = "PRD"
    landscape_tfstate_key = "state.tfstate"
  }

  assert {
    condition     = output.environment == "ABCDE"
    error_message = "Five character environment should be valid."
  }
}

run "valid_subscription_id_provided" {
  command = plan

  variables {
    environment           = "TST"
    location              = "eastus2"
    sid                   = "TS1"
    landscape_tfstate_key = "state.tfstate"
    subscription_id       = "12345678-1234-1234-1234-123456789012"
  }

  assert {
    condition     = output.subscription_id == "12345678-1234-1234-1234-123456789012"
    error_message = "A 36-character subscription_id should be accepted."
  }
}

run "valid_subscription_id_empty" {
  command = plan

  variables {
    environment           = "DEV"
    location              = "eastus"
    sid                   = "HD1"
    landscape_tfstate_key = "state.tfstate"
    subscription_id       = ""
  }

  assert {
    condition     = output.subscription_id == ""
    error_message = "An empty subscription_id should be accepted."
  }
}

run "valid_dns_subscription_ids" {
  command = plan

  variables {
    environment                     = "DEV"
    location                        = "eastus"
    sid                             = "HD1"
    landscape_tfstate_key           = "state.tfstate"
    management_dns_subscription_id  = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    privatelink_dns_subscription_id = "11111111-2222-3333-4444-555555555555"
  }

  assert {
    condition     = output.management_dns_subscription_id == "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    error_message = "A 36-character management_dns_subscription_id should be accepted."
  }

  assert {
    condition     = output.privatelink_dns_subscription_id == "11111111-2222-3333-4444-555555555555"
    error_message = "A 36-character privatelink_dns_subscription_id should be accepted."
  }
}

run "valid_database_boolean_flags" {
  command = plan

  variables {
    environment           = "DEV"
    location              = "eastus"
    sid                   = "HD1"
    landscape_tfstate_key = "state.tfstate"
    database_use_avset    = false
    database_use_ppg      = true
  }

  assert {
    condition     = output.database_use_avset == false
    error_message = "database_use_avset=false should be accepted."
  }

  assert {
    condition     = output.database_use_ppg == true
    error_message = "database_use_ppg=true should be accepted."
  }
}

run "valid_app_tier_boolean_flags" {
  command = plan

  variables {
    environment                  = "DEV"
    location                     = "eastus"
    sid                          = "HD1"
    landscape_tfstate_key        = "state.tfstate"
    scs_server_use_avset         = true
    scs_server_use_ppg           = false
    application_server_use_avset = true
    application_server_use_ppg   = false
  }

  assert {
    condition     = output.scs_server_use_avset == true
    error_message = "scs_server_use_avset=true should be accepted."
  }

  assert {
    condition     = output.application_server_use_ppg == false
    error_message = "application_server_use_ppg=false should be accepted."
  }
}

run "valid_database_platform_variants" {
  command = plan

  variables {
    environment           = "PRD"
    location              = "northeurope"
    sid                   = "DB2"
    landscape_tfstate_key = "state.tfstate"
    database_platform     = "SQLSERVER"
  }

  assert {
    condition     = output.database_platform == "SQLSERVER"
    error_message = "SQLSERVER should be a valid database_platform value."
  }
}

# ==============================================================================
# Negative Tests — Invalid Inputs (expect_failures)
# ==============================================================================

run "invalid_environment_empty" {
  command = plan

  variables {
    environment           = ""
    location              = "eastus"
    sid                   = "HD1"
    landscape_tfstate_key = "state.tfstate"
  }

  expect_failures = [
    var.environment,
  ]
}

run "invalid_environment_too_long" {
  command = plan

  variables {
    environment           = "ABCDEF"
    location              = "eastus"
    sid                   = "HD1"
    landscape_tfstate_key = "state.tfstate"
  }

  expect_failures = [
    var.environment,
  ]
}

run "invalid_location_empty" {
  command = plan

  variables {
    environment           = "DEV"
    location              = ""
    sid                   = "HD1"
    landscape_tfstate_key = "state.tfstate"
  }

  expect_failures = [
    var.location,
  ]
}

run "invalid_network_logical_name_empty" {
  command = plan

  variables {
    environment           = "DEV"
    location              = "eastus"
    sid                   = "HD1"
    landscape_tfstate_key = "state.tfstate"
    network_logical_name  = ""
  }

  expect_failures = [
    var.network_logical_name,
  ]
}

run "invalid_database_platform_empty" {
  command = plan

  variables {
    environment           = "DEV"
    location              = "eastus"
    sid                   = "HD1"
    landscape_tfstate_key = "state.tfstate"
    database_platform     = ""
  }

  expect_failures = [
    var.database_platform,
  ]
}

run "invalid_sid_too_short" {
  command = plan

  variables {
    environment           = "DEV"
    location              = "eastus"
    sid                   = "HD"
    landscape_tfstate_key = "state.tfstate"
  }

  expect_failures = [
    var.sid,
  ]
}

run "invalid_sid_too_long" {
  command = plan

  variables {
    environment           = "DEV"
    location              = "eastus"
    sid                   = "HD12"
    landscape_tfstate_key = "state.tfstate"
  }

  expect_failures = [
    var.sid,
  ]
}

run "invalid_landscape_tfstate_key_empty" {
  command = plan

  variables {
    environment           = "DEV"
    location              = "eastus"
    sid                   = "HD1"
    landscape_tfstate_key = ""
  }

  expect_failures = [
    var.landscape_tfstate_key,
  ]
}

run "invalid_landscape_tfstate_key_whitespace_only" {
  command = plan

  variables {
    environment           = "DEV"
    location              = "eastus"
    sid                   = "HD1"
    landscape_tfstate_key = "   "
  }

  expect_failures = [
    var.landscape_tfstate_key,
  ]
}

run "invalid_subscription_id_wrong_length" {
  command = plan

  variables {
    environment           = "DEV"
    location              = "eastus"
    sid                   = "HD1"
    landscape_tfstate_key = "state.tfstate"
    subscription_id       = "too-short"
  }

  expect_failures = [
    var.subscription_id,
  ]
}

run "invalid_subscription_id_too_long" {
  command = plan

  variables {
    environment           = "DEV"
    location              = "eastus"
    sid                   = "HD1"
    landscape_tfstate_key = "state.tfstate"
    subscription_id       = "12345678-1234-1234-1234-1234567890123"
  }

  expect_failures = [
    var.subscription_id,
  ]
}

run "invalid_management_dns_subscription_id" {
  command = plan

  variables {
    environment                    = "DEV"
    location                       = "eastus"
    sid                            = "HD1"
    landscape_tfstate_key          = "state.tfstate"
    management_dns_subscription_id = "not-a-valid-subscription-id"
  }

  expect_failures = [
    var.management_dns_subscription_id,
  ]
}

run "invalid_privatelink_dns_subscription_id" {
  command = plan

  variables {
    environment                     = "DEV"
    location                        = "eastus"
    sid                             = "HD1"
    landscape_tfstate_key           = "state.tfstate"
    privatelink_dns_subscription_id = "short"
  }

  expect_failures = [
    var.privatelink_dns_subscription_id,
  ]
}
