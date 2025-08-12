# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.


#######################################4#######################################8
#                                                                              #
#                                Resource Group                                #
#                                                                              #
#######################################4#######################################8

data "azurerm_resource_group" "backup" {
  provider                = azurerm.main
  count                   = var.infrastructure.resource_group.use_existing ? 1 : 0
  name                    = local.resource_group_name
}

resource "azurerm_resource_group" "backup"        {
  provider                = azurerm.main
  count                   = var.infrastructure.resource_group.use_existing ? 0 : 1
  name                    = local.resource_group_name
  location                = local.location
  tags                    = local.tags
}


#######################################4#######################################8
#                                                                              #
#                                Back up Virtual Network                       #
#                                                                              #
#######################################4#######################################8

resource "azurerm_virtual_network" "vnet_backup" {
  provider                             = azurerm.main
  count                                = var.infrastructure.vnets.backup.exists  ? 0 : 1
  name                                 = local.BACKUP_virtual_network_name
  location                             = local.resource_group_exists ? (
                                           data.azurerm_resource_group.resource_group[0].location) : (
                                           azurerm_resource_group.resource_group[0].location
                                         )
  resource_group_name                  = local.resource_group_exists ? (
                                           data.azurerm_resource_group.resource_group[0].name) : (
                                           azurerm_resource_group.resource_group[0].name
                                         )
  address_space                        = var.infrastructure.vnets.backup.address_space
  flow_timeout_in_minutes              = var.infrastructure.vnets.backup.flow_timeout_in_minutes
  tags                                 = var.infrastructure.tags
  dns_servers                          = length(var.dns_settings.dns_server_list) > 0 ? var.dns_settings.dns_server_list : []
}

data "azurerm_virtual_network" "vnet_backup" {
  provider                             = azurerm.main
  count                                = var.infrastructure.vnets.backup.exists  ? 1 : 0
  name                                 = split("/", var.infrastructure.vnets.backup.backup.id)[8]
  resource_group_name                  = split("/", var.infrastructure.vnets.backup.backup.id)[4]
}

#######################################4#######################################8
#                                                                              #
#                                Back up Subnet                                #
#                                                                              #
#######################################4#######################################8

data "azurerm_subnet" "subnet_backup" {
  count               = local.use_existing_network && local.backup_network_resource_group != null ? 1 : 0
  name                = var.infrastructure.vnets.backup.subnet.name
  virtual_network_name = var.infrastructure.vnets.backup.name
  resource_group_name = local.backup_network_resource_group
}

resource "azurerm_subnet" "subnet_backup" {
  count                = local.use_existing_network ? 0 : 1
  name                 = "${local.backup_prefix}-${local.environment}-subnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.backup[0].name
  address_prefixes     = var.infrastructure.vnets.backup.subnet_backup.address_prefixes
}
