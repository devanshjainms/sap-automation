# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

terraform {
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      configuration_aliases = [azurerm.main, azurerm.deployer, azurerm.dnsmanagement, azurerm.privatelinkdnsmanagement, azurerm.peering, azurerm.kv_user]
    }

    azapi = {
      source                = "azure/azapi"
      configuration_aliases = [azapi.api]
    }
  }
}
