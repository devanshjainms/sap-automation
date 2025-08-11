# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

variable "backup_configuration_name" {
  description               = "Name of the backup configuration (e.g., DEV-SECE-BUP01-BACKUP)"
  type                      = string
}

variable "deployer_environment" {
  description               = "Deployer environment name (MGMT, DEV, QA, PRD, etc.)"
  type                      = string
  default                   = "MGMT"
}

variable "deployer_region" {
  description               = "Deployer region code (SECE, EAUS, etc.)"
  type                      = string
  default                   = "SECE"
}

variable "deployer_remote_state_resource_group_name" {
  description               = "Resource group name where the deployer state is stored"
  type                      = string
  default                   = ""
}

variable "deployer_remote_state_storage_account_name" {
  description               = "Storage account name where the deployer state is stored"
  type                      = string
  default                   = ""
}

variable "infrastructure" {
  description               = "Infrastructure configuration overrides"
  type                      = object({
    resource_group          = optional(object({
      name                  = string
      use_existing          = bool
    }))
  })
  default                   = {
    resource_group          = {
      name                  = ""
      use_existing          = false
    }
  }
}

variable "sap_vnet_arm_id" {
  description               = "ID of the SAP VNet to connect backup infrastructure to"
  type                      = string
}

variable "backup_vnet_arm_id" {
  description               = "ID of the existing backup VNet to connect backup infrastructure to"
  type                      = string
}

variable "backup_subnet_arm_id" {
  description               = "Name of existing backup subnet (if use_existing_sap_network is true)"
  type                      = string
  default                   = ""
}

variable "backup_vnet_address_space" {
  description               = "Address space for the backup VNet"
  type                      = list(string)
  default                   = ["10.100.0.0/16"]
}

variable "backup_subnet_address_prefixes" {
  description               = "Address prefixes for the backup subnet"
  type                      = list(string)
  default                   = ["10.100.1.0/24"]
}

variable "backup_configuration" {
  description = "Backup infrastructure configuration"
  type = object({
    vault_sku                      = optional(string)
    storage_mode_type              = optional(string)
    cross_region_restore_enabled   = optional(bool)
    soft_delete_enabled            = optional(bool)
    public_network_access_enabled  = optional(bool)
    enable_private_endpoint        = optional(bool)
    create_key_vault               = optional(bool)
    encryption_key_id              = optional(string)
    infrastructure_encryption_enabled = optional(bool)
  })
  default = {}
}

variable "backup_policy" {
  description                     = "SAP HANA backup policy configuration"
  type = object({
    time_zone                     = optional(string)
    compression_enabled           = optional(bool)

    full_backup                   = optional(object({
      frequency                   = optional(string)
      time                        = optional(string)
      weekdays                    = optional(list(string))

      retention_weekly            = optional(object({
        count                     = optional(number)
        weekdays                  = optional(list(string))
      }))

      retention_monthly           = optional(object({
        count                     = optional(number)
        weekdays                  = optional(list(string))
        weeks                     = optional(list(string))
      }))

      retention_yearly            = optional(object({
        count                     = optional(number)
        weekdays                  = optional(list(string))
        weeks                     = optional(list(string))
        months                    = optional(list(string))
      }))
    }))

    incremental_backup            = optional(object({
      frequency                   = optional(string)
      time                        = optional(string)
      weekdays                    = optional(list(string))
      retention_days              = optional(number)
    }))

    log_backup                    = optional(object({
      frequency_in_minutes        = optional(number)
      retention_days              = optional(number)
    }))
  })
  default = {}
}

variable "sap_systems" {
  description                     = "List of SAP systems to be backed up"
  type                            = list(object({
    sid                            = string
    environment                     = string
    resource_group_name             = string
    hana_instance_number            = string
    database_names                  = optional(list(string), [])
    exclude_from_backup             = optional(bool, false)
  }))
  default = []
}

variable "target_workload_zones" {
  description                     = "List of workload zone configurations to discover SAP systems from"
  type                            = list(object({
    code                           = string
    environment                    = string
    region                         = string
  }))
  default                           = []
}

variable "tags" {
  description                     = "Custom tags to be applied to backup resources"
  type                            = map(string)
  default                           = {}
}
