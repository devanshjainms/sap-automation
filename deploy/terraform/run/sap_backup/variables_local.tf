# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.


#######################################4#######################################8
#                                                                              #
#                            Local Variables                                   #
#                                                                              #
#######################################4#######################################8

locals {

  version_label                        = trimspace(file("${path.module}/../../../configs/version.txt"))

  environment                          = upper(local.infrastructure.environment)

  backup_vnet_logical_name             = local.infrastructure.vnets.backup.logical_name

  tfstate_container_name               = module.sap_namegenerator.naming.resource_suffixes.tfstate

  custom_names                         = length(var.name_override_file) > 0 ? (
                                            jsondecode(file(format("%s/%s", path.cwd, var.name_override_file)))
                                          ) : (
                                          null
                                        )



}
