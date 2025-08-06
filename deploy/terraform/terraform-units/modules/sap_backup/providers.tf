# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

terraform {
  required_providers {
    azurerm                   = {
      source                  = "hashicorp/azurerm"
      version                 = "~>3.108"
      configuration_aliases   = [
                                  azurerm.main,
                                  azurerm.deployer,
                                  azurerm.dnsmanagement,
                                  azurerm.peering,
                                  azurerm.privatelinkdnsmanagement
                                ]
    }
    azapi                     = {
      source                  = "azure/azapi"
      version                 = "~>1.13"
      configuration_aliases   = [
                                  azapi.api
                                ]
    }
  }
}
