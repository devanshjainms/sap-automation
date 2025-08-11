# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

/*
  Description:
  Transform input variables for the backup deployment
*/

locals {
  version_label                   = trimspace(file("${path.module}/../../../configs/version.txt"))

  name_components                 = split("-", var.backup_configuration_name)
  environment                     = local.name_components[0]
  region_code                     = local.name_components[1]
  backup_name                     = local.name_components[2]

  location_map = {
    "SECE"                        = "swedencentral"
    "SWCE"                        = "switzerlandcentral"
    "EAUS"                        = "eastus"
    "WEU2"                        = "westeurope"
    "CEUS"                        = "centralus"
  }

  location                        = lookup(local.location_map, upper(local.region_code), "eastus")

  deployer_prefix                 = "${var.deployer_environment}-${var.deployer_region}"
  deployer_tfstate_key            = "${local.deployer_prefix}-DEPLOYER-infrastructure.tfstate"

  deployer_remote_state_resource_group_name  = var.deployer_remote_state_resource_group_name
  deployer_remote_state_storage_account_name = var.deployer_remote_state_storage_account_name

  default_rg_name                 = format("rg-%s-%s-%s-backup",
                                      lower(local.environment),
                                      lower(local.region_code),
                                      lower(local.backup_name)
                                    )

  infrastructure                  = {
    environment                   = lower(local.environment)
    region                        = local.location

    resource_group                = {
      name                        = try(var.infrastructure.resource_group.name, local.default_rg_name)
      use_existing                = try(var.infrastructure.resource_group.use_existing, false)
    }

    vnets = {
      sap = {
        id                        = var.sap_vnet_arm_id
        name                      = split("/", var.sap_vnet_arm_id)[-1]
        resource_group_name       = split("/", var.sap_vnet_arm_id)[-3]
      }

      backup = var.backup_vnet_arm_id != "" && var.backup_vnet_arm_id != null ? {
        id                        = var.backup_vnet_arm_id
        name                      = split("/", var.backup_vnet_arm_id)[-1]
        resource_group_name       = split("/", var.backup_vnet_arm_id)[-3]
        address_space             = null

        subnet_backup             = var.backup_subnet_arm_id != "" && var.backup_subnet_arm_id != null ? {
          id                      = var.backup_subnet_arm_id
          name                    = split("/", var.backup_subnet_arm_id)[-1]
          resource_group_name     = split("/", var.backup_subnet_arm_id)[-3]
          address_prefixes        = null
        } : null
      } : {
        id                        = null
        name                      = null
        resource_group_name       = null
        address_space             = var.backup_vnet_address_space

        subnet_backup             = {
          id                      = null
          name                    = null
          resource_group_name     = null
          address_prefixes        = var.backup_subnet_address_prefixes
        }
      }
    }

    tags = merge(
      {
        "backup-deployment-version" = local.version_label
        "backup-deployment-type"    = "sap-backup"
        "backup-environment"        = local.environment
        "backup-region"             = local.region_code
        "backup-name"               = local.backup_name
      },
      var.tags
    )
  }

  naming = {
    prefix = {
      BACKUP = upper(local.backup_name)
    }

    resource_prefixes = {
      backup_vault             = "rsv-"
      backup_policy           = "bkp-"
      backup_private_endpoint = "pe-backup-"
    }
  }

  backup_configuration = merge(
    {
      vault_sku                        = "Standard"
      storage_mode_type               = "LocallyRedundant"
      cross_region_restore_enabled   = false
      soft_delete_enabled            = true
      public_network_access_enabled  = false
      enable_private_endpoint        = true
      create_key_vault               = false
      encryption_key_id              = null
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
        frequency       = "Daily"
        time           = "01:00"
        weekdays       = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        retention_days = 30
      }

      log_backup = {
        frequency_in_minutes = 15
        retention_days      = 7
      }
    },
    var.backup_policy
  )

  sap_systems                   = var.sap_systems

  target_workload_zones         = var.target_workload_zones
}
