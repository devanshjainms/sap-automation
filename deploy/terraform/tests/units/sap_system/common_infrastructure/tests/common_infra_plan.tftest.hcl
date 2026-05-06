## SAP System Common Infrastructure Plan-Level Tests
##
## Tests the common_infrastructure sub-module of sap_system, which is
## the foundation for all SAP workload deployments. This module creates:
## - Resource groups, PPGs, and scale sets
## - Database and admin subnets with NSGs and ASGs
## - Key Vault for SAP credentials (when local credentials used)
## - Storage accounts (boot diagnostics, sapmnt for AFS)
## - ANF volumes for sapmnt and usrsap
## - Anchor VMs for zonal pinning
## - Network security rules for SAP traffic
## - ARM template deployment marker
##
## All tests use mock providers with command = plan (no real Azure resources).

mock_provider "azurerm" {
  override_data {
    target = module.common_infra.data.azurerm_client_config.current
    values = {
      client_id       = "00000000-0000-0000-0000-000000000001"
      tenant_id       = "00000000-0000-0000-0000-000000000002"
      subscription_id = "00000000-0000-0000-0000-000000000003"
      object_id       = "00000000-0000-0000-0000-000000000004"
    }
  }

  override_data {
    target = module.common_infra.data.azurerm_subnet.db[0]
    values = {
      address_prefixes = ["10.1.1.0/24"]
      id               = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/db-subnet"
    }
  }

  override_data {
    target = module.common_infra.data.azurerm_subnet.admin[0]
    values = {
      address_prefixes = ["10.1.4.0/24"]
      id               = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/admin-subnet"
    }
  }

  override_data {
    target = module.common_infra.data.azurerm_subnet.storage[0]
    values = {
      address_prefixes = ["10.1.5.0/24"]
      id               = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/storage-subnet"
    }
  }
}

###############################################################################
# 1. Basic HANA system — single node, no HA, no zones                        #
###############################################################################
run "basic_hana_system" {
  command = plan

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP-HN1"
    error_message = "Resource group should use SDU naming: {prefix}{sdu_rg_suffix}"
  }

  assert {
    condition     = output.network_resource_group == "test-rg"
    error_message = "Network RG should be derived from landscape vnet ARM ID"
  }

  assert {
    condition     = output.route_table_id == ""
    error_message = "Route table ID should be empty when not provided"
  }

  assert {
    condition     = output.firewall_id == ""
    error_message = "Firewall ID should be empty when deployer_tfstate is null"
  }

  assert {
    condition     = output.use_local_credentials == true
    error_message = "Local credentials should be used when authentication block is provided"
  }

  assert {
    condition     = output.use_AFS_encryption_in_transit == false
    error_message = "AFS encryption in transit should be disabled by default"
  }
}

###############################################################################
# 2. Resource group naming convention                                        #
###############################################################################
run "resource_group_naming_convention" {
  command = plan

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP-HN1"
    error_message = "RG name: SDU prefix with empty sdu_rg suffix = just prefix"
  }
}

###############################################################################
# 3. PPG created for database when use_ppg=true                              #
###############################################################################
run "ppg_created_for_db" {
  command = plan

  assert {
    condition     = length(output.ppg) > 0
    error_message = "PPG should be created when database.use_ppg is true"
  }
}

###############################################################################
# 4. Application PPG with app_proximityplacementgroups enabled               #
###############################################################################
run "app_ppg_created" {
  command = plan

  variables {
    use_app_proximityplacementgroups = true
  }

  assert {
    condition     = length(output.app_ppg) > 0
    error_message = "App PPG should be created when use_app_proximityplacementgroups is true"
  }
}

###############################################################################
# 5. Application PPG disabled                                                #
###############################################################################
run "app_ppg_disabled" {
  command = plan

  variables {
    use_app_proximityplacementgroups = false
  }

  assert {
    condition     = length(output.app_ppg) == 0
    error_message = "App PPG should be empty when use_app_proximityplacementgroups is false"
  }
}

