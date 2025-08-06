# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

data "terraform_remote_state" "deployer" {
  count   = 1
  backend = "azurerm"
  config = {
    resource_group_name  = local.deployer_remote_state_resource_group_name
    storage_account_name = local.deployer_remote_state_storage_account_name
    container_name       = "tfstate"
    key                  = local.deployer_tfstate_key
  }
}

data "terraform_remote_state" "landscape" {
  count   = length(var.target_workload_zones)
  backend = "azurerm"
  config = {
    resource_group_name  = local.deployer_remote_state_resource_group_name
    storage_account_name = local.deployer_remote_state_storage_account_name
    container_name       = "tfstate"
    key                  = "terraform-${var.target_workload_zones[count.index].environment}-${var.target_workload_zones[count.index].region}-${var.target_workload_zones[count.index].code}-landscape.tfstate"
  }
}

data "terraform_remote_state" "sap_system" {
  for_each = { for system in var.sap_systems : "${system.environment}-${system.sid}" => system if !system.exclude_from_backup }
  backend  = "azurerm"
  config = {
    resource_group_name  = local.deployer_remote_state_resource_group_name
    storage_account_name = local.deployer_remote_state_storage_account_name
    container_name       = "tfstate"
    key                  = "terraform-${each.value.environment}-${local.region_code}-${each.value.sid}-sap_system.tfstate"
  }
}
