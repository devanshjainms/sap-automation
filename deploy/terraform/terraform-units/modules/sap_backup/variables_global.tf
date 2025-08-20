# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

variable "naming" { description = "Defines the names for the resources" }

variable "infrastructure" {
  description                 = "Details of the Azure infrastructure to deploy the backup solution into"
  type = object({
    environment               = string
    region                    = string

    resource_group            = object({
      name                    = string
      exists                  = bool
    })

    vnets = object({
      sap = object({
        id                    = string
        name                  = string
        resource_group_name   = string
      })

      backup                  = optional(object({
        id                    = optional(string)
        name                  = optional(string)
        resource_group_name   = optional(string)
        address_space         = optional(list(string))
        exists                = optional(bool, false)
        subnet_backup         = optional(object({
          id                  = optional(string)
          name                = optional(string)
          resource_group_name = optional(string)
          address_prefixes    = optional(list(string))
        }))
      }))
    })

    tags                      = map(string)
  })
}


variable "backup_configuration" {
  description                      = "Configuration for the backup infrastructure"
  type                             = object({
    vault_sku                      = optional(string, "Standard")
    storage_mode_type              = optional(string, "LocallyRedundant")
    cross_region_restore_enabled   = optional(bool, false)
    soft_delete_enabled            = optional(bool, true)
    public_network_access_enabled  = optional(bool, false)
    enable_private_endpoint        = optional(bool, true)
    create_key_vault               = optional(bool, false)
    encryption_key_id              = optional(string, null)
    infrastructure_encryption_enabled = optional(bool, false)
  })

  default = {
    vault_sku                      = "Standard"
    storage_mode_type              = "LocallyRedundant"
    cross_region_restore_enabled   = false
    soft_delete_enabled            = true
    public_network_access_enabled  = false
    enable_private_endpoint        = true
    create_key_vault               = false
    encryption_key_id              = null
    infrastructure_encryption_enabled = false
  }
}

variable "backup_policy" {
  description                       = "Configuration for SAP HANA backup policies"
  type = object({
    time_zone                       = optional(string, "UTC")
    compression_enabled             = optional(bool, false)

    full_backup                     = object({
      frequency                     = string
      time                          = string
      weekdays                      = optional(list(string), ["Sunday"])

      retention_weekly              = object({
        count                       = number
        weekdays                    = list(string)
      })

      retention_monthly             = object({
        count                       = number
        weekdays                    = list(string)
        weeks                       = list(string)
      })

      retention_yearly              = object({
        count                       = number
        weekdays                    = list(string)
        weeks                       = list(string)
        months                      = list(string)
      })
    })

    incremental_backup              = object({
      frequency                     = string  # "Daily"
      time                          = string  # "01:00"
      weekdays                      = list(string)
      retention_days                = number
    })

    log_backup = object({
      frequency_in_minutes          = number
      retention_days                = number
    })
  })

  default = {
    time_zone                       = "UTC"
    compression_enabled             = false

    full_backup                     = {
      frequency                     = "Weekly"
      time                          = "23:00"
      weekdays                      = ["Sunday"]

      retention_weekly = {
        count                       = 12
        weekdays                    = ["Sunday"]
      }

      retention_monthly = {
        count                       = 12
        weekdays                    = ["Sunday"]
        weeks                       = ["First"]
      }

      retention_yearly = {
        count                       = 7
        weekdays                    = ["Sunday"]
        weeks                       = ["First"]
        months                      = ["January"]
      }
    }

    incremental_backup = {
      frequency                     = "Daily"
      time                          = "01:00"
      weekdays                      = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
      retention_days                = 30
    }

    log_backup = {
      frequency_in_minutes          = 15
      retention_days                = 7
    }
  }
}

variable "sap_systems" {
  description                     = "List of SAP systems to be backed up"
  type = list(object({
    sid                           = string
    environment                   = string
    resource_group_name           = string
    hana_instance_number          = string
    database_names                = optional(list(string), [])
    exclude_from_backup           = optional(bool, false)
  }))
  default = []
}

variable "target_workload_zones" {
  description                     = "List of workload zone configurations to discover SAP systems from"
  type                            = list(object({
    code                          = string
    environment                   = string
    region                        = string
  }))
  default                         = []
}

variable "tags" {
  description                     = "List of tags to associate to all resources"
}