###############################################################################
# 6. ASG deployed for database                                               #
###############################################################################
run "asg_deployed_for_database" {
  command = plan

  variables {
    deploy_application_security_groups = true
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP-HN1"
    error_message = "Plan should succeed with ASGs enabled"
  }
}

###############################################################################
# 7. ASG disabled — no DB ASG                                                #
###############################################################################
run "asg_disabled_no_db_asg" {
  command = plan

  variables {
    deploy_application_security_groups = false
  }

  assert {
    condition     = output.db_asg_id == ""
    error_message = "DB ASG ID should be empty when ASGs are disabled"
  }
}

###############################################################################
# 8. Private endpoint mode                                                   #
###############################################################################
run "private_endpoint_mode" {
  command = plan

  variables {
    use_private_endpoint = true
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP-HN1"
    error_message = "Plan should succeed with private endpoints enabled"
  }
}

###############################################################################
# 9. Firewall for keyvaults and storage                                      #
###############################################################################
run "firewall_for_keyvaults_and_storage" {
  command = plan

  variables {
    enable_firewall_for_keyvaults_and_storage = true
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP-HN1"
    error_message = "Plan should succeed with KV/storage firewall enabled"
  }
}

###############################################################################
# 10. AFS for shared storage                                                 #
###############################################################################
run "afs_shared_storage" {
  command = plan

  variables {
    use_AFS_for_shared_storage = true
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP-HN1"
    error_message = "Plan should succeed with AFS shared storage"
  }
}

###############################################################################
# 11. AFS for sapmnt creates storage account                                 #
###############################################################################
run "afs_for_sapmnt" {
  command = plan

  variables {
    use_AFS_for_sapmnt = true
    NFS_provider       = "AFS"
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP-HN1"
    error_message = "Plan should succeed when using AFS for sapmnt"
  }
}

###############################################################################
# 12. Scale sets for deployment                                              #
###############################################################################
run "scalesets_deployment" {
  command = plan

  variables {
    use_scalesets_for_deployment = true
    db_use_ppg                   = false
  }

  assert {
    condition     = length(output.ppg) == 0
    error_message = "PPG should be empty when using scale sets"
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP-HN1"
    error_message = "Plan should succeed with scale sets enabled"
  }
}

###############################################################################
# 13. NSG/ASG co-located with VNet                                           #
###############################################################################
run "nsg_asg_with_vnet" {
  command = plan

  variables {
    nsg_asg_with_vnet                  = true
    deploy_application_security_groups = true
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP-HN1"
    error_message = "Plan should succeed with NSG/ASG in VNet RG"
  }
}

###############################################################################
# 14. Deployment disabled — standalone mode                                  #
###############################################################################
run "deployment_disabled_standalone" {
  command = plan

  variables {
    enable_deployment = false
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP-HN1"
    error_message = "Plan should succeed even when app deployment is disabled"
  }

  assert {
    condition     = output.scale_set_id == ""
    error_message = "Scale set should not be created when deployment is disabled"
  }
}

###############################################################################
# 15. Database HA enabled (NFS provider required)                            #
###############################################################################
run "database_ha_enabled" {
  command = plan

  variables {
    database_high_availability = true
    NFS_provider               = "AFS"
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP-HN1"
    error_message = "Plan should succeed with database HA"
  }
}

###############################################################################
# 16. SCS HA enabled                                                         #
###############################################################################
run "scs_ha_enabled" {
  command = plan

  variables {
    scs_high_availability = true
    NFS_provider          = "AFS"
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP-HN1"
    error_message = "Plan should succeed with SCS HA enabled"
  }
}

###############################################################################
# 17. Both DB and SCS HA enabled together                                    #
###############################################################################
run "full_ha_db_and_scs" {
  command = plan

  variables {
    database_high_availability = true
    scs_high_availability      = true
    NFS_provider               = "AFS"
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP-HN1"
    error_message = "Plan should succeed with full HA (DB + SCS)"
  }
}

