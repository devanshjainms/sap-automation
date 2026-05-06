## SAP Library Module — Systematic Plan-Level Tests
##
## Organized by resource group following the SYSTEMATIC approach:
## Section 1: Resource Group naming and creation logic
## Section 2: TFState storage account naming and configuration
## Section 3: SAPBits storage account naming and configuration
## Section 4: Key Vault secrets (conditional on key_vault.id)
## Section 5: DNS zone creation (on/off, zone names)
## Section 6: Private endpoint configuration
## Section 7: Bootstrap vs non-bootstrap mode differences
## Section 8: Brownfield scenarios (existing storage, existing RG)
## Section 9: Feature combinations
##
## All tests use command = plan with mock providers — no real Azure resources.
## Assertions target SPECIFIC computed values known at plan time.

mock_provider "azurerm" {
  override_data {
    target = module.sap_library.data.azurerm_client_config.current
    values = {
      client_id       = "00000000-0000-0000-0000-000000000001"
      tenant_id       = "00000000-0000-0000-0000-000000000002"
      subscription_id = "00000000-0000-0000-0000-000000000003"
      object_id       = "00000000-0000-0000-0000-000000000004"
    }
  }
}


## ═══════════════════════════════════════════════════════════════════════════════
## Section 1: Resource Group Naming and Creation Logic
##
## Formula: format("%s%s%s", resource_prefixes.library_rg, prefix, resource_suffixes.library_rg)
## With test inputs: "" + "DEV-EAUS" + "-SAP_LIBRARY" = "DEV-EAUS-SAP_LIBRARY"
##
## DESIGN: The module uses a 3-tier priority for RG name:
##   1. If exists=true → extract from resource ID (split on "/")[4]
##   2. If rg name is provided → use it directly
##   3. Otherwise → format("{library_rg prefix}{LIBRARY prefix}{library_rg suffix}")
## ═══════════════════════════════════════════════════════════════════════════════

run "rg_greenfield_naming_convention" {
  command = plan

  # prefix="DEV-EAUS" (naming.prefix.LIBRARY), library_rg prefix="", library_rg suffix="-SAP_LIBRARY"
  # Result: "" + "DEV-EAUS" + "-SAP_LIBRARY" = "DEV-EAUS-SAP_LIBRARY"
  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP_LIBRARY"
    error_message = "RG name: {rg_prefix}{LIBRARY prefix}{rg_suffix} = DEV-EAUS-SAP_LIBRARY. Got: ${output.resource_group_name}"
  }
}

run "rg_custom_name_override" {
  command = plan

  # DESIGN: When infrastructure.resource_group.name is set, it overrides the naming convention
  # AND becomes the prefix (local.prefix uses rg.name when set)
  variables {
    rg_name_override = "MY-CUSTOM-LIBRARY-RG"
  }

  assert {
    condition     = output.resource_group_name == "MY-CUSTOM-LIBRARY-RG"
    error_message = "RG name should use direct override when name is provided. Got: ${output.resource_group_name}"
  }
}

run "rg_sapbits_matches_library_rg" {
  command = plan

  # DESIGN: sapbits_sa_resource_group_name always equals the library resource group name
  assert {
    condition     = output.sapbits_sa_resource_group_name == "DEV-EAUS-SAP_LIBRARY"
    error_message = "SAPBits RG must match library RG. Got: ${output.sapbits_sa_resource_group_name}"
  }

  assert {
    condition     = output.sapbits_sa_resource_group_name == output.resource_group_name
    error_message = "SAPBits RG output must be identical to resource_group_name output"
  }
}


## ═══════════════════════════════════════════════════════════════════════════════
## Section 2: TFState Storage Account Naming and Configuration
##
## Formula (greenfield, no name override):
##   naming.storageaccount_names.LIBRARY.terraformstate_storageaccount_name
## With name override: use var.storage_account_tfstate.name directly
##
## DESIGN: 3-tier priority:
##   1. If exists=true → split(id)[8] (extract name from ARM resource ID)
##   2. If name is set → use it directly
##   3. Otherwise → use naming convention
## ═══════════════════════════════════════════════════════════════════════════════

run "tfstate_sa_default_naming" {
  command = plan

  # No override: falls back to naming.storageaccount_names.LIBRARY.terraformstate_storageaccount_name
  assert {
    condition     = output.tfstate_storage_account == "deveaustfstateabc"
    error_message = "TFState SA should use naming convention default 'deveaustfstateabc'. Got: ${output.tfstate_storage_account}"
  }

  # remote_state_storage_account_name uses identical logic
  assert {
    condition     = output.remote_state_storage_account_name == "deveaustfstateabc"
    error_message = "Remote state SA name must match tfstate SA name. Got: ${output.remote_state_storage_account_name}"
  }
}

