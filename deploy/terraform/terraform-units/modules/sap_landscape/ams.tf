# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

// Imports data of existing AMS subnet
data "azurerm_subnet" "ams" {
  provider                             = azurerm.main
  count                                = length(local.ams_subnet_arm_id) > 0 ? 1 : 0
  name                                 = split("/", local.ams_subnet_arm_id)[10]   # Get the Subnet from actual arm_id
  virtual_network_name                 = split("/", local.ams_subnet_arm_id)[8]    # Get the Network from actual arm_id
  resource_group_name                  = split("/", local.ams_subnet_arm_id)[4]    # Get RG name from actual arm_id
}

resource "azurerm_subnet_route_table_association" "ams" {
  provider                             = azurerm.main
  count                                = local.create_ams_instance && local.ams_subnet_defined && !local.SAP_virtualnetwork_exists && !local.ams_subnet_existing ?  (local.create_nat_gateway ? 0 : 1)  : 0
  depends_on                           = [
                                           azurerm_route_table.rt,
                                           azurerm_subnet.ams
                                         ]
  subnet_id                            = local.ams_subnet_existing ? var.infrastructure.virtual_networks.sap.subnet_ams.arm_id : azurerm_subnet.ams[0].id
  route_table_id                       = azurerm_route_table.rt[0].id
}


# Created AMS instance if log analytics workspace is NOT defined
resource "azapi_resource" "ams_instance" {
  type                                  = "Microsoft.Workloads/monitors@2023-04-01"
  count                                 = local.create_ams_instance && local.ams_subnet_defined ? 1 : 0
  name                                  = local.ams_instance_name
  location                              = local.region
  parent_id                             = azurerm_resource_group.resource_group[0].id
  depends_on                            = [
                                            azurerm_virtual_network.vnet_sap,
                                            azurerm_subnet.ams
                                          ]
  body                                  = {
                                            properties = {
                                                            appLocation: local.region,
                                                            routingPreference: "RouteAll",
                                                            logAnalyticsWorkspaceArmId: length(local.ams_laws_arm_id) > 0 ? local.ams_laws_arm_id : null,
                                                            managedResourceGroupConfiguration: {
                                                              name: "managedrg-ams"
                                                            },
                                                           monitorSubnet: length(local.ams_subnet_arm_id) > 0 ? local.ams_subnet_arm_id : azurerm_subnet.ams[0].id,
                                                          }
                                          }
}
