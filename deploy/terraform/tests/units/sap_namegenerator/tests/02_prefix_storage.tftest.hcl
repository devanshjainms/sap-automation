## Section 2: Resource Group Prefixes and Storage Account Naming
##
## Tests the computed prefixes and storage account names:
## - Prefix: deployer_name, landscape_name, library_name, sdu_name
## - custom_prefix override behavior
## - separator (default "_", empty with custom_prefix)
## - Storage accounts: 24-char max, lowercase alphanumeric, sanitized
## - Appconfig and Network Security Perimeter names

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
## Prefix Computation (no custom_prefix)
## deployer_name = upper("{deployer_env}-{deployer_location_short}-{dep_vnet}")
## landscape_name = upper("{landscape_env}-{location_short}-{sap_vnet}")
## library_name = upper("{library_env}-{location_short}")
## sdu_name = upper("{env}-{location_short}-{sap_vnet}-{sid}")  (no codename)
## sdu_name = upper("{env}-{location_short}-{sap_vnet}_{codename}-{sid}")  (with codename)
## ─────────────────────────────────────────────────────────────────────────────

run "prefix_deployer_format" {
  command = plan

  # deployer_name = upper("DEV-EAUS-DEPVNET")
  assert {
    condition     = output.naming.prefix.DEPLOYER == "DEV-EAUS-DEPVNET"
    error_message = "Deployer prefix: {env}-{location_short}-{dep_vnet_verified}"
  }
}

run "prefix_workload_zone_format" {
  command = plan

  # landscape_name = upper("DEV-EAUS-SAPVNET")
  assert {
    condition     = output.naming.prefix.WORKLOAD_ZONE == "DEV-EAUS-SAPVNET"
    error_message = "Workload zone prefix: {env}-{location_short}-{sap_vnet_verified}"
  }
}

run "prefix_library_format_no_vnet" {
  command = plan

  # library_name = upper("DEV-EAUS")
  assert {
    condition     = output.naming.prefix.LIBRARY == "DEV-EAUS"
    error_message = "Library prefix has no VNET component: {env}-{location_short}"
  }
}

run "prefix_sdu_without_codename" {
  command = plan

  # sdu_name = upper("DEV-EAUS-SAPVNET-HN1")
  assert {
    condition     = output.naming.prefix.SDU == "DEV-EAUS-SAPVNET-HN1"
    error_message = "SDU prefix without codename: {env}-{location}-{vnet}-{sid}"
  }
}

