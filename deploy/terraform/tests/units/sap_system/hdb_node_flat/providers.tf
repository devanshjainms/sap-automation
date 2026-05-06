# Test-only providers.tf — replaces the module's configuration_aliases
# with concrete provider definitions that can be mocked in tests.
# This is the ONLY file that differs from the production module.

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azurerm" {
  alias    = "main"
  features {}
}

provider "azurerm" {
  alias    = "deployer"
  features {}
}

provider "azurerm" {
  alias    = "dnsmanagement"
  features {}
}

provider "azurerm" {
  alias    = "privatelinkdnsmanagement"
  features {}
}
