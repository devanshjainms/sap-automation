## Section 3: Key Vault Naming
##
## Tests all 8 Key Vault names (4 tiers × private/user):
## - SDU: {env}{location}{sap_vnet}{sid}p|u{random}
## - Deployer: {deployer_env}{deployer_location}{dep_vnet}prvt|user{random}
## - Landscape: {landscape_env}{location}{sap_vnet}prvt|user{random}
## - Library: {library_env}{location}SAPLIBprvt|user{random}
##
## All names have non-alphanumeric chars stripped from components.
## Azure limit: 24 chars max (though module doesn't explicitly truncate KV names).

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
## SDU Key Vault Names
## Private: format("{env}{location}{sap_vnet}{sid}p{random}")
## User: format("{env}{location}{sap_vnet}{sid}u{random}")
## Components have non-alphanumeric stripped via replace(..., "/[^A-Za-z0-9]/", "")
## ─────────────────────────────────────────────────────────────────────────────

run "sdu_keyvault_private" {
  command = plan

  # env_verified="DEV", location_short="EAUS", sap_vnet_verified="SAPVNET" (stripped),
  # sid="HN1", random_id_verified="ABC"
  # Result: "DEVEAUSSAPVNETHN1pABC"
  assert {
    condition     = output.naming.keyvault_names.SDU.private_access == "DEVEAUSSAPVNETHN1pABC"
    error_message = "SDU private KV: {env}{location}{vnet}{sid}p{random}"
  }
}