run "prefix_sdu_with_codename" {
  command = plan

  variables {
    codename = "MYAPP"
  }

  # sdu_name = upper("DEV-EAUS-SAPVNET_MYAPP-HN1")
  assert {
    condition     = output.naming.prefix.SDU == "DEV-EAUS-SAPVNET_MYAPP-HN1"
    error_message = "SDU with codename: {env}-{location}-{vnet}_{codename}-{sid}"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Custom Prefix Override
## When custom_prefix is non-empty:
## - All prefix fields return the custom_prefix value
## - Separator becomes "" (empty)
## ─────────────────────────────────────────────────────────────────────────────

run "custom_prefix_overrides_all_prefixes" {
  command = plan

  variables {
    custom_prefix = "MYPREFIX"
  }

  assert {
    condition     = output.naming.prefix.DEPLOYER == "MYPREFIX"
    error_message = "Custom prefix overrides deployer prefix"
  }

  assert {
    condition     = output.naming.prefix.WORKLOAD_ZONE == "MYPREFIX"
    error_message = "Custom prefix overrides workload zone prefix"
  }

  assert {
    condition     = output.naming.prefix.SDU == "MYPREFIX"
    error_message = "Custom prefix overrides SDU prefix"
  }

  assert {
    condition     = output.naming.prefix.LIBRARY == "MYPREFIX"
    error_message = "Custom prefix overrides library prefix"
  }
}

run "custom_prefix_makes_separator_empty" {
  command = plan

  variables {
    custom_prefix = "MYPREFIX"
  }

  assert {
    condition     = output.naming.separator == ""
    error_message = "Separator should be empty when custom_prefix is used"
  }
}

run "default_separator_is_underscore" {
  command = plan

  assert {
    condition     = output.naming.separator == "_"
    error_message = "Default separator should be underscore when no custom_prefix"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Storage Account Names
## Formula: substr(replace(lower(format(...)), "/[^a-z0-9]/", ""), 0, 24)
## - All lowercase
## - Only alphanumeric characters
## - Max 24 characters (Azure limit)
## ─────────────────────────────────────────────────────────────────────────────

run "deployer_storage_account_name" {
  command = plan

  # Format: "{env}{location}{vnet}diag{random}" → "deveausdepvnetdiagabc"
  assert {
    condition     = output.naming.storageaccount_names.DEPLOYER == "deveausdepvnetdiagabc"
    error_message = "Deployer storage: lower({env}{location}{dep_vnet}diag{random})"
  }
}

run "sdu_storage_account_name" {
  command = plan

  # Format: "{env}{location}{sap_vnet}diag{random}" → "deveaussapvnetdiagabc"
  assert {
    condition     = output.naming.storageaccount_names.SDU == "deveaussapvnetdiagabc"
    error_message = "SDU storage: lower({env}{location}{sap_vnet}diag{random})"
  }
}

run "landscape_storage_accounts" {
  command = plan

  assert {
    condition     = output.naming.storageaccount_names.WORKLOAD_ZONE.landscape_storageaccount_name == "deveaussapvnetdiagabc"
    error_message = "Landscape diag storage: {env}{location}{vnet}diag{random}"
  }

  # witness: "{env}{location}{vnet}witness{random}" = "deveaussapvnetwitnessabc" (24 chars, fits)
  assert {
    condition     = output.naming.storageaccount_names.WORKLOAD_ZONE.witness_storageaccount_name == "deveaussapvnetwitnessabc"
    error_message = "Witness storage: {env}{location}{vnet}witness{random} (24 chars, fits exactly)"
  }

  # transport: "{env}{location}{vnet}transport{random}" = "deveaussapvnettransportabc" (26 chars, truncated)
  assert {
    condition     = output.naming.storageaccount_names.WORKLOAD_ZONE.landscape_shared_transport_storage_account_name == "deveaussapvnettransporta"
    error_message = "Transport storage: truncated to 24 chars"
  }

  # install: "{env}{location}{vnet}install{random}" = "deveaussapvnetinstallabc" (24 chars, fits)
  assert {
    condition     = output.naming.storageaccount_names.WORKLOAD_ZONE.landscape_shared_install_storage_account_name == "deveaussapvnetinstallabc"
    error_message = "Install storage: {env}{location}{vnet}install{random} (24 chars, fits exactly)"
  }
}

run "library_storage_accounts" {
  command = plan

  # saplib: "{env}{location}saplib{random}" → "deveaussaplibabc"
  assert {
    condition     = output.naming.storageaccount_names.LIBRARY.library_storageaccount_name == "deveaussaplibabc"
    error_message = "Library storage: {env}{location}saplib{random}"
  }

  # tfstate: "{env}{location}tfstate{random}" → "deveaustfstateabc"
  assert {
    condition     = output.naming.storageaccount_names.LIBRARY.terraformstate_storageaccount_name == "deveaustfstateabc"
    error_message = "TF state storage: {env}{location}tfstate{random}"
  }
}

run "storage_accounts_all_under_24_chars_with_long_inputs" {
  command = plan

  variables {
    environment   = "PRODUCTION"
    location      = "germanywestcentral"
    sap_vnet_name = "VERY-LONG-NETWORK-NAME"
  }

  # EDGE_CASE: Long inputs cause truncation that may clip the random suffix,
  # reducing name uniqueness. All must still be ≤24 chars.
  assert {
    condition     = length(output.naming.storageaccount_names.SDU) <= 24
    error_message = "SDU storage must not exceed 24 chars"
  }

  assert {
    condition     = length(output.naming.storageaccount_names.DEPLOYER) <= 24
    error_message = "Deployer storage must not exceed 24 chars"
  }

  assert {
    condition     = length(output.naming.storageaccount_names.WORKLOAD_ZONE.landscape_storageaccount_name) <= 24
    error_message = "Landscape storage must not exceed 24 chars"
  }

  assert {
    condition     = length(output.naming.storageaccount_names.WORKLOAD_ZONE.witness_storageaccount_name) <= 24
    error_message = "Witness storage must not exceed 24 chars"
  }

  assert {
    condition     = length(output.naming.storageaccount_names.WORKLOAD_ZONE.landscape_shared_transport_storage_account_name) <= 24
    error_message = "Transport storage must not exceed 24 chars"
  }

  assert {
    condition     = length(output.naming.storageaccount_names.WORKLOAD_ZONE.landscape_shared_install_storage_account_name) <= 24
    error_message = "Install storage must not exceed 24 chars"
  }

  assert {
    condition     = length(output.naming.storageaccount_names.LIBRARY.library_storageaccount_name) <= 24
    error_message = "Library storage must not exceed 24 chars"
  }

  assert {
    condition     = length(output.naming.storageaccount_names.LIBRARY.terraformstate_storageaccount_name) <= 24
    error_message = "TF state storage must not exceed 24 chars"
  }
}

run "storage_truncation_exact_values" {
  command = plan

  variables {
    environment   = "PRODUCTION"
    location      = "germanywestcentral"
    sap_vnet_name = "SAP-LONG-NETWORK"
  }

  # env_verified = "PRODU", location_short = "GEWC", sap_vnet_verified = "SAPLONG"
  # transport raw: "produgewcsaplongtransportabc" (28 chars) → truncated to 24
  assert {
    condition     = output.naming.storageaccount_names.WORKLOAD_ZONE.landscape_shared_transport_storage_account_name == "produgewcsaplongtranspor"
    error_message = "Transport with long inputs truncates at 24 chars, clipping random_id"
  }

  # witness raw: "produgewcsaplongwitnessabc" (26 chars) → truncated to 24
  assert {
    condition     = output.naming.storageaccount_names.WORKLOAD_ZONE.witness_storageaccount_name == "produgewcsaplongwitnessa"
    error_message = "Witness truncated to 24 chars with partial random suffix"
  }
}

run "storage_with_deployer_location_override" {
  command = plan

  variables {
    deployer_location = "westeurope"
  }

  # Deployer storage uses deployer_location_short = WEEU
  assert {
    condition     = output.naming.storageaccount_names.DEPLOYER == "devweeudepvnetdiagabc"
    error_message = "Deployer storage uses deployer_location_short (WEEU)"
  }

  # Other tier storages use main location
  assert {
    condition     = output.naming.storageaccount_names.SDU == "deveaussapvnetdiagabc"
    error_message = "SDU storage still uses main location (EAUS)"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Appconfig Name
## Formula: substr(replace(lower("{deployer_env}{deployer_location}apc{random}"), "/[^a-z0-9]/", ""), 0, 24)
## ─────────────────────────────────────────────────────────────────────────────

run "appconfig_name_format" {
  command = plan

  # "deveausapcabc"
  assert {
    condition     = output.naming_new.appconfig_name == "deveausapcabc"
    error_message = "Appconfig name: lower({deployer_env}{deployer_location}apc{random})"
  }
}

run "appconfig_with_deployer_location_override" {
  command = plan

  variables {
    deployer_location = "westeurope"
  }

  assert {
    condition     = output.naming_new.appconfig_name == "devweeuapcabc"
    error_message = "Appconfig uses deployer_location_short (WEEU) when overridden"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Network Security Perimeter Name
## Formula: upper("{env_verified}-{location_short}_network_security_perimeter")
## ─────────────────────────────────────────────────────────────────────────────

run "network_security_perimeter_name" {
  command = plan

  assert {
    condition     = output.naming_new.network_security_perimeter_name == "DEV-EAUS_NETWORK_SECURITY_PERIMETER"
    error_message = "NSP: upper({env}-{location}_network_security_perimeter)"
  }
}
