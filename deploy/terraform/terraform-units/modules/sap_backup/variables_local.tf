# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.


###############################################################################
#                                                                             #
#                            Local Variables                                  #
#                                                                             #
###############################################################################

locals {
  backup_prefix          = var.naming.prefix.BACKUP
  environment            = var.infrastructure.environment
  location               = var.infrastructure.region
  resource_group_name    = local.resource_group_exists ? (
                            try(split("/", var.infrastructure.resource_group.arm_id)[4], "")) : (
                            length(try(var.infrastructure.resource_group.name, "")) > 0 ? (
                              var.infrastructure.resource_group.name) : (
                              format("%s%s%s",
                                var.naming.resource_prefixes.vnet_rg,
                                local.prefix,
                                local.resource_suffixes.vnet_rg
                              )
                            )
                          )
  sap_network_resource_group = var.infrastructure.vnets.sap.resource_group_name
  backup_network_resource_group = try(var.infrastructure.vnets.backup.resource_group_name, null)
  prefix                 = trimspace(var.naming.prefix.BACKUP)
  resource_suffixes      = var.naming.resource_suffixes

  resource_group_exists  = length(try(var.infrastructure.resource_group.id, "")) > 0
  use_existing_network   = var.infrastructure.vnets.backup.subnet_backup != null && var.infrastructure.vnets.backup.subnet_backup.id != null
  use_existing_backup_vnet = var.infrastructure.vnets.backup != null && var.infrastructure.vnets.backup.id != null

  use_deployer           = length(var.deployer_tfstate) > 0
  firewall_exists        = local.use_deployer ? length(trimspace(coalesce(var.deployer_tfstate.firewall_id, ""))) > 0 : false
  firewall_ip            = local.firewall_exists ? try(var.deployer_tfstate.firewall_ip, "") : ""

  rsv_name                  = format("%s%s%s%s",
    var.naming.resource_prefixes.backup_vault,
    local.backup_prefix,
    local.environment,
    random_id.deployment_id.hex
  )

  BACKUP_virtual_network_name   = var.infrastructure.vnets.backup.exists ? (
                                  try(split("/", var.infrastructure.vnets.backup.id)[8], "")) : (
                                  coalesce(
                                    var.infrastructure.vnets.backup.name,
                                    format("%s%s%s", var.naming.resource_prefixes.vnet, local.prefix, local.resource_suffixes.vnet)
                                  )
                                )

  backup_policy_name      = format("%s%s%s%s",
    var.naming.resource_prefixes.backup_policy,
    local.backup_prefix,
    local.environment,
    random_id.deployment_id.hex
  )

  private_endpoint_name   = format("%s%s%s%s",
    var.naming.resource_prefixes.backup_private_endpoint,
    local.backup_prefix,
    local.environment,
    random_id.deployment_id.hex
  )

  tags = merge(
    var.infrastructure.tags,
    {
      "backup-environment" = local.environment
      "backup-location"    = local.location
      "backup-prefix"      = local.backup_prefix
    }
  )
}

variable "deployer_tfstate" {
  description               = "Deployer remote tfstate file"
}