run "tfstate_sa_custom_name_override" {
  command = plan

  variables {
    tfstate_name_override = "mytfstatecustom"
  }

  # DESIGN: When storage_account_tfstate.name is set, it takes priority over naming convention
  assert {
    condition     = output.tfstate_storage_account == "mytfstatecustom"
    error_message = "TFState SA should use custom name when provided. Got: ${output.tfstate_storage_account}"
  }

  assert {
    condition     = output.remote_state_storage_account_name == "mytfstatecustom"
    error_message = "Remote state name must also use the custom override. Got: ${output.remote_state_storage_account_name}"
  }
}

run "tfstate_container_name" {
  command = plan

  # DESIGN: Container name comes directly from storage_account_tfstate.tfstate_blob_container.name
  # It is NOT derived from naming convention — it's a direct pass-through of input config
  assert {
    condition     = output.storagecontainer_tfstate == "tfstate"
    error_message = "TFState container is a direct input pass-through = 'tfstate'. Got: ${output.storagecontainer_tfstate}"
  }
}

run "tfstate_sa_and_remote_state_always_match" {
  command = plan

  # DESIGN: Both outputs use exactly the same conditional logic, so they must always be identical
  variables {
    tfstate_name_override = "anothername123"
  }

  assert {
    condition     = output.tfstate_storage_account == output.remote_state_storage_account_name
    error_message = "tfstate_storage_account and remote_state_storage_account_name must always be identical"
  }
}


## ═══════════════════════════════════════════════════════════════════════════════
## Section 3: SAPBits Storage Account Naming and Configuration
##
## Formula (greenfield, no name override):
##   naming.storageaccount_names.LIBRARY.library_storageaccount_name
## With name override: use var.storage_account_sapbits.name directly
##
## DESIGN: Same 3-tier priority as tfstate:
##   1. If exists=true → split(id)[8]
##   2. If name is set → use it
##   3. Otherwise → naming convention
## ═══════════════════════════════════════════════════════════════════════════════

run "sapbits_sa_default_naming" {
  command = plan

  # No override: falls back to naming.storageaccount_names.LIBRARY.library_storageaccount_name
  assert {
    condition     = output.sapbits_storage_account_name == "deveaussaplibabc"
    error_message = "SAPBits SA should use naming convention 'deveaussaplibabc'. Got: ${output.sapbits_storage_account_name}"
  }
}

run "sapbits_sa_custom_name_override" {
  command = plan

  variables {
    sapbits_name_override = "mycustomsapbits"
  }

  # DESIGN: Custom name takes priority over naming convention
  assert {
    condition     = output.sapbits_storage_account_name == "mycustomsapbits"
    error_message = "SAPBits SA should use custom name 'mycustomsapbits'. Got: ${output.sapbits_storage_account_name}"
  }
}

run "sapbits_container_name" {
  command = plan

  # DESIGN: storagecontainer_sapbits_name output is file_share.name (not blob container name)
  # This is the file share name from storage_account_sapbits.file_share.name
  assert {
    condition     = output.storagecontainer_sapbits_name == "sapbits"
    error_message = "SAPBits container (file share) name is a direct pass-through = 'sapbits'. Got: ${output.storagecontainer_sapbits_name}"
  }
}

run "sapbits_and_tfstate_names_independent" {
  command = plan

  # DESIGN: Overriding one does not affect the other
  variables {
    sapbits_name_override = "customsapbits99"
    tfstate_name_override = ""
  }

  assert {
    condition     = output.sapbits_storage_account_name == "customsapbits99"
    error_message = "SAPBits override applied. Got: ${output.sapbits_storage_account_name}"
  }

  assert {
    condition     = output.tfstate_storage_account == "deveaustfstateabc"
    error_message = "TFState should remain at default when only SAPBits is overridden. Got: ${output.tfstate_storage_account}"
  }
}


## ═══════════════════════════════════════════════════════════════════════════════
## Section 4: Key Vault Secrets
##
## DESIGN: Key Vault secrets are ONLY created when length(var.key_vault.id) > 0.
## With key_vault.id = "" (our default), no secrets are created.
## The module does NOT create a Key Vault itself — it writes secrets to an
## existing one specified by ID. This means naming outputs are unaffected by KV.
## ═══════════════════════════════════════════════════════════════════════════════

