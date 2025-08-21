# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.


#######################################4#######################################8
#                                                                              #
#                                Resource Group                                #
#                                                                              #
#######################################4#######################################8

data "azurerm_resource_group" "backup" {
  provider                = azurerm.main
  count                   = var.infrastructure.resource_group.exists ? 1 : 0
  name                    = local.resource_group_name
}

resource "azurerm_resource_group" "backup"        {
  provider                = azurerm.main
  count                   = var.infrastructure.resource_group.exists ? 0 : 1
  name                    = local.resource_group_name
  location                = local.location
  tags                    = local.tags
}


resource "random_id" "deployment_id" {
  byte_length             = 2
}

resource "azurerm_recovery_services_vault" "main" {
  name                         = local.rsv_name
  location                     = local.location
  resource_group_name          = local.resource_group_name
  sku                          = var.backup_configuration.vault_sku
  storage_mode_type           = var.backup_configuration.storage_mode_type
  cross_region_restore_enabled = var.backup_configuration.cross_region_restore_enabled
  soft_delete_enabled         = var.backup_configuration.soft_delete_enabled
  public_network_access_enabled = var.backup_configuration.public_network_access_enabled

  dynamic "encryption" {
    for_each = var.backup_configuration.encryption_key_id != null ? [1] : []
    content {
      key_id                            = var.backup_configuration.encryption_key_id
      infrastructure_encryption_enabled = var.backup_configuration.infrastructure_encryption_enabled
    }
  }

  dynamic "identity" {
    for_each                  = var.backup_configuration.encryption_key_id != null ? [1] : []
    content {
      type                    = "SystemAssigned"
    }
  }

  tags                        = local.tags
  depends_on                  = [azurerm_resource_group.backup]
}

resource "azurerm_backup_policy_vm_workload" "hana" {
  name                = local.backup_policy_name
  resource_group_name = local.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.main.name
  workload_type       = "SAPHanaDatabase"

  settings {
    time_zone           = var.backup_policy.time_zone
    compression_enabled = var.backup_policy.compression_enabled
  }

  protection_policy {
    policy_type = "Full"

    backup {
      frequency = var.backup_policy.full_backup.frequency
      time      = var.backup_policy.full_backup.time
      weekdays  = var.backup_policy.full_backup.weekdays
    }

    dynamic "retention_daily" {
      for_each = var.backup_policy.full_backup.frequency == "Daily" && var.backup_policy.full_backup.retention_daily != null ? [1] : []
      content {
        count = var.backup_policy.full_backup.retention_daily.count
      }
    }

    retention_weekly {
      count    = var.backup_policy.full_backup.retention_weekly.count
      weekdays = var.backup_policy.full_backup.retention_weekly.weekdays
    }

    retention_monthly {
      count       = var.backup_policy.full_backup.retention_monthly.count
      format_type = "Weekly"
      weekdays    = var.backup_policy.full_backup.retention_monthly.weekdays
      weeks       = var.backup_policy.full_backup.retention_monthly.weeks
    }

    retention_yearly {
      count       = var.backup_policy.full_backup.retention_yearly.count
      format_type = "Weekly"
      weekdays    = var.backup_policy.full_backup.retention_yearly.weekdays
      weeks       = var.backup_policy.full_backup.retention_yearly.weeks
      months      = var.backup_policy.full_backup.retention_yearly.months
    }
  }

  protection_policy {
    policy_type = "Incremental"

    backup {
      frequency = var.backup_policy.incremental_backup.frequency
      time      = var.backup_policy.incremental_backup.time
      weekdays  = var.backup_policy.incremental_backup.weekdays
    }

    simple_retention {
      count = var.backup_policy.incremental_backup.retention_days
    }
  }

  protection_policy {
    policy_type = "Log"

    backup {
      frequency_in_minutes = var.backup_policy.log_backup.frequency_in_minutes
    }

    simple_retention {
      count = var.backup_policy.log_backup.retention_days
    }
  }
}

