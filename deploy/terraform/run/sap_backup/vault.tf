# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

#######################################4#######################################8
#                                                                              #
#                      Recovery Services Vault for SAP HANA                    #
#                                                                              #
#######################################4#######################################8

resource "azurerm_recovery_services_vault" "sap_backup" {
  provider                              = azurerm.main
  count                                 = 1

  name                                  = format("%s%s%s%s",
                                            var.naming.resource_prefixes.recovery_services_vault,
                                            local.prefix,
                                            var.naming.separator,
                                            local.resource_suffixes.recovery_services_vault
                                          )

  location                              = local.resource_group_exists ? (
                                            data.azurerm_resource_group.resource_group[0].location) : (
                                            azurerm_resource_group.resource_group[0].location
                                          )

  resource_group_name                  = local.resource_group_exists ? (
                                            data.azurerm_resource_group.resource_group[0].name) : (
                                            azurerm_resource_group.resource_group[0].name
                                          )

  sku                                   = "Standard"
  storage_mode_type                     = "GeoRedundant"
  cross_region_restore_enabled          = true
  soft_delete_enabled                   = true

  public_network_access_enabled         = var.public_network_access_enabled

  tags                                  = var.tags

  identity {
    type = "SystemAssigned"
  }
}
