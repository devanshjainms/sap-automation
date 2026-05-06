## Section 1: Location and Environment Processing
##
## Tests how input parameters are sanitized, truncated, and mapped into
## the internal local values that all other naming logic depends on:
## - location_short: region_mapping lookup with "UNKN" fallback
## - env_verified: upper(substr(environment, 0, 5))
## - deployer_env_verified, landscape_env_verified, library_env_verified: tier overrides
## - sap_vnet_verified, dep_vnet_verified: sanitized+truncated VNET names
## - random_id_verified: upper(substr(random_id, 0, 3))
## - random_id_vm_verified: lower(substr(random_id, 0, 3))
## - random_id_virt_vm_verified: lower(substr(random_id, 0, 2))

variables {
  environment          = "DEV"
  location             = "eastus"
  sap_sid              = "HN1"
  db_sid               = "HDB"
  web_sid              = "WEB"
  random_id            = "abc123"
  management_vnet_name = "DEP-VNET"
  sap_vnet_name        = "SAP-VNET"
  db_server_count      = 1
  app_server_count     = 1
  scs_server_count     = 1
  web_server_count     = 1
  deployer_vm_count    = 1
  iscsi_server_count   = 1
}

## ─────────────────────────────────────────────────────────────────────────────
## Location Short Code Mapping
## Formula: upper(try(var.region_mapping[var.location], "unkn"))
## ─────────────────────────────────────────────────────────────────────────────

run "location_eastus_maps_to_EAUS" {
  command = plan

  assert {
    condition     = output.naming_new.location_short == "EAUS"
    error_message = "eastus should map to EAUS"
  }
}

run "location_westeurope_maps_to_WEEU" {
  command = plan

  variables {
    location = "westeurope"
  }

  assert {
    condition     = output.naming_new.location_short == "WEEU"
    error_message = "westeurope should map to WEEU"
  }
}

run "location_germanywestcentral_maps_to_GEWC" {
  command = plan

  variables {
    location = "germanywestcentral"
  }

  assert {
    condition     = output.naming_new.location_short == "GEWC"
    error_message = "germanywestcentral should map to GEWC"
  }
}