###############################################################################
# 18. Private endpoints with firewall combined                               #
###############################################################################
run "private_endpoint_with_firewall" {
  command = plan

  variables {
    use_private_endpoint                      = true
    enable_firewall_for_keyvaults_and_storage = true
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP-HN1"
    error_message = "Plan should succeed with private endpoints and firewall"
  }
}

###############################################################################
# 19. PPG disabled when db_use_ppg is false but app ppg flags remain         #
###############################################################################
run "ppg_still_created_when_app_ppg_flags_set" {
  command = plan

  variables {
    db_use_ppg                       = false
    use_app_proximityplacementgroups = false
  }

  # When use_app_proximityplacementgroups=false, create_ppg considers
  # app_use_ppg || scs_use_ppg || web_use_ppg || db_use_ppg.
  # Since app_use_ppg and scs_use_ppg are true, PPG is still created.
  assert {
    condition     = length(output.ppg) > 0
    error_message = "PPG should still be created when app tier PPG flags are true"
  }

  assert {
    condition     = length(output.app_ppg) == 0
    error_message = "App PPG should be empty when use_app_proximityplacementgroups is false"
  }
}

###############################################################################
# 20. Full deployment — all features active simultaneously                   #
###############################################################################
run "full_deployment_all_features" {
  command = plan

  variables {
    database_high_availability                = true
    scs_high_availability                     = true
    use_private_endpoint                      = true
    enable_firewall_for_keyvaults_and_storage = true
    deploy_application_security_groups        = true
    use_AFS_for_shared_storage                = true
    NFS_provider                              = "AFS"
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP-HN1"
    error_message = "RG naming should be consistent with all features enabled"
  }

  assert {
    condition     = output.use_local_credentials == true
    error_message = "Local credentials should be used"
  }
}

###############################################################################
# 21. Brownfield — existing resource group via ARM ID                        #
###############################################################################
run "brownfield_existing_resource_group" {
  command = plan

  variables {
    brownfield_resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-sap-rg"
  }

  override_data {
    target = module.common_infra.data.azurerm_resource_group.resource_group[0]
    values = {
      name     = "existing-sap-rg"
      location = "eastus"
      id       = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-sap-rg"
    }
  }

  assert {
    condition     = output.resource_group_name == "existing-sap-rg"
    error_message = "Brownfield RG: name should come from existing data source, not generated"
  }

  assert {
    condition     = output.resource_group_id == "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-sap-rg"
    error_message = "Brownfield RG: ID should match the provided ARM ID"
  }
}

###############################################################################
# 22. Brownfield — existing Key Vault via ARM ID                             #
###############################################################################
run "brownfield_existing_key_vault" {
  command = plan

  variables {
    brownfield_keyvault_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-kv-rg/providers/Microsoft.KeyVault/vaults/existing-sap-kv"
  }

  override_data {
    target = module.common_infra.data.azurerm_key_vault.sid_keyvault_user[0]
    values = {
      name                = "existing-sap-kv"
      resource_group_name = "existing-kv-rg"
      id                  = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-kv-rg/providers/Microsoft.KeyVault/vaults/existing-sap-kv"
    }
  }

  assert {
    condition     = output.sid_keyvault_user_id == "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-kv-rg/providers/Microsoft.KeyVault/vaults/existing-sap-kv"
    error_message = "Brownfield KV: sid_keyvault_user_id should match the provided ARM ID"
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-SAP-HN1"
    error_message = "Brownfield KV: resource group should still be newly created (greenfield)"
  }
}