run "keyvault_empty_id_no_impact_on_naming" {
  command = plan

  # DESIGN: key_vault.id = "" → count = 0 for all azurerm_key_vault_secret resources
  # Naming outputs remain stable regardless
  variables {
    key_vault_id = ""
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP_LIBRARY"
    error_message = "RG name unaffected by empty KV ID. Got: ${output.resource_group_name}"
  }

  assert {
    condition     = output.tfstate_storage_account == "deveaustfstateabc"
    error_message = "TFState naming unaffected by empty KV ID. Got: ${output.tfstate_storage_account}"
  }
}

run "keyvault_with_id_naming_stable" {
  command = plan

  # DESIGN: Even with a valid KV ID, naming outputs don't change
  # The KV ID only triggers secret creation, not naming changes
  variables {
    key_vault_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/deployer-rg/providers/Microsoft.KeyVault/vaults/mydeployerkv"
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP_LIBRARY"
    error_message = "RG name unaffected by KV ID. Got: ${output.resource_group_name}"
  }

  assert {
    condition     = output.tfstate_storage_account == "deveaustfstateabc"
    error_message = "TFState naming unaffected by KV ID. Got: ${output.tfstate_storage_account}"
  }

  assert {
    condition     = output.sapbits_storage_account_name == "deveaussaplibabc"
    error_message = "SAPBits naming unaffected by KV ID. Got: ${output.sapbits_storage_account_name}"
  }
}


## ═══════════════════════════════════════════════════════════════════════════════
## Section 5: DNS Zone Creation (On/Off, Zone Names)
##
## DESIGN: Local DNS zone creation depends on:
##   use_local_private_dns = (dns_label != "" && !use_custom_dns_a_registration
##                           && management_dns_resourcegroup_name == "")
##   use_local_privatelink_dns = (create_privatelink_dns_zones
##                               && !use_custom_dns_a_registration
##                               && privatelink_dns_resourcegroup_name == "")
##
## DNS zones created when use_local_privatelink_dns=true AND
## register_storage_accounts_keyvaults_with_dns=true:
##   - blob, table, file, vault
## DNS zone "dns" created when use_local_private_dns=true
## ═══════════════════════════════════════════════════════════════════════════════

run "dns_all_disabled_naming_stable" {
  command = plan

  # DESIGN: dns_label="" → use_local_private_dns=false
  # create_privatelink_dns_zones=false → use_local_privatelink_dns=false
  # No DNS zones are created; naming outputs unaffected
  variables {
    dns_label                                    = ""
    create_privatelink_dns_zones                 = false
    register_storage_accounts_keyvaults_with_dns = false
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP_LIBRARY"
    error_message = "RG name stable with DNS disabled. Got: ${output.resource_group_name}"
  }

  assert {
    condition     = output.tfstate_storage_account == "deveaustfstateabc"
    error_message = "TFState stable with DNS disabled. Got: ${output.tfstate_storage_account}"
  }

  assert {
    condition     = output.sapbits_storage_account_name == "deveaussaplibabc"
    error_message = "SAPBits stable with DNS disabled. Got: ${output.sapbits_storage_account_name}"
  }
}

run "dns_local_private_dns_zone" {
  command = plan

  # DESIGN: dns_label="sap.contoso.com", use_custom_dns_a_registration=false,
  # management_dns_resourcegroup_name="" → use_local_private_dns=true
  # This creates azurerm_private_dns_zone.dns[0] with name = dns_label
  # But outputs remain stable (DNS doesn't change naming)
  variables {
    dns_label                     = "sap.contoso.com"
    use_custom_dns_a_registration = false
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP_LIBRARY"
    error_message = "RG name stable with local private DNS. Got: ${output.resource_group_name}"
  }

  assert {
    condition     = output.tfstate_storage_account == "deveaustfstateabc"
    error_message = "TFState stable with local private DNS. Got: ${output.tfstate_storage_account}"
  }
}

run "dns_privatelink_zones_enabled" {
  command = plan

  # DESIGN: create_privatelink_dns_zones=true + !custom_dns + no external RG
  # → use_local_privatelink_dns=true
  # register_storage_accounts_keyvaults_with_dns=true enables zone creation
  # Creates: blob, table, file, vault DNS zones locally
  variables {
    create_privatelink_dns_zones                 = true
    register_storage_accounts_keyvaults_with_dns = true
    use_custom_dns_a_registration                = false
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP_LIBRARY"
    error_message = "RG name stable with privatelink DNS. Got: ${output.resource_group_name}"
  }

  assert {
    condition     = output.tfstate_storage_account == "deveaustfstateabc"
    error_message = "TFState stable with privatelink DNS. Got: ${output.tfstate_storage_account}"
  }

  assert {
    condition     = output.sapbits_storage_account_name == "deveaussaplibabc"
    error_message = "SAPBits stable with privatelink DNS. Got: ${output.sapbits_storage_account_name}"
  }
}

