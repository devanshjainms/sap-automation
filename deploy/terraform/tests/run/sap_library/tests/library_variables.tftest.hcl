/*
 * SAP Library Module — Variable Validation Tests
 *
 * Tests input validation logic for the sap_library root module.
 * Uses a helper module (tests/setup) to isolate from provider-dependent resources.
 *
 * Coverage:
 *   - environment: must be 1-5 characters (positive + negative)
 *   - subscription_id: must be 36 characters if provided (positive + negative)
 *   - spn_id: must be 36 characters if provided (positive + negative)
 *   - management_dns_subscription_id: must be 36 characters if provided (positive + negative)
 *   - privatelink_dns_subscription_id: must be 36 characters if provided (positive + negative)
 *
 * Excluded (require provider::azurerm::parse_resource_id):
 *   - resourcegroup_arm_id
 *   - library_sapmedia_arm_id
 *   - library_terraform_state_arm_id
 *   - spn_keyvault_id
 *   - tfstate_resource_id
 *   - additional_network_id
 *   - management_network_id
 *   - application_configuration_id
 *
 * Run: cd deploy/terraform/tests/run/sap_library && terraform test
 */

# ============================================================================ #
#  environment — positive scenarios
# ============================================================================ #

run "environment_single_char" {
  command = plan

  variables {
    environment = "D"
  }

  assert {
    condition     = output.environment == "D"
    error_message = "Expected environment to be 'D'."
  }
}

run "environment_three_chars" {
  command = plan

  variables {
    environment = "DEV"
  }

  assert {
    condition     = output.environment == "DEV"
    error_message = "Expected environment to be 'DEV'."
  }
}

run "environment_max_five_chars" {
  command = plan

  variables {
    environment = "ABCDE"
  }

  assert {
    condition     = output.environment == "ABCDE"
    error_message = "Expected environment to be 'ABCDE'."
  }
}

# ============================================================================ #
#  environment — negative scenarios
# ============================================================================ #

run "environment_empty_rejected" {
  command = plan

  variables {
    environment = ""
  }

  expect_failures = [
    var.environment,
  ]
}

run "environment_six_chars_rejected" {
  command = plan

  variables {
    environment = "ABCDEF"
  }

  expect_failures = [
    var.environment,
  ]
}

run "environment_too_long_rejected" {
  command = plan

  variables {
    environment = "PRODUCTION"
  }

  expect_failures = [
    var.environment,
  ]
}

# ============================================================================ #
#  subscription_id — positive scenarios
# ============================================================================ #

run "subscription_id_empty_accepted" {
  command = plan

  variables {
    environment     = "DEV"
    subscription_id = ""
  }

  assert {
    condition     = output.subscription_id == ""
    error_message = "Expected empty subscription_id to be accepted."
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
    error_message = "Expected valid 36-char subscription_id to be accepted."
  }
}

# ============================================================================ #
#  subscription_id — negative scenarios
# ============================================================================ #

run "subscription_id_too_short_rejected" {
  command = plan

  variables {
    environment     = "DEV"
    subscription_id = "short"
  }

  expect_failures = [
    var.subscription_id,
  ]
}

run "subscription_id_too_long_rejected" {
  command = plan

  variables {
    environment     = "DEV"
    subscription_id = "12345678-1234-1234-1234-1234567890123"
  }

  expect_failures = [
    var.subscription_id,
  ]
}

# ============================================================================ #
#  spn_id — positive scenarios
# ============================================================================ #

run "spn_id_empty_accepted" {
  command = plan

  variables {
    environment = "DEV"
    spn_id      = ""
  }

  assert {
    condition     = output.spn_id == ""
    error_message = "Expected empty spn_id to be accepted."
  }
}

run "spn_id_valid_uuid" {
  command = plan

  variables {
    environment = "DEV"
    spn_id      = "abcdefab-abcd-abcd-abcd-abcdefabcdef"
  }

  assert {
    condition     = output.spn_id == "abcdefab-abcd-abcd-abcd-abcdefabcdef"
    error_message = "Expected valid 36-char spn_id to be accepted."
  }
}

# ============================================================================ #
#  spn_id — negative scenarios
# ============================================================================ #

