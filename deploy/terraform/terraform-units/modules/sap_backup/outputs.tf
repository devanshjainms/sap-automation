# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

output "recovery_services_vault" {
  description             = "Recovery Services Vault details"
  value                   = {
    id                    = azurerm_recovery_services_vault.main.id
    name                  = azurerm_recovery_services_vault.main.name
  }
}

output "backup_policy" {
  description             = "Backup policy details"
  value                   = {
    id                    = azurerm_backup_policy_vm_workload.hana.id
    name                  = azurerm_backup_policy_vm_workload.hana.name
  }
}

output "private_endpoint" {
  description             = "Private endpoint details"
  value                   = var.backup_configuration.enable_private_endpoint ? {
    id                    = azurerm_private_endpoint.backup[0].id
    name                  = azurerm_private_endpoint.backup[0].name
    private_ip_address    = azurerm_private_endpoint.backup[0].private_service_connection[0].private_ip_address
  } : null
}

output "backup_vnet" {
  description             = "Backup VNet details"
  value                   = local.use_existing_network ? null : {
    id                    = azurerm_virtual_network.backup[0].id
    name                  = azurerm_virtual_network.backup[0].name
    address_space         = azurerm_virtual_network.backup[0].address_space
    resource_group_name   = azurerm_virtual_network.backup[0].resource_group_name
  }
}

output "backup_subnet" {
  description             = "Backup subnet details"
  value                   = local.use_existing_network ? null : {
    id                    = azurerm_subnet.backup[0].id
    name                  = azurerm_subnet.backup[0].name
    address_prefixes      = azurerm_subnet.backup[0].address_prefixes
  }
}

output "backup_nsg" {
  description             = "Backup NSG details"
  value                   = local.use_existing_network ? null : {
    id                    = azurerm_network_security_group.backup[0].id
    name                  = azurerm_network_security_group.backup[0].name
  }
}

output "key_vault" {
  description             = "Key Vault details for backup secrets"
  value                   = var.backup_configuration.create_key_vault ? {
    id                    = azurerm_key_vault.backup[0].id
    name                  = azurerm_key_vault.backup[0].name
  } : null
}

output "resource_group" {
  description             = "Resource group details"
  value                   = {
    name                  = local.resource_group_name
    location              = local.location
  }
}

output "backup_configuration_summary" {
  description               = "Summary of backup configuration"
  value                    = {
    vault_name             = azurerm_recovery_services_vault.main.name
    policy_name            = azurerm_backup_policy_vm_workload.hana.name
    storage_mode           = var.backup_configuration.storage_mode_type
    cross_region_restore   = var.backup_configuration.cross_region_restore_enabled
    soft_delete_enabled    = var.backup_configuration.soft_delete_enabled
    private_endpoint_enabled = var.backup_configuration.enable_private_endpoint
    full_backup_frequency    = var.backup_policy.full_backup.frequency
    incremental_backup_frequency = var.backup_policy.incremental_backup.frequency
    log_backup_frequency_minutes = var.backup_policy.log_backup.frequency_in_minutes
  }
}