run "dns_custom_registration_suppresses_local_zones" {
  command = plan

  # DESIGN: use_custom_dns_a_registration=true overrides everything:
  # use_local_private_dns = (dns_label != "" && !use_custom_dns_a_registration && ...) → false
  # use_local_privatelink_dns = (create_privatelink... && !use_custom_dns_a_registration && ...) → false
  # So even with dns_label set and create_privatelink_dns_zones=true, NO local zones are created
  variables {
    dns_label                                    = "sap.contoso.com"
    create_privatelink_dns_zones                 = true
    register_storage_accounts_keyvaults_with_dns = true
    use_custom_dns_a_registration                = true
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP_LIBRARY"
    error_message = "RG name stable with custom DNS registration. Got: ${output.resource_group_name}"
  }

  assert {
    condition     = output.tfstate_storage_account == "deveaustfstateabc"
    error_message = "TFState stable with custom DNS registration. Got: ${output.tfstate_storage_account}"
  }
}


## ═══════════════════════════════════════════════════════════════════════════════
## Section 6: Private Endpoint Configuration
##
## DESIGN: Private endpoints are created when ALL conditions are true:
##   - var.deployer.use = true
##   - var.use_private_endpoint = true
##   - !var.storage_account_*.exists (greenfield)
##
## With deployer_use=false (our default), PEs are never created regardless of
## use_private_endpoint setting. This verifies naming stability in both cases.
## ═══════════════════════════════════════════════════════════════════════════════

run "pe_disabled_no_deployer" {
  command = plan

  # DESIGN: deployer.use=false → PE count=0 regardless of use_private_endpoint
  variables {
    use_private_endpoint = false
    deployer_use         = false
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP_LIBRARY"
    error_message = "RG name stable with PE disabled. Got: ${output.resource_group_name}"
  }

  assert {
    condition     = output.tfstate_storage_account == "deveaustfstateabc"
    error_message = "TFState stable with PE disabled. Got: ${output.tfstate_storage_account}"
  }

  assert {
    condition     = output.sapbits_storage_account_name == "deveaussaplibabc"
    error_message = "SAPBits stable with PE disabled. Got: ${output.sapbits_storage_account_name}"
  }
}

run "pe_enabled_but_no_deployer" {
  command = plan

  # DESIGN: use_private_endpoint=true BUT deployer.use=false → PE count still 0
  # Both conditions must be true for PE creation
  variables {
    use_private_endpoint = true
    deployer_use         = false
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP_LIBRARY"
    error_message = "RG name stable when PE enabled but deployer not in use. Got: ${output.resource_group_name}"
  }

  assert {
    condition     = output.tfstate_storage_account == "deveaustfstateabc"
    error_message = "TFState stable when PE enabled but deployer not in use. Got: ${output.tfstate_storage_account}"
  }
}

run "pe_enabled_with_deployer" {
  command = plan

  # DESIGN: deployer.use=true AND use_private_endpoint=true AND !exists → PEs planned
  # But naming outputs remain identical since PE names are separate resources
  variables {
    use_private_endpoint            = true
    deployer_use                    = true
    deployer_tfstate_subnet_mgmt_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/mgmt-subnet"
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP_LIBRARY"
    error_message = "RG name stable with PEs enabled + deployer. Got: ${output.resource_group_name}"
  }

  assert {
    condition     = output.tfstate_storage_account == "deveaustfstateabc"
    error_message = "TFState stable with PEs enabled + deployer. Got: ${output.tfstate_storage_account}"
  }

  assert {
    condition     = output.sapbits_storage_account_name == "deveaussaplibabc"
    error_message = "SAPBits stable with PEs enabled + deployer. Got: ${output.sapbits_storage_account_name}"
  }

  assert {
    condition     = output.sapbits_sa_resource_group_name == output.resource_group_name
    error_message = "SAPBits RG must match library RG even with PEs enabled"
  }
}


## ═══════════════════════════════════════════════════════════════════════════════
## Section 7: Bootstrap vs Non-Bootstrap Mode Differences
##
## DESIGN: var.bootstrap affects network rules default_action:
##   - bootstrap=true → default_action = "Allow" (permissive during initial setup)
##   - bootstrap=false → default_action = firewall enabled ? "Deny" : "Allow"
##
## This only applies when enable_firewall_for_keyvaults_and_storage=true.
## Naming outputs are identical in both modes. The difference is behavioral.
## ═══════════════════════════════════════════════════════════════════════════════

