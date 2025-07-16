# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

#######################################4#######################################8
#                                                                              #
#                      Recovery Services Vault for SAP HANA                    #
#                                                                              #
#######################################4#######################################8

resource "azurerm_recovery_services_vault" "sap_backup" {
  provider                             = azurerm.main
  count                                = var.enable_backup_services_vault ? 1 : 0

  name                                 = format("%s%s%s%s",
                                            var.naming.resource_prefixes.recovery_services_vault,
                                            local.prefix,
                                            var.naming.separator,
                                            local.resource_suffixes.recovery_services_vault
                                          )

  location                             = local.resource_group_exists ? (
                                            data.azurerm_resource_group.resource_group[0].location) : (
                                            azurerm_resource_group.resource_group[0].location
                                          )

  resource_group_name                  = local.resource_group_exists ? (
                                            data.azurerm_resource_group.resource_group[0].name) : (
                                            azurerm_resource_group.resource_group[0].name
                                          )

  sku                                  = "Standard"
  storage_mode_type                    = "GeoRedundant"
  cross_region_restore_enabled         = true
  soft_delete_enabled                  = true

  public_network_access_enabled        = var.public_network_access_enabled

  tags                                 = var.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_backup_policy_vm" "sap_hana" {
  provider                             = azurerm.main
  count                                = var.enable_backup_services_vault ? 1 : 0

  name                                 = format("%s%s%s%s",
                                            var.naming.resource_prefixes.backup_policy,
                                            local.prefix,
                                            var.naming.separator,
                                            "hana"
                                          )

  resource_group_name                  = azurerm_recovery_services_vault.sap_backup[0].resource_group_name
  recovery_vault_name                  = azurerm_recovery_services_vault.sap_backup[0].name

  timezone                             = "UTC"

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 30
  }

  retention_weekly {
    count    = 12
    weekdays = ["Sunday"]
  }

  retention_monthly {
    count    = 12
    weekdays = ["Sunday"]
    weeks    = ["First"]
  }

  retention_yearly {
    count    = 2
    weekdays = ["Sunday"]
    weeks    = ["First"]
    months   = ["January"]
  }
}

resource "azurerm_private_endpoint" "backup_vault" {
  provider                             = azurerm.main
  count                                = (var.enable_backup_services_vault) && var.use_private_endpoint ? 1 : 0

  name                                 = format("%s%s%s%s",
                                            var.naming.resource_prefixes.recovery_vault_private_link,
                                            local.prefix,
                                            var.naming.separator,
                                            local.resource_suffixes.recovery_vault_private_link
                                          )

  resource_group_name                  = local.resource_group_exists ? (
                                            data.azurerm_resource_group.resource_group[0].name) : (
                                            azurerm_resource_group.resource_group[0].name
                                          )

  location                             = local.resource_group_exists ? (
                                            data.azurerm_resource_group.resource_group[0].location) : (
                                            azurerm_resource_group.resource_group[0].location
                                          )

  subnet_id                            = var.infrastructure.virtual_networks.sap.subnet_app.defined ? (
                                            var.infrastructure.virtual_networks.sap.subnet_app.exists ? (
                                              var.infrastructure.virtual_networks.sap.subnet_app.id) : (
                                              azurerm_subnet.app[0].id)) : (
                                            ""
                                          )

  private_service_connection {
    name                              = format("%s%s%s",
                                          var.naming.resource_prefixes.recovery_vault_private_svc,
                                          local.prefix,
                                          local.resource_suffixes.recovery_vault_private_svc
                                        )
    is_manual_connection              = false
    private_connection_resource_id    = azurerm_recovery_services_vault.sap_backup[0].id
    subresource_names                 = ["AzureBackup"]
  }

  dynamic "private_dns_zone_group" {
    for_each = range(var.dns_settings.register_endpoints_with_dns ? 1 : 0)
    content {
      name                            = var.dns_settings.dns_zone_names.backup_dns_zone_name
      private_dns_zone_ids            = local.privatelink_backup_defined ? [
        data.azurerm_private_dns_zone.backup[0].id
      ] : [
        azurerm_private_dns_zone.backup[0].id
      ]
    }
  }

  tags = var.tags
}