run "sdu_keyvault_user" {
  command = plan

  assert {
    condition     = output.naming.keyvault_names.SDU.user_access == "DEVEAUSSAPVNETHN1uABC"
    error_message = "SDU user KV: {env}{location}{vnet}{sid}u{random}"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Deployer Key Vault Names
## Private: format("{deployer_env}{deployer_location}{dep_vnet}prvt{random}")
## User: format("{deployer_env}{deployer_location}{dep_vnet}user{random}")
## ─────────────────────────────────────────────────────────────────────────────

run "deployer_keyvault_private" {
  command = plan

  # deployer_env="DEV", deployer_location_short="EAUS", dep_vnet="DEPVNET"
  # Result: "DEVEAUSDEPVNETprvtABC"
  assert {
    condition     = output.naming.keyvault_names.DEPLOYER.private_access == "DEVEAUSDEPVNETprvtABC"
    error_message = "Deployer private KV: {env}{location}{dep_vnet}prvt{random}"
  }
}

run "deployer_keyvault_user" {
  command = plan

  assert {
    condition     = output.naming.keyvault_names.DEPLOYER.user_access == "DEVEAUSDEPVNETuserABC"
    error_message = "Deployer user KV: {env}{location}{dep_vnet}user{random}"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Landscape (WORKLOAD_ZONE) Key Vault Names
## Private: format("{landscape_env}{location}{sap_vnet}prvt{random}")
## User: format("{landscape_env}{location}{sap_vnet}user{random}")
## ─────────────────────────────────────────────────────────────────────────────

run "landscape_keyvault_private" {
  command = plan

  assert {
    condition     = output.naming.keyvault_names.WORKLOAD_ZONE.private_access == "DEVEAUSSAPVNETprvtABC"
    error_message = "Landscape private KV: {landscape_env}{location}{sap_vnet}prvt{random}"
  }
}

run "landscape_keyvault_user" {
  command = plan

  assert {
    condition     = output.naming.keyvault_names.WORKLOAD_ZONE.user_access == "DEVEAUSSAPVNETuserABC"
    error_message = "Landscape user KV: {landscape_env}{location}{sap_vnet}user{random}"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Library Key Vault Names
## Private: format("{library_env}{location}SAPLIBprvt{random}")
## User: format("{library_env}{location}SAPLIBuser{random}")
## Note: Library KV does NOT include VNET, uses fixed "SAPLIB" string
## ─────────────────────────────────────────────────────────────────────────────

run "library_keyvault_private" {
  command = plan

  assert {
    condition     = output.naming.keyvault_names.LIBRARY.private_access == "DEVEAUSSAPLIBprvtABC"
    error_message = "Library private KV: {env}{location}SAPLIBprvt{random}"
  }
}

run "library_keyvault_user" {
  command = plan

  assert {
    condition     = output.naming.keyvault_names.LIBRARY.user_access == "DEVEAUSSAPLIBuserABC"
    error_message = "Library user KV: {env}{location}SAPLIBuser{random}"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Key Vault with Tier Environment Overrides
## Each tier's KV uses its respective env override
## ─────────────────────────────────────────────────────────────────────────────

run "keyvault_deployer_env_override" {
  command = plan

  variables {
    deployer_environment = "MGMT"
  }

  # deployer_env_verified = "MGMT"
  assert {
    condition     = output.naming.keyvault_names.DEPLOYER.private_access == "MGMTEAUSDEPVNETprvtABC"
    error_message = "Deployer KV uses deployer_environment override"
  }

  # Landscape KV still uses default env
  assert {
    condition     = output.naming.keyvault_names.WORKLOAD_ZONE.private_access == "DEVEAUSSAPVNETprvtABC"
    error_message = "Landscape KV unaffected by deployer_environment override"
  }
}

run "keyvault_landscape_env_override" {
  command = plan

  variables {
    landscape_environment = "QA"
  }

  assert {
    condition     = output.naming.keyvault_names.WORKLOAD_ZONE.private_access == "QAEAUSSAPVNETprvtABC"
    error_message = "Landscape KV uses landscape_environment override 'QA'"
  }
}

run "keyvault_library_env_override" {
  command = plan

  variables {
    library_environment = "SHARED"
  }

  # library_env_verified = "SHARE" (truncated to 5)
  assert {
    condition     = output.naming.keyvault_names.LIBRARY.private_access == "SHAREEAUSSAPLIBprvtABC"
    error_message = "Library KV uses truncated library_environment 'SHARE'"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Key Vault with deployer_location Override
## ─────────────────────────────────────────────────────────────────────────────

run "keyvault_deployer_location_override" {
  command = plan

  variables {
    deployer_location = "westeurope"
  }

  # deployer_location_short = "WEEU"
  assert {
    condition     = output.naming.keyvault_names.DEPLOYER.private_access == "DEVWEEUDEPVNETprvtABC"
    error_message = "Deployer KV uses overridden location (WEEU)"
  }

  assert {
    condition     = output.naming.keyvault_names.DEPLOYER.user_access == "DEVWEEUDEPVNETuserABC"
    error_message = "Deployer user KV uses overridden location (WEEU)"
  }

  # Other tiers unaffected
  assert {
    condition     = output.naming.keyvault_names.WORKLOAD_ZONE.private_access == "DEVEAUSSAPVNETprvtABC"
    error_message = "Landscape KV still uses main location (EAUS)"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Key Vault with Different Random ID
## Verifies random_id_verified = upper(substr(random_id, 0, 3))
## ─────────────────────────────────────────────────────────────────────────────

run "keyvault_random_id_is_uppercased_3_chars" {
  command = plan

  variables {
    random_id = "f9e8d7c6"
  }

  # random_id_verified = upper(substr("f9e8d7c6", 0, 3)) = "F9E"
  assert {
    condition     = output.naming.keyvault_names.SDU.private_access == "DEVEAUSSAPVNETHN1pF9E"
    error_message = "KV random_id should be upper 3 chars: F9E"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Key Vault with Special Characters in VNET
## Non-alphanumeric chars are stripped from vnet component
## ─────────────────────────────────────────────────────────────────────────────

run "keyvault_vnet_special_chars_stripped" {
  command = plan

  variables {
    sap_vnet_name        = "my-sap_vnet.01"
    management_vnet_name = "dep_mgmt-02"
  }

  # sap_vnet_verified = upper(trim(substr(replace("my-sap_vnet.01", ...), 0, 7), "-_")) = "MYSAPVN"
  # dep_vnet_verified = upper(trim(substr(replace("dep_mgmt-02", ...), 0, 7), "-_")) = "DEPMGMT"
  assert {
    condition     = output.naming.keyvault_names.WORKLOAD_ZONE.private_access == "DEVEAUSMYSAPVNprvtABC"
    error_message = "Landscape KV VNET should be sanitized: MYSAPVN"
  }

  assert {
    condition     = output.naming.keyvault_names.DEPLOYER.private_access == "DEVEAUSDEPMGMTprvtABC"
    error_message = "Deployer KV VNET should be sanitized: DEPMGMT"
  }
}