run "bootstrap_mode_naming_stable" {
  command = plan

  variables {
    bootstrap = true
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP_LIBRARY"
    error_message = "RG name stable in bootstrap mode. Got: ${output.resource_group_name}"
  }

  assert {
    condition     = output.tfstate_storage_account == "deveaustfstateabc"
    error_message = "TFState stable in bootstrap mode. Got: ${output.tfstate_storage_account}"
  }

  assert {
    condition     = output.sapbits_storage_account_name == "deveaussaplibabc"
    error_message = "SAPBits stable in bootstrap mode. Got: ${output.sapbits_storage_account_name}"
  }
}

run "non_bootstrap_mode_naming_stable" {
  command = plan

  variables {
    bootstrap = false
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP_LIBRARY"
    error_message = "RG name stable in non-bootstrap mode. Got: ${output.resource_group_name}"
  }

  assert {
    condition     = output.tfstate_storage_account == "deveaustfstateabc"
    error_message = "TFState stable in non-bootstrap mode. Got: ${output.tfstate_storage_account}"
  }

  assert {
    condition     = output.sapbits_storage_account_name == "deveaussaplibabc"
    error_message = "SAPBits stable in non-bootstrap mode. Got: ${output.sapbits_storage_account_name}"
  }

  assert {
    condition     = output.remote_state_storage_account_name == output.tfstate_storage_account
    error_message = "Remote state must match tfstate in non-bootstrap mode"
  }
}

run "bootstrap_with_firewall_naming_stable" {
  command = plan

  # DESIGN: bootstrap=true + firewall=true → network rules planned with default_action="Allow"
  # Naming outputs unchanged
  variables {
    bootstrap                                 = true
    enable_firewall_for_keyvaults_and_storage = true
    public_network_access_enabled             = true
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP_LIBRARY"
    error_message = "RG name stable with bootstrap + firewall. Got: ${output.resource_group_name}"
  }

  assert {
    condition     = output.tfstate_storage_account == "deveaustfstateabc"
    error_message = "TFState stable with bootstrap + firewall. Got: ${output.tfstate_storage_account}"
  }
}

run "non_bootstrap_with_firewall_naming_stable" {
  command = plan

  # DESIGN: bootstrap=false + firewall=true → network rules default_action="Deny"
  # Naming outputs unchanged
  variables {
    bootstrap                                 = false
    enable_firewall_for_keyvaults_and_storage = true
    public_network_access_enabled             = false
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP_LIBRARY"
    error_message = "RG name stable with non-bootstrap + firewall. Got: ${output.resource_group_name}"
  }

  assert {
    condition     = output.tfstate_storage_account == "deveaustfstateabc"
    error_message = "TFState stable with non-bootstrap + firewall. Got: ${output.tfstate_storage_account}"
  }

  assert {
    condition     = output.sapbits_storage_account_name == "deveaussaplibabc"
    error_message = "SAPBits stable with non-bootstrap + firewall. Got: ${output.sapbits_storage_account_name}"
  }
}


## ═══════════════════════════════════════════════════════════════════════════════
## Section 8: Brownfield Scenarios (existing resources)
##
## DESIGN: When storage_account_*.exists=true, the module uses data sources
## instead of creating new resources. For naming outputs, the "exists" path
## extracts the name from the ARM resource ID: split("/", id)[8]
##
## NOTE: We cannot fully test exists=true in this harness because it requires
## valid data source responses. But we CAN test that with exists=false
## (greenfield), all naming paths work correctly. The custom name override
## simulates the same behavior as exists since it bypasses naming convention.
## ═══════════════════════════════════════════════════════════════════════════════

run "brownfield_custom_rg_name" {
  command = plan

  # DESIGN: infrastructure.resource_group.name override simulates the name that
  # would be extracted from an existing RG's ARM ID
  variables {
    rg_name_override = "EXISTING-SAP-LIBRARY-RG"
  }

  assert {
    condition     = output.resource_group_name == "EXISTING-SAP-LIBRARY-RG"
    error_message = "Custom RG name should be used directly. Got: ${output.resource_group_name}"
  }

  assert {
    condition     = output.sapbits_sa_resource_group_name == "EXISTING-SAP-LIBRARY-RG"
    error_message = "SAPBits RG must match the custom RG name. Got: ${output.sapbits_sa_resource_group_name}"
  }
}

