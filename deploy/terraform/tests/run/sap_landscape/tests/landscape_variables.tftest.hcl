/*
 * SAP Landscape Module — Variable Validation Tests
 *
 * Tests input validation logic for the sap_landscape root module.
 * Uses a helper module to isolate from provider-dependent resources.
 *
 * Coverage:
 *   - environment: must be 1-5 characters
 *   - subscription_id: must be 36 characters if provided
 *   - management_subscription_id: must be 36 characters if provided
 *   - network_flow_timeout_in_minutes: must be 4-30 if set, null allowed
 *   - management_dns_subscription_id: must be 36 characters if provided
 *   - privatelink_dns_subscription_id: must be 36 characters if provided
 *   - spn_id: must be 36 characters if provided
 *
 * Run: cd deploy/terraform/tests/run/sap_landscape && terraform test
 */

# ==============================================================================
# POSITIVE TESTS — environment
# ==============================================================================

run "environment_single_char" {
  command = plan
  variables {
    environment = "D"
  }
  assert {
    condition     = output.environment == "D"
    error_message = "Single character environment should be valid."
  }
}

run "environment_typical_value" {
  command = plan
  variables {
    environment = "DEV"
  }
  assert {
    condition     = output.environment == "DEV"
    error_message = "Typical 3-character environment should be valid."
  }
}

run "environment_max_length" {
  command = plan
  variables {
    environment = "ABCDE"
  }
  assert {
    condition     = output.environment == "ABCDE"
    error_message = "5-character environment (maximum) should be valid."
  }
}

# ==============================================================================
# NEGATIVE TESTS — environment
# ==============================================================================

run "environment_empty_string_rejected" {
  command = plan
  variables {
    environment = ""
  }
  expect_failures = [var.environment]
}

run "environment_too_long_rejected" {
  command = plan
  variables {
    environment = "ABCDEF"
  }
  expect_failures = [var.environment]
}

# ==============================================================================
# POSITIVE TESTS — subscription_id
# ==============================================================================

run "subscription_id_empty_allowed" {
  command = plan
  variables {
    environment     = "DEV"
    subscription_id = ""
  }
  assert {
    condition     = output.subscription_id == ""
    error_message = "Empty subscription_id should be allowed."
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
    error_message = "36-character subscription_id should be valid."
  }
}

# ==============================================================================
# NEGATIVE TESTS — subscription_id
# ==============================================================================

run "subscription_id_too_short_rejected" {
  command = plan
  variables {
    environment     = "DEV"
    subscription_id = "too-short"
  }
  expect_failures = [var.subscription_id]
}

run "subscription_id_too_long_rejected" {
  command = plan
  variables {
    environment     = "DEV"
    subscription_id = "12345678-1234-1234-1234-1234567890123"
  }
  expect_failures = [var.subscription_id]
}

# ==============================================================================
# POSITIVE TESTS — management_subscription_id
# ==============================================================================

run "management_subscription_id_empty_allowed" {
  command = plan
  variables {
    environment                = "DEV"
    management_subscription_id = ""
  }
  assert {
    condition     = output.management_subscription_id == ""
    error_message = "Empty management_subscription_id should be allowed."
  }
}

run "management_subscription_id_valid_uuid" {
  command = plan
  variables {
    environment                = "DEV"
    management_subscription_id = "abcdefab-abcd-abcd-abcd-abcdefabcdef"
  }
  assert {
    condition     = output.management_subscription_id == "abcdefab-abcd-abcd-abcd-abcdefabcdef"
    error_message = "36-character management_subscription_id should be valid."
  }
}

# ==============================================================================
# NEGATIVE TESTS — management_subscription_id
# ==============================================================================

run "management_subscription_id_invalid_rejected" {
  command = plan
  variables {
    environment                = "DEV"
    management_subscription_id = "invalid"
  }
  expect_failures = [var.management_subscription_id]
}

# ==============================================================================
# POSITIVE TESTS — network_flow_timeout_in_minutes
# ==============================================================================

run "network_flow_timeout_null_allowed" {
  command = plan
  variables {
    environment                     = "DEV"
    network_flow_timeout_in_minutes = null
  }
  assert {
    condition     = output.network_flow_timeout_in_minutes == null
    error_message = "Null network_flow_timeout_in_minutes should be allowed."
  }
}

run "network_flow_timeout_minimum_boundary" {
  command = plan
  variables {
    environment                     = "DEV"
    network_flow_timeout_in_minutes = 4
  }
  assert {
    condition     = output.network_flow_timeout_in_minutes == 4
    error_message = "Minimum value of 4 should be valid."
  }
}

