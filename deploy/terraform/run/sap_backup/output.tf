# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

output "backup_infrastructure" {
  description                   = "Backup infrastructure details"
  value                         = module.sap_backup
}

output "recovery_services_vault" {
  description                   = "Recovery Services Vault details"
  value                         = module.sap_backup.recovery_services_vault
}

output "backup_policy" {
  description                   = "Backup policy details"
  value                         = module.sap_backup.backup_policy
}

output "backup_configuration_summary" {
  description                   = "Summary of backup configuration"
  value                         = module.sap_backup.backup_configuration_summary
}

output "backup_network" {
  description                   = "Backup network details"
  value                         = {
    vnet                        = module.sap_backup.backup_vnet
    subnet                      = module.sap_backup.backup_subnet
    nsg                         = module.sap_backup.backup_nsg
  }
}

output "private_endpoint" {
  description                   = "Private endpoint details"
  value                         = module.sap_backup.private_endpoint
}

output "key_vault" {
  description                   = "Key Vault for backup secrets"
  value                         = module.sap_backup.key_vault
}
