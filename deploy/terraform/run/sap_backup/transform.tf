# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

/*
  Description:
  Transform input variables for the backup deployment
*/

locals {

  infrastructure = {
    environment = coalesce(
      var.environment,
      try(var.infrastructure.environment, "")
    )
    region   = coalesce(var.location, try(var.infrastructure.region, ""))
    codename = try(var.codename, try(var.infrastructure.codename, ""))
    resource_group = {
      name = try(
        coalesce(
          var.backup_resourcegroup_name,
          try(var.infrastructure.resource_group.name, "")
        ),
        ""
      )
      id = try(
        coalesce(
          var.backup_resourcegroup_arm_id,
          try(var.infrastructure.backup_resource_group.arm_id, "")
        ),
        ""
      )
      exists = length(try(
        coalesce(
          var.backup_resourcegroup_arm_id,
          try(var.infrastructure.backup_resource_group.arm_id, "")
        ),
        ""
      )) > 0 ? true : false

    }
    tags = merge(
      var.tags, var.backup_resourcegroup_tags

    )

    authentication = {
      username            = coalesce(var.automation_username, "azureadm")
      password            = var.automation_password
      path_to_public_key  = var.automation_path_to_public_key
      path_to_private_key = var.automation_path_to_private_key
    }
    options = {
      enable_secure_transfer = true
      use_spn                = var.use_spn
      spn_id                 = coalesce(data.azurerm_client_config.current_main.object_id, var.spn_id)
    }

    vnets = {
      sap = {
        id                  = var.sap_vnet_arm_id
        exists              = length(var.sap_vnet_arm_id) > 0
        name                = split("/", var.sap_vnet_arm_id)[-1]
        resource_group_name = split("/", var.sap_vnet_arm_id)[-3]
      }

      backup = var.backup_vnet_arm_id != "" && var.backup_vnet_arm_id != null ? {
        logical_name            = var.backup_network_logical_name
        id                      = var.backup_vnet_arm_id
        name                    = split("/", var.backup_vnet_arm_id)[-1]
        resource_group_name     = split("/", var.backup_vnet_arm_id)[-3]
        address_space           = null
        exists                  = true
        flow_timeout_in_minutes = var.network_flow_timeout_in_minutes
        enable_route_propagation = var.network_enable_route_propagation
        subnet_backup = var.backup_subnet_arm_id != "" && var.backup_subnet_arm_id != null ? {
          id                  = var.backup_subnet_arm_id
          name                = split("/", var.backup_subnet_arm_id)[-1]
          resource_group_name = split("/", var.backup_subnet_arm_id)[-3]
          address_prefixes    = null
        } : null
        } : {
        id                  = null
        name                = null
        resource_group_name = null
        address_space       = var.backup_vnet_address_space
        exists              = false

        subnet_backup = {
          id                  = null
          name                = null
          resource_group_name = null
          address_prefixes    = var.backup_subnet_address_prefixes
        }
      }
    }

  }

  backup_configuration = merge(
    {
      vault_sku                         = "Standard"
      storage_mode_type                 = "LocallyRedundant"
      cross_region_restore_enabled      = false
      soft_delete_enabled               = true
      public_network_access_enabled     = false
      enable_private_endpoint           = true
      create_key_vault                  = false
      encryption_key_id                 = null
      infrastructure_encryption_enabled = false
    },
    var.backup_configuration
  )

  backup_policy = merge(
    {
      time_zone           = "UTC"
      compression_enabled = false

      full_backup = {
        frequency = "Weekly"
        time      = "23:00"
        weekdays  = ["Sunday"]

        retention_weekly = {
          count    = 12
          weekdays = ["Sunday"]
        }

        retention_monthly = {
          count    = 12
          weekdays = ["Sunday"]
          weeks    = ["First"]
        }

        retention_yearly = {
          count    = 7
          weekdays = ["Sunday"]
          weeks    = ["First"]
          months   = ["January"]
        }
      }

      incremental_backup = {
        frequency      = "Daily"
        time           = "01:00"
        weekdays       = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        retention_days = 30
      }

      log_backup = {
        frequency_in_minutes = 15
        retention_days       = 7
      }
    },
    var.backup_policy
  )

  sap_systems = var.sap_systems

  target_workload_zones = var.target_workload_zones

  terraform_state_storage_account = {
    id = var.terraform_storage_account_arm_id
  }
}
