# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

module "sap_backup" {
  source = "../../terraform-units/modules/sap_backup"

  providers = {
    azurerm.main                     = azurerm
    azurerm.deployer                 = azurerm.deployer
    azurerm.dnsmanagement            = azurerm.dnsmanagement
    azurerm.peering                  = azurerm.peering
    azurerm.privatelinkdnsmanagement = azurerm.privatelinkdnsmanagement
    azapi.api                        = azapi.api
  }

  infrastructure                      = local.infrastructure
  naming                              = length(var.name_override_file) > 0 ? (
                                          local.custom_names) : (
                                          module.sap_namegenerator.naming
                                        )
  backup_configuration                = local.backup_configuration
  backup_policy                       = local.backup_policy
  sap_systems                         = local.sap_systems
  target_workload_zones               = local.target_workload_zones
}