###############################################################################
# 23. Brownfield — both RG and KV pre-exist (common production pattern)      #
###############################################################################
run "brownfield_existing_rg_and_kv" {
  command = plan

  variables {
    brownfield_resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-sap-rg"
    brownfield_keyvault_id       = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-sap-rg/providers/Microsoft.KeyVault/vaults/existing-sap-kv"
  }

  override_data {
    target = module.common_infra.data.azurerm_resource_group.resource_group[0]
    values = {
      name     = "existing-sap-rg"
      location = "eastus"
      id       = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-sap-rg"
    }
  }

  override_data {
    target = module.common_infra.data.azurerm_key_vault.sid_keyvault_user[0]
    values = {
      name                = "existing-sap-kv"
      resource_group_name = "existing-sap-rg"
      id                  = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-sap-rg/providers/Microsoft.KeyVault/vaults/existing-sap-kv"
    }
  }

  assert {
    condition     = output.resource_group_name == "existing-sap-rg"
    error_message = "Brownfield RG+KV: RG name should come from existing data source"
  }

  assert {
    condition     = output.resource_group_id == "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-sap-rg"
    error_message = "Brownfield RG+KV: RG ID should match the provided ARM ID"
  }

  assert {
    condition     = output.sid_keyvault_user_id == "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-sap-rg/providers/Microsoft.KeyVault/vaults/existing-sap-kv"
    error_message = "Brownfield RG+KV: KV ID should match the provided ARM ID"
  }

  assert {
    condition     = output.use_local_credentials == true
    error_message = "Brownfield RG+KV: local credentials should still be used"
  }
}

###############################################################################
# Section 8: Negative Tests — Variable Validation Failures                    #
#                                                                             #
# Tests that invalid inputs are rejected by the module's validation blocks.   #
# Each test triggers exactly ONE validation failure via expect_failures.       #
###############################################################################

run "negative_sid_too_short_rejected" {
  command = plan
  variables {
    test_sid = "AB"
  }
  expect_failures = [var.test_sid]
}

run "negative_sid_too_long_rejected" {
  command = plan
  variables {
    test_sid = "ABCD"
  }
  expect_failures = [var.test_sid]
}

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

run "negative_empty_vnet_logical_name_rejected" {
  command = plan
  variables {
    test_vnet_logical_name = ""
  }
  expect_failures = [var.test_vnet_logical_name]
}

run "negative_empty_db_sizing_key_rejected" {
  command = plan
  variables {
    test_db_sizing_key = ""
  }
  expect_failures = [var.test_db_sizing_key]
}

run "negative_ha_without_nfs_provider_rejected" {
  command = plan
  variables {
    test_ha_validator = "10-NONE"
  }
  expect_failures = [var.test_ha_validator]
}

run "negative_missing_landscape_vnet_rejected" {
  command = plan
  variables {
    test_landscape_vnet_arm_id = ""
  }
  expect_failures = [var.test_landscape_vnet_arm_id]
}

###############################################################################
# Section 9: Deep Resource-Parameter Assertions                               #
#                                                                             #
# Validates computed credential settings, network routing, and firewall       #
# configuration that determine the security posture of the deployment.        #
###############################################################################

run "deep_default_credential_and_network_settings" {
  command = plan

  # Default: use local credentials (no key vault override)
  assert {
    condition     = output.use_local_credentials == true
    error_message = "Default deployment should use local credentials"
  }

  # Default: AFS encryption in transit disabled
  assert {
    condition     = output.use_AFS_encryption_in_transit == false
    error_message = "Default deployment should not enable AFS encryption in transit"
  }

  # Default: no firewall
  assert {
    condition     = output.firewall_id == ""
    error_message = "Default deployment should have empty firewall_id"
  }

  # Default: no route table
  assert {
    condition     = output.route_table_id == ""
    error_message = "Default deployment should have empty route_table_id"
  }

  # Network resource group comes from landscape_tfstate
  assert {
    condition     = output.network_resource_group == "test-rg"
    error_message = "Network RG should be extracted from landscape_tfstate vnet ARM ID (test-rg)"
  }
}
