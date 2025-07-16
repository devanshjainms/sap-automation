# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

#######################################4#######################################8
#                                                                              #
#                      Azure Backup for SAP HANA Database                      #
#                                                                              #
#######################################4#######################################8

# Register HANA VMs with Recovery Services Vault
resource "azurerm_backup_protected_vm" "hana_vm" {
  provider                             = azurerm.main
  count                                = local.enable_deployment && (var.enable_hana_backup || (var.enable_hsr_backup && var.database.high_availability)) ? var.database_server_count : 0

  resource_group_name                  = var.landscape_tfstate.recovery_services_vault_name != "" ? (
                                            split("/", var.landscape_tfstate.recovery_services_vault_id)[4]
                                          ) : ""

  recovery_vault_name                  = var.landscape_tfstate.recovery_services_vault_name
  source_vm_id                         = azurerm_linux_virtual_machine.vm_dbnode[count.index].id
  backup_policy_id                     = var.landscape_tfstate.backup_policy_hana_id

  depends_on = [
    azurerm_linux_virtual_machine.vm_dbnode,
    azurerm_virtual_machine_extension.monitoring_extension_db
  ]
}