run "spn_id_too_short_rejected" {
  command = plan

  variables {
    environment = "DEV"
    spn_id      = "invalid-length"
  }

  expect_failures = [
    var.spn_id,
  ]
}

run "spn_id_too_long_rejected" {
  command = plan

  variables {
    environment = "DEV"
    spn_id      = "abcdefab-abcd-abcd-abcd-abcdefabcdef0"
  }

  expect_failures = [
    var.spn_id,
  ]
}

# ============================================================================ #
#  management_dns_subscription_id — positive scenarios
# ============================================================================ #

run "mgmt_dns_sub_id_empty_accepted" {
  command = plan

  variables {
    environment                    = "DEV"
    management_dns_subscription_id = ""
  }

  assert {
    condition     = output.management_dns_subscription_id == ""
    error_message = "Expected empty management_dns_subscription_id to be accepted."
  }
}

run "mgmt_dns_sub_id_valid_uuid" {
  command = plan

  variables {
    environment                    = "DEV"
    management_dns_subscription_id = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  }

  assert {
    condition     = output.management_dns_subscription_id == "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    error_message = "Expected valid 36-char management_dns_subscription_id to be accepted."
  }
}

# ============================================================================ #
#  management_dns_subscription_id — negative scenarios
# ============================================================================ #

run "mgmt_dns_sub_id_too_short_rejected" {
  command = plan

  variables {
    environment                    = "DEV"
    management_dns_subscription_id = "too-short"
  }

  expect_failures = [
    var.management_dns_subscription_id,
  ]
}

run "mgmt_dns_sub_id_too_long_rejected" {
  command = plan

  variables {
    environment                    = "DEV"
    management_dns_subscription_id = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeeee"
  }

  expect_failures = [
    var.management_dns_subscription_id,
  ]
}

# ============================================================================ #
#  privatelink_dns_subscription_id — positive scenarios
# ============================================================================ #

run "plink_dns_sub_id_empty_accepted" {
  command = plan

  variables {
    environment                     = "DEV"
    privatelink_dns_subscription_id = ""
  }

  assert {
    condition     = output.privatelink_dns_subscription_id == ""
    error_message = "Expected empty privatelink_dns_subscription_id to be accepted."
  }
}

run "plink_dns_sub_id_valid_uuid" {
  command = plan

  variables {
    environment                     = "DEV"
    privatelink_dns_subscription_id = "11111111-2222-3333-4444-555555555555"
  }

  assert {
    condition     = output.privatelink_dns_subscription_id == "11111111-2222-3333-4444-555555555555"
    error_message = "Expected valid 36-char privatelink_dns_subscription_id to be accepted."
  }
}

# ============================================================================ #
#  privatelink_dns_subscription_id — negative scenarios
# ============================================================================ #

run "plink_dns_sub_id_too_short_rejected" {
  command = plan

  variables {
    environment                     = "DEV"
    privatelink_dns_subscription_id = "not-valid"
  }

  expect_failures = [
    var.privatelink_dns_subscription_id,
  ]
}

run "plink_dns_sub_id_too_long_rejected" {
  command = plan

  variables {
    environment                     = "DEV"
    privatelink_dns_subscription_id = "11111111-2222-3333-4444-5555555555556"
  }

  expect_failures = [
    var.privatelink_dns_subscription_id,
  ]
}

# ============================================================================ #
#  Combined positive scenario — all variables valid together
# ============================================================================ #

run "all_variables_valid_combined" {
  command = plan

  variables {
    environment                     = "QA"
    subscription_id                 = "12345678-1234-1234-1234-123456789012"
    spn_id                          = "abcdefab-abcd-abcd-abcd-abcdefabcdef"
    management_dns_subscription_id  = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    privatelink_dns_subscription_id = "11111111-2222-3333-4444-555555555555"
  }

  assert {
    condition     = output.environment == "QA"
    error_message = "Expected environment 'QA'."
  }

  assert {
    condition     = output.subscription_id == "12345678-1234-1234-1234-123456789012"
    error_message = "Expected subscription_id to match input."
  }

  assert {
    condition     = output.spn_id == "abcdefab-abcd-abcd-abcd-abcdefabcdef"
    error_message = "Expected spn_id to match input."
  }
}