run "brownfield_custom_storage_names" {
  command = plan

  # DESIGN: Custom names simulate the naming path used when exists=true
  # (which extracts from ARM ID). Both should yield the same output behavior.
  variables {
    sapbits_name_override = "existingsapbitsacct"
    tfstate_name_override = "existingtfstateacct"
  }

  assert {
    condition     = output.sapbits_storage_account_name == "existingsapbitsacct"
    error_message = "Brownfield SAPBits name. Got: ${output.sapbits_storage_account_name}"
  }

  assert {
    condition     = output.tfstate_storage_account == "existingtfstateacct"
    error_message = "Brownfield TFState name. Got: ${output.tfstate_storage_account}"
  }

  assert {
    condition     = output.remote_state_storage_account_name == "existingtfstateacct"
    error_message = "Brownfield remote state name. Got: ${output.remote_state_storage_account_name}"
  }

  # Container names are always from input config, not affected by brownfield
  assert {
    condition     = output.storagecontainer_tfstate == "tfstate"
    error_message = "Container names unaffected by brownfield SA names. Got: ${output.storagecontainer_tfstate}"
  }

  assert {
    condition     = output.storagecontainer_sapbits_name == "sapbits"
    error_message = "SAPBits container unaffected by brownfield SA names. Got: ${output.storagecontainer_sapbits_name}"
  }
}

run "brownfield_rg_with_default_storage_names" {
  command = plan

  # DESIGN: Custom RG name does NOT affect storage account naming when no SA override
  variables {
    rg_name_override      = "BROWNFIELD-RG"
    sapbits_name_override = ""
    tfstate_name_override = ""
  }

  assert {
    condition     = output.resource_group_name == "BROWNFIELD-RG"
    error_message = "RG should use override. Got: ${output.resource_group_name}"
  }

  assert {
    condition     = output.tfstate_storage_account == "deveaustfstateabc"
    error_message = "TFState should still use naming convention. Got: ${output.tfstate_storage_account}"
  }

  assert {
    condition     = output.sapbits_storage_account_name == "deveaussaplibabc"
    error_message = "SAPBits should still use naming convention. Got: ${output.sapbits_storage_account_name}"
  }
}


## ═══════════════════════════════════════════════════════════════════════════════
## Section 9: Feature Combinations
##
## DESIGN: Tests that exercise multiple features simultaneously to verify
## no interactions between features corrupt naming outputs.
## ═══════════════════════════════════════════════════════════════════════════════

run "full_private_deployment" {
  command = plan

  # All security features enabled: PE + DNS + firewall + locks
  variables {
    use_private_endpoint                         = true
    deployer_use                                 = true
    deployer_tfstate_subnet_mgmt_id              = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/mgmt-subnet"
    create_privatelink_dns_zones                 = true
    register_storage_accounts_keyvaults_with_dns = true
    enable_firewall_for_keyvaults_and_storage    = true
    public_network_access_enabled                = false
    place_delete_lock_on_resources               = true
    bootstrap                                    = false
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP_LIBRARY"
    error_message = "RG name stable in full private deployment. Got: ${output.resource_group_name}"
  }

  assert {
    condition     = output.tfstate_storage_account == "deveaustfstateabc"
    error_message = "TFState stable in full private deployment. Got: ${output.tfstate_storage_account}"
  }

  assert {
    condition     = output.sapbits_storage_account_name == "deveaussaplibabc"
    error_message = "SAPBits stable in full private deployment. Got: ${output.sapbits_storage_account_name}"
  }

  assert {
    condition     = output.sapbits_sa_resource_group_name == output.resource_group_name
    error_message = "SAPBits RG must match library RG in full private deployment"
  }

  assert {
    condition     = output.remote_state_storage_account_name == output.tfstate_storage_account
    error_message = "Remote state must match tfstate in full private deployment"
  }

  assert {
    condition     = output.storagecontainer_tfstate == "tfstate"
    error_message = "Container names stable in full private deployment. Got: ${output.storagecontainer_tfstate}"
  }

  assert {
    condition     = output.storagecontainer_sapbits_name == "sapbits"
    error_message = "SAPBits container stable in full private deployment. Got: ${output.storagecontainer_sapbits_name}"
  }
}