run "location_unknown_region_falls_back_to_UNKN" {
  command = plan

  variables {
    location = "madeupregion"
  }

  assert {
    condition     = output.naming_new.location_short == "UNKN"
    error_message = "Unknown region should fall back to UNKN via try() default"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Deployer Location Override
## Formula: length(deployer_location) > 0 ? lookup(deployer_location) : location_short
## Only affects: deployer prefix, deployer storage, deployer KV, deployer VMs
## ─────────────────────────────────────────────────────────────────────────────

run "deployer_location_overrides_deployer_tier_only" {
  command = plan

  variables {
    deployer_location = "westeurope"
  }

  # Deployer prefix uses overridden location
  assert {
    condition     = output.naming.prefix.DEPLOYER == "DEV-WEEU-DEPVNET"
    error_message = "Deployer prefix should use WEEU from deployer_location override"
  }

  # Other tiers unaffected
  assert {
    condition     = output.naming.prefix.WORKLOAD_ZONE == "DEV-EAUS-SAPVNET"
    error_message = "Workload zone should still use main location EAUS"
  }

  assert {
    condition     = output.naming.prefix.LIBRARY == "DEV-EAUS"
    error_message = "Library should still use main location EAUS"
  }

  assert {
    condition     = output.naming.prefix.SDU == "DEV-EAUS-SAPVNET-HN1"
    error_message = "SDU should still use main location EAUS"
  }
}

run "deployer_location_empty_inherits_main_location" {
  command = plan

  variables {
    deployer_location = ""
  }

  assert {
    condition     = output.naming.prefix.DEPLOYER == "DEV-EAUS-DEPVNET"
    error_message = "Empty deployer_location should inherit main location (EAUS)"
  }
}

run "deployer_location_unknown_maps_to_UNKN" {
  command = plan

  variables {
    deployer_location = "fakeregion"
  }

  assert {
    condition     = output.naming.prefix.DEPLOYER == "DEV-UNKN-DEPVNET"
    error_message = "Unknown deployer_location should fall back to UNKN"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Environment Truncation
## Formula: upper(substr(var.environment, 0, sapautomation_name_limits.environment_variable_length))
## Default limit: 5 characters
## ─────────────────────────────────────────────────────────────────────────────

run "environment_exactly_5_chars_no_truncation" {
  command = plan

  variables {
    environment = "PROD1"
  }

  # env_verified = "PROD1" (5 chars, no truncation)
  assert {
    condition     = output.naming.prefix.WORKLOAD_ZONE == "PROD1-EAUS-SAPVNET"
    error_message = "5-char environment should not be truncated"
  }
}

run "environment_exceeds_5_truncated_to_5" {
  command = plan

  variables {
    environment = "PRODUCTION"
  }

  # env_verified = upper(substr("PRODUCTION", 0, 5)) = "PRODU"
  assert {
    condition     = output.naming.prefix.WORKLOAD_ZONE == "PRODU-EAUS-SAPVNET"
    error_message = "Environment 'PRODUCTION' should truncate to 'PRODU' (5 chars)"
  }
}

run "environment_short_3_chars_no_padding" {
  command = plan

  variables {
    environment = "QA1"
  }

  # env_verified = "QA1" (3 chars, no padding)
  assert {
    condition     = output.naming.prefix.WORKLOAD_ZONE == "QA1-EAUS-SAPVNET"
    error_message = "3-char environment should pass through without padding"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Tier-specific Environment Overrides
## Each tier can override the base environment:
## - deployer_environment → deployer_env_verified
## - landscape_environment → landscape_env_verified
## - library_environment → library_env_verified
## All subject to same 5-char truncation.
## ─────────────────────────────────────────────────────────────────────────────

run "deployer_environment_override_truncated" {
  command = plan

  variables {
    deployer_environment = "MGMTLONG"
  }

  # deployer_env_verified = upper(substr("MGMTLONG", 0, 5)) = "MGMTL"
  assert {
    condition     = output.naming.prefix.DEPLOYER == "MGMTL-EAUS-DEPVNET"
    error_message = "Deployer env override should truncate to 5 chars: MGMTL"
  }

  # Other tiers use base environment
  assert {
    condition     = output.naming.prefix.WORKLOAD_ZONE == "DEV-EAUS-SAPVNET"
    error_message = "Workload zone should use base env 'DEV' not deployer override"
  }
}

run "landscape_environment_override" {
  command = plan

  variables {
    landscape_environment = "QA"
  }

  assert {
    condition     = output.naming.prefix.WORKLOAD_ZONE == "QA-EAUS-SAPVNET"
    error_message = "Workload zone should use landscape_environment 'QA'"
  }

  assert {
    condition     = output.naming.prefix.DEPLOYER == "DEV-EAUS-DEPVNET"
    error_message = "Deployer should still use base environment"
  }
}

run "library_environment_override" {
  command = plan

  variables {
    library_environment = "SHARED"
  }

  # library_env_verified = upper(substr("SHARED", 0, 5)) = "SHARE"
  assert {
    condition     = output.naming.prefix.LIBRARY == "SHARE-EAUS"
    error_message = "Library env 'SHARED' should truncate to 'SHARE'"
  }
}

run "all_tier_overrides_independent" {
  command = plan

  variables {
    deployer_environment  = "CTRL"
    landscape_environment = "SAND"
    library_environment   = "GLBL"
  }

  assert {
    condition     = output.naming.prefix.DEPLOYER == "CTRL-EAUS-DEPVNET"
    error_message = "Deployer uses its own override"
  }

  assert {
    condition     = output.naming.prefix.WORKLOAD_ZONE == "SAND-EAUS-SAPVNET"
    error_message = "Workload zone uses landscape override"
  }

  assert {
    condition     = output.naming.prefix.LIBRARY == "GLBL-EAUS"
    error_message = "Library uses its own override"
  }

  # SDU always uses the base environment
  assert {
    condition     = output.naming.prefix.SDU == "DEV-EAUS-SAPVNET-HN1"
    error_message = "SDU always uses base environment, not any tier override"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## VNET Name Sanitization
## Formula: upper(trim(substr(replace(var.sap_vnet_name, "/[^A-Za-z0-9]/", ""), 0, 7), "-_"))
## - Removes all non-alphanumeric chars
## - Truncates to 7 chars (sap_vnet_length default)
## - Trims leading/trailing hyphens and underscores
## - Uppercased
## ─────────────────────────────────────────────────────────────────────────────

run "vnet_name_special_chars_removed" {
  command = plan

  variables {
    sap_vnet_name = "my-sap_vnet.test"
  }

  # After regex removal: "mysapvnettest", truncated to 7: "MYSAPVN"
  assert {
    condition     = output.naming.prefix.WORKLOAD_ZONE == "DEV-EAUS-MYSAPVN"
    error_message = "VNET name should have special chars removed and truncate to 7: MYSAPVN"
  }
}

run "vnet_name_already_short_and_clean" {
  command = plan

  variables {
    sap_vnet_name = "SAP01"
  }

  assert {
    condition     = output.naming.prefix.WORKLOAD_ZONE == "DEV-EAUS-SAP01"
    error_message = "Clean short VNET name should pass through uppercased: SAP01"
  }
}

run "management_vnet_name_sanitized_for_deployer" {
  command = plan

  variables {
    management_vnet_name = "mgmt_vnet-01!"
  }

  # After regex: "mgmtvnet01", truncated to 7: "MGMTVNE"
  assert {
    condition     = output.naming.prefix.DEPLOYER == "DEV-EAUS-MGMTVNE"
    error_message = "Management VNET 'mgmt_vnet-01!' should sanitize to 'MGMTVNE'"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Random ID Processing
## - random_id_verified: upper(substr(random_id, 0, 3))  → used in KV/storage names
## - random_id_vm_verified: lower(substr(random_id, 0, 3)) → used in VM names
## - random_id_virt_vm_verified: lower(substr(random_id, 0, 2)) → used in secondary DNS
## ─────────────────────────────────────────────────────────────────────────────

run "random_id_truncation_in_keyvault" {
  command = plan

  variables {
    random_id = "xyz789longstring"
  }

  # random_id_verified = upper(substr("xyz789longstring", 0, 3)) = "XYZ"
  assert {
    condition     = output.naming.keyvault_names.DEPLOYER.private_access == "DEVEAUSDEPVNETprvtXYZ"
    error_message = "KV uses upper 3-char random_id: XYZ"
  }
}

run "random_id_truncation_in_vm_names" {
  command = plan

  variables {
    random_id = "XYZ789"
  }

  # random_id_vm_verified = lower(substr("XYZ789", 0, 3)) = "xyz"
  assert {
    condition     = output.naming.virtualmachine_names.APP_COMPUTERNAME[0] == "hn1app00lxyz"
    error_message = "VM names use lower 3-char random_id: xyz"
  }
}

run "random_id_2char_in_secondary_dns" {
  command = plan

  variables {
    random_id = "XYZ789"
  }

  # random_id_virt_vm_verified = lower(substr("XYZ789", 0, 2)) = "xy"
  assert {
    condition     = output.naming.virtualmachine_names.SCS_SECONDARY_DNSNAME[0] == "vhn1s00lxy"
    error_message = "SCS secondary DNS uses lower 2-char random_id: xy"
  }
}

run "random_id_2char_in_hana_computer_name" {
  command = plan

  variables {
    random_id = "XYZ789"
  }

  # HANA computer name uses substr(random_id_vm_verified, 0, 2) = "xy"
  assert {
    condition     = output.naming.virtualmachine_names.HANA_COMPUTERNAME[0] == "hn1dhdb00l0xy"
    error_message = "HANA computer name uses lower 2-char random_id: xy"
  }
}