run "network_flow_timeout_mid_range" {
  command = plan
  variables {
    environment                     = "DEV"
    network_flow_timeout_in_minutes = 15
  }
  assert {
    condition     = output.network_flow_timeout_in_minutes == 15
    error_message = "Mid-range value of 15 should be valid."
  }
}

run "network_flow_timeout_maximum_boundary" {
  command = plan
  variables {
    environment                     = "DEV"
    network_flow_timeout_in_minutes = 30
  }
  assert {
    condition     = output.network_flow_timeout_in_minutes == 30
    error_message = "Maximum value of 30 should be valid."
  }
}

# ==============================================================================
# NEGATIVE TESTS — network_flow_timeout_in_minutes
# ==============================================================================

run "network_flow_timeout_below_minimum_rejected" {
  command = plan
  variables {
    environment                     = "DEV"
    network_flow_timeout_in_minutes = 3
  }
  expect_failures = [var.network_flow_timeout_in_minutes]
}

run "network_flow_timeout_above_maximum_rejected" {
  command = plan
  variables {
    environment                     = "DEV"
    network_flow_timeout_in_minutes = 31
  }
  expect_failures = [var.network_flow_timeout_in_minutes]
}

run "network_flow_timeout_zero_rejected" {
  command = plan
  variables {
    environment                     = "DEV"
    network_flow_timeout_in_minutes = 0
  }
  expect_failures = [var.network_flow_timeout_in_minutes]
}

# ==============================================================================
# POSITIVE TESTS — management_dns_subscription_id
# ==============================================================================

run "management_dns_subscription_id_empty_allowed" {
  command = plan
  variables {
    environment                    = "DEV"
    management_dns_subscription_id = ""
  }
  assert {
    condition     = output.management_dns_subscription_id == ""
    error_message = "Empty management_dns_subscription_id should be allowed."
  }
}

run "management_dns_subscription_id_valid_uuid" {
  command = plan
  variables {
    environment                    = "DEV"
    management_dns_subscription_id = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  }
  assert {
    condition     = output.management_dns_subscription_id == "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    error_message = "36-character management_dns_subscription_id should be valid."
  }
}

# ==============================================================================
# NEGATIVE TESTS — management_dns_subscription_id
# ==============================================================================

run "management_dns_subscription_id_invalid_rejected" {
  command = plan
  variables {
    environment                    = "DEV"
    management_dns_subscription_id = "not-a-valid-sub-id"
  }
  expect_failures = [var.management_dns_subscription_id]
}

# ==============================================================================
# POSITIVE TESTS — privatelink_dns_subscription_id
# ==============================================================================

run "privatelink_dns_subscription_id_empty_allowed" {
  command = plan
  variables {
    environment                     = "DEV"
    privatelink_dns_subscription_id = ""
  }
  assert {
    condition     = output.privatelink_dns_subscription_id == ""
    error_message = "Empty privatelink_dns_subscription_id should be allowed."
  }
}

run "privatelink_dns_subscription_id_valid_uuid" {
  command = plan
  variables {
    environment                     = "DEV"
    privatelink_dns_subscription_id = "11111111-2222-3333-4444-555555555555"
  }
  assert {
    condition     = output.privatelink_dns_subscription_id == "11111111-2222-3333-4444-555555555555"
    error_message = "36-character privatelink_dns_subscription_id should be valid."
  }
}

# ==============================================================================
# NEGATIVE TESTS — privatelink_dns_subscription_id
# ==============================================================================

run "privatelink_dns_subscription_id_invalid_rejected" {
  command = plan
  variables {
    environment                     = "DEV"
    privatelink_dns_subscription_id = "short"
  }
  expect_failures = [var.privatelink_dns_subscription_id]
}

# ==============================================================================
# POSITIVE TESTS — spn_id
# ==============================================================================

run "spn_id_empty_allowed" {
  command = plan
  variables {
    environment = "DEV"
    spn_id      = ""
  }
  assert {
    condition     = output.spn_id == ""
    error_message = "Empty spn_id should be allowed."
  }
}

run "spn_id_valid_uuid" {
  command = plan
  variables {
    environment = "DEV"
    spn_id      = "fedcba98-7654-3210-fedc-ba9876543210"
  }
  assert {
    condition     = output.spn_id == "fedcba98-7654-3210-fedc-ba9876543210"
    error_message = "36-character spn_id should be valid."
  }
}

# ==============================================================================
# NEGATIVE TESTS — spn_id
# ==============================================================================

run "spn_id_too_short_rejected" {
  command = plan
  variables {
    environment = "DEV"
    spn_id      = "abc123"
  }
  expect_failures = [var.spn_id]
}

run "spn_id_too_long_rejected" {
  command = plan
  variables {
    environment = "DEV"
    spn_id      = "fedcba98-7654-3210-fedc-ba98765432101"
  }
  expect_failures = [var.spn_id]
}