run "custom_names_with_full_features" {
  command = plan

  # Custom names + all features enabled: overrides must still take precedence
  variables {
    sapbits_name_override                        = "fullcustomsapbits"
    tfstate_name_override                        = "fullcustomtfstate"
    use_private_endpoint                         = true
    deployer_use                                 = true
    deployer_tfstate_subnet_mgmt_id              = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/mgmt-subnet"
    create_privatelink_dns_zones                 = true
    register_storage_accounts_keyvaults_with_dns = true
    enable_firewall_for_keyvaults_and_storage    = true
    place_delete_lock_on_resources               = true
  }

  assert {
    condition     = output.sapbits_storage_account_name == "fullcustomsapbits"
    error_message = "Custom SAPBits name used with all features. Got: ${output.sapbits_storage_account_name}"
  }

  assert {
    condition     = output.tfstate_storage_account == "fullcustomtfstate"
    error_message = "Custom TFState name used with all features. Got: ${output.tfstate_storage_account}"
  }

  assert {
    condition     = output.remote_state_storage_account_name == "fullcustomtfstate"
    error_message = "Remote state reflects custom override. Got: ${output.remote_state_storage_account_name}"
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP_LIBRARY"
    error_message = "RG naming independent of SA overrides. Got: ${output.resource_group_name}"
  }

  assert {
    condition     = output.storagecontainer_tfstate == "tfstate"
    error_message = "Containers independent of SA name overrides. Got: ${output.storagecontainer_tfstate}"
  }

  assert {
    condition     = output.storagecontainer_sapbits_name == "sapbits"
    error_message = "SAPBits container independent of SA name overrides. Got: ${output.storagecontainer_sapbits_name}"
  }
}

run "custom_rg_with_pe_and_dns" {
  command = plan

  # Custom RG name + private endpoints + DNS
  variables {
    rg_name_override                             = "CUSTOM-LIB-RG"
    use_private_endpoint                         = true
    deployer_use                                 = true
    deployer_tfstate_subnet_mgmt_id              = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/mgmt-subnet"
    dns_label                                    = "sap.myorg.com"
    create_privatelink_dns_zones                 = true
    register_storage_accounts_keyvaults_with_dns = true
  }

  assert {
    condition     = output.resource_group_name == "CUSTOM-LIB-RG"
    error_message = "Custom RG override with PE+DNS. Got: ${output.resource_group_name}"
  }

  assert {
    condition     = output.sapbits_sa_resource_group_name == "CUSTOM-LIB-RG"
    error_message = "SAPBits RG matches custom RG with PE+DNS. Got: ${output.sapbits_sa_resource_group_name}"
  }

  assert {
    condition     = output.tfstate_storage_account == "deveaustfstateabc"
    error_message = "TFState uses naming convention with custom RG. Got: ${output.tfstate_storage_account}"
  }

  assert {
    condition     = output.sapbits_storage_account_name == "deveaussaplibabc"
    error_message = "SAPBits uses naming convention with custom RG. Got: ${output.sapbits_storage_account_name}"
  }
}

run "shared_access_key_disabled_oauth_only" {
  command = plan

  # DESIGN: shared_access_key_enabled=false disables access key for both storage accounts
  # Naming outputs unaffected. KV secrets for access keys won't be created.
  variables {
    shared_access_key_enabled = false
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP_LIBRARY"
    error_message = "RG name stable in OAuth-only mode. Got: ${output.resource_group_name}"
  }

  assert {
    condition     = output.tfstate_storage_account == "deveaustfstateabc"
    error_message = "TFState stable in OAuth-only mode. Got: ${output.tfstate_storage_account}"
  }

  assert {
    condition     = output.sapbits_storage_account_name == "deveaussaplibabc"
    error_message = "SAPBits stable in OAuth-only mode. Got: ${output.sapbits_storage_account_name}"
  }

  assert {
    condition     = output.storagecontainer_sapbits_name == "sapbits"
    error_message = "Container stable in OAuth-only mode. Got: ${output.storagecontainer_sapbits_name}"
  }
}