resource "azurerm_private_dns_zone" "backup" {
  count               = var.backup_configuration.enable_private_endpoint ? 1 : 0
  name                = "privatelink.${local.location}.backup.windowsazure.com"
  resource_group_name = local.resource_group_name
  tags                = local.tags

  depends_on = [azurerm_resource_group.backup]
}

resource "azurerm_private_dns_zone_virtual_network_link" "backup" {
  count                 = var.backup_configuration.enable_private_endpoint ? 1 : 0
  name                  = "backup-vnet-link"
  resource_group_name   = local.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.backup[0].name
  virtual_network_id    = var.infrastructure.vnets.sap.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_endpoint" "backup" {
  count               = var.backup_configuration.enable_private_endpoint ? 1 : 0
  name                = local.private_endpoint_name
  location            = local.location
  resource_group_name = local.resource_group_name
  subnet_id           = local.use_existing_network ? (
    length(data.azurerm_subnet.subnet_backup) > 0 ? data.azurerm_subnet.subnet_backup[0].id : null
  ) : (
    length(azurerm_subnet.subnet_backup) > 0 ? azurerm_subnet.subnet_backup[0].id : null
  )

  depends_on = [
    azurerm_subnet.subnet_backup,
    data.azurerm_subnet.subnet_backup
  ]

  private_service_connection {
    name                           = "${local.private_endpoint_name}-connection"
    private_connection_resource_id = azurerm_recovery_services_vault.main.id
    subresource_names              = ["AzureBackup"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "backup-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.backup[0].id]
  }

  tags = local.tags
}

resource "azurerm_network_security_group" "backup" {
  count               = local.use_existing_network ? 0 : 1
  name                = "${local.backup_prefix}-${local.environment}-nsg"
  location            = local.location
  resource_group_name = local.resource_group_name
  tags                = local.tags

  security_rule {
    name                       = "AllowBackupHTTPS"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "Storage"
  }

  security_rule {
    name                       = "AllowAzureBackup"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureBackup"
  }

  depends_on = [azurerm_resource_group.backup]
}

resource "azurerm_subnet_network_security_group_association" "backup" {
  count                     = local.use_existing_network ? 0 : 1
  subnet_id                 = azurerm_subnet.subnet_backup[0].id
  network_security_group_id = azurerm_network_security_group.backup[0].id
}

resource "azurerm_key_vault" "backup" {
  count                      = var.backup_configuration.create_key_vault ? 1 : 0
  name                       = "${local.backup_prefix}${local.environment}kv${random_id.deployment_id.hex}"
  location                   = local.location
  resource_group_name        = local.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Recover",
      "Backup",
      "Restore"
    ]
  }

  tags = local.tags

  depends_on = [azurerm_resource_group.backup]
}

data "azurerm_client_config" "current" {}


resource "azurerm_virtual_network_peering" "backup_to_sap" {
  count                        = !local.use_existing_network ? 1 : 0
  name                         = "${local.backup_prefix}-${local.environment}-to-sap-peering"
  resource_group_name          = local.resource_group_name
  virtual_network_name         = azurerm_virtual_network.vnet_backup[0].name
  remote_virtual_network_id    = var.infrastructure.vnets.sap.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false

  depends_on                   = [
                                  azurerm_virtual_network.vnet_backup,
                                  azurerm_subnet.subnet_backup
                                ]
}

resource "azurerm_virtual_network_peering" "sap_to_backup" {
  count                        = !local.use_existing_network ? 1 : 0
  name                         = "sap-to-${local.backup_prefix}-${local.environment}-peering"
  resource_group_name          = var.infrastructure.vnets.sap.resource_group_name
  virtual_network_name         = split("/", var.infrastructure.vnets.sap.id)[8]
  remote_virtual_network_id    = azurerm_virtual_network.vnet_backup[0].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false

  depends_on                   = [
                                  azurerm_virtual_network.vnet_backup,
                                  azurerm_subnet.subnet_backup
                                ]
}
