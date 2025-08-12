# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

terraform {
  backend "azurerm" {
    use_azuread_auth     = true
  }
}
