# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.


#######################################4#######################################8
#                                                                              #
#                            Local Variables                                   #
#                                                                              #
#######################################4#######################################8

locals {

  version_label                       = trimspace(file("${path.module}/../../../configs/version.txt"))

  spn_key_vault_arm_id                = var.use_deployer ?  coalesce(var.spn_keyvault_id, try(data.terraform_remote_state.deployer[0].outputs.deployer_kv_user_arm_id, "")) : ""

  key_vault = {
    spn = {
      id = local.spn_key_vault_arm_id
    }
  }

  parsed_id                           = provider::azurerm::parse_resource_id(var.tfstate_resource_id)

  SAPLibrary_subscription_id          = local.parsed_id["subscription_id"]
  SAPLibrary_resource_group_name      = local.parsed_id["resource_group_name"]
  tfstate_storage_account_name        = local.parsed_id["resource_name"]
  tfstate_container_name              = module.sap_namegenerator.naming.resource_suffixes.tfstate

  deployer_subscription_id            = coalesce(
                                          try(data.terraform_remote_state.deployer[0].outputs.created_resource_group_subscription_id,""),
                                          local.SAPLibrary_subscription_id
                                        )

  backup_vnet_logical_name            = local.infrastructure.vnets.backup.logical_name

  custom_names                        = length(var.name_override_file) > 0 ? (
                                            jsondecode(file(format("%s/%s", path.cwd, var.name_override_file)))
                                          ) : (
                                          null
                                        )

}

resource "random_id" "deployment_id" {
  byte_length = 3
}
