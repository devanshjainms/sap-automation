# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.


#######################################4#######################################8
#                                                                              #
#                                Resource Group                                #
#                                                                              #
#######################################4#######################################8

resource "azurerm_resource_group" "resource_group" {
  provider                             = azurerm.main
  count                                = local.resource_group_exists ? 0 : 1
  name                                 = local.resourcegroup_name
  location                             = var.infrastructure.region
  tags                                 = merge(var.infrastructure.tags, var.tags)

}

data "azurerm_resource_group" "resource_group" {
  provider                             = azurerm.main
  count                                = length(try(var.infrastructure.resource_group.arm_id, "")) > 0 ? 1 : 0
  name                                 = split("/", var.infrastructure.resource_group.arm_id)[4]
}

#######################################4#######################################8
#                                                                              #
#                                Virtual Network                                #
#                                                                              #
#######################################4#######################################8


// Creates the Backup VNET
resource "azurerm_virtual_network" "vnet_backup" {
  provider                             = azurerm.main
  count                                = var.infrastructure.virtual_networks.backup.exists  ? 0 : 1
  name                                 = local.backup_virtual_network_name
  location                             = local.resource_group_exists ? (
                                            data.azurerm_resource_group.resource_group[0].location) : (
                                            azurerm_resource_group.resource_group[0].location
                                          )
  resource_group_name                  = local.resource_group_exists ? (
                                            data.azurerm_resource_group.resource_group[0].name) : (
                                            azurerm_resource_group.resource_group[0].name
                                          )
  address_space                        = var.infrastructure.virtual_networks.backup.address_space
  flow_timeout_in_minutes              = var.infrastructure.virtual_networks.backup.flow_timeout_in_minutes
  tags                                 = var.tags
  dns_servers                          = length(var.dns_settings.dns_server_list) > 0 ? var.dns_settings.dns_server_list : []
}

data "azurerm_virtual_network" "vnet_backup" {
  provider                             = azurerm.main
  name                                 = split("/", var.landscape_tfstate.vnet_backup_arm_id)[8]
  resource_group_name                  = split("/", var.landscape_tfstate.vnet_backup_arm_id)[4]
}

###################################################################################
#                                                                                #
#                                Subnet for Backup                              #
#                                                                              #
###################################################################################

resource "azurerm_subnet" "subnet_backup" {
  provider                             = azurerm.main
  count                                = var.infrastructure.virtual_networks.backup.subnet_backup.exists ? 0 : 1
  name                                 = local.backup_subnet_name
  resource_group_name                  = local.resource_group_exists ? (
                                            data.azurerm_resource_group.resource_group[0].name) : (
                                            azurerm_resource_group.resource_group[0].name
                                          )
  virtual_network_name                 = local.resource_group_exists ? (
                                            data.azurerm_virtual_network.vnet_backup[0].name) : (
                                            azurerm_virtual_network.vnet_backup[0].name
                                          )
  address_prefixes                     = var.infrastructure.virtual_networks.backup.subnet_backup.address_prefixes
  service_endpoints                    = var.infrastructure.virtual_networks.backup.subnet_backup.service_endpoints
  enforce_private_link_endpoint_network_policies = var.infrastructure.virtual_networks.backup.subnet_backup.enforce_private_link_endpoint_network_policies
}