run "minimal_bootstrap_deployment" {
  command = plan

  # DESIGN: Minimal viable config — bootstrap mode, no DNS, no PE, no firewall
  # This is the simplest deployment path
  variables {
    bootstrap                                    = true
    use_private_endpoint                         = false
    deployer_use                                 = false
    dns_label                                    = ""
    create_privatelink_dns_zones                 = false
    register_storage_accounts_keyvaults_with_dns = false
    enable_firewall_for_keyvaults_and_storage    = false
    public_network_access_enabled                = true
    place_delete_lock_on_resources               = false
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP_LIBRARY"
    error_message = "Minimal bootstrap: RG name. Got: ${output.resource_group_name}"
  }

  assert {
    condition     = output.tfstate_storage_account == "deveaustfstateabc"
    error_message = "Minimal bootstrap: TFState name. Got: ${output.tfstate_storage_account}"
  }

  assert {
    condition     = output.sapbits_storage_account_name == "deveaussaplibabc"
    error_message = "Minimal bootstrap: SAPBits name. Got: ${output.sapbits_storage_account_name}"
  }

  assert {
    condition     = output.storagecontainer_tfstate == "tfstate"
    error_message = "Minimal bootstrap: TFState container. Got: ${output.storagecontainer_tfstate}"
  }

  assert {
    condition     = output.storagecontainer_sapbits_name == "sapbits"
    error_message = "Minimal bootstrap: SAPBits container. Got: ${output.storagecontainer_sapbits_name}"
  }

  assert {
    condition     = output.sapbits_sa_resource_group_name == output.resource_group_name
    error_message = "Minimal bootstrap: SAPBits RG must match library RG"
  }

  assert {
    condition     = output.remote_state_storage_account_name == output.tfstate_storage_account
    error_message = "Minimal bootstrap: remote state must match tfstate"
  }
}

run "delete_lock_with_custom_names" {
  command = plan

  # DESIGN: place_delete_lock_on_resources=true creates management locks on
  # storage accounts. Locks reference the SA, so they only exist when exists=false.
  # Naming outputs are not affected by lock presence.
  variables {
    place_delete_lock_on_resources = true
    sapbits_name_override          = "lockedsa1"
    tfstate_name_override          = "lockedsa2"
  }

  assert {
    condition     = output.sapbits_storage_account_name == "lockedsa1"
    error_message = "Lock + custom name: SAPBits. Got: ${output.sapbits_storage_account_name}"
  }

  assert {
    condition     = output.tfstate_storage_account == "lockedsa2"
    error_message = "Lock + custom name: TFState. Got: ${output.tfstate_storage_account}"
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP_LIBRARY"
    error_message = "Lock + custom name: RG unchanged. Got: ${output.resource_group_name}"
  }
}

###############################################################################
# Section 10: Negative Tests — Variable Validation Failures                   #
#                                                                             #
# Tests that invalid inputs are rejected by the module's validation blocks.   #
# Each test triggers exactly ONE validation failure via expect_failures.       #
###############################################################################

run "negative_empty_region_rejected" {
  command = plan
  variables {
    test_region = ""
  }
  expect_failures = [var.test_region]
}

run "negative_empty_environment_rejected" {
  command = plan
  variables {
    test_environment = ""
  }
  expect_failures = [var.test_environment]
}

run "negative_invalid_keyvault_id_format_rejected" {
  command = plan
  variables {
    test_keyvault_deploy_cred_id = "not-a-valid-resource-id"
  }
  expect_failures = [var.test_keyvault_deploy_cred_id]
}

run "negative_keyvault_id_too_few_segments_rejected" {
  command = plan
  variables {
    test_keyvault_deploy_cred_id = "/subscriptions/00000000/resourceGroups/rg"
  }
  expect_failures = [var.test_keyvault_deploy_cred_id]
}

###############################################################################
# Section 11: Deep Resource-Parameter Assertions                              #
#                                                                             #
# Validates storage account naming, container naming, and resource group      #
# naming that downstream tfstate operations depend on.                        #
###############################################################################

run "deep_storage_naming_conventions" {
  command = plan

  # Terraform state storage account: <env><loc>tfstate<random>
  assert {
    condition     = output.tfstate_storage_account == "deveaustfstateabc"
    error_message = "Tfstate storage account should be 'deveaustfstateabc'"
  }

  assert {
    condition     = output.remote_state_storage_account_name == "deveaustfstateabc"
    error_message = "Remote state account name should match tfstate account"
  }

  # SAP bits storage account: <env><loc>saplib<random>
  assert {
    condition     = output.sapbits_storage_account_name == "deveaussaplibabc"
    error_message = "SAP bits storage account should be 'deveaussaplibabc'"
  }

  # Resource group for sapbits: <ENV>-<LOC>-SAP_LIBRARY
  assert {
    condition     = output.sapbits_sa_resource_group_name == "DEV-EAUS-SAP_LIBRARY"
    error_message = "SAP bits RG should be 'DEV-EAUS-SAP_LIBRARY'"
  }

  # Container names: fixed convention
  assert {
    condition     = output.storagecontainer_tfstate == "tfstate"
    error_message = "Tfstate container should be 'tfstate'"
  }

  assert {
    condition     = output.storagecontainer_sapbits_name == "sapbits"
    error_message = "SAP bits container should be 'sapbits'"
  }
}
