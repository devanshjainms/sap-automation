# Test harness for sap_library terraform-units module
# Constructs minimal valid input objects and invokes the module with mock providers.
# This allows testing conditional resource creation logic without real Azure access.

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

variable "use_private_endpoint" {
  type    = bool
  default = false
}

variable "use_custom_dns_a_registration" {
  type    = bool
  default = false
}

variable "enable_purge_control_for_keyvaults" {
  type    = bool
  default = false
}

variable "place_delete_lock_on_resources" {
  type    = bool
  default = false
}

variable "bootstrap" {
  type    = bool
  default = true
}

variable "dns_label" {
  type    = string
  default = ""
}

variable "create_privatelink_dns_zones" {
  type    = bool
  default = false
}

variable "register_storage_accounts_keyvaults_with_dns" {
  type    = bool
  default = false
}

variable "deployer_use" {
  type    = bool
  default = false
}

variable "shared_access_key_enabled" {
  type    = bool
  default = true
}

variable "public_network_access_enabled" {
  type    = bool
  default = true
}

variable "enable_firewall_for_keyvaults_and_storage" {
  type    = bool
  default = false
}

variable "application_configuration_deployment" {
  type    = bool
  default = false
}

variable "sapbits_name_override" {
  type    = string
  default = ""
}

variable "tfstate_name_override" {
  type    = string
  default = ""
}

variable "rg_name_override" {
  type    = string
  default = ""
}

variable "rg_exists" {
  type    = bool
  default = false
}

variable "rg_id" {
  type    = string
  default = ""
}

variable "key_vault_id" {
  type    = string
  default = ""
}

variable "short_named_endpoints_nics" {
  type    = bool
  default = false
}

variable "assign_permissions" {
  type    = bool
  default = false
}

variable "deployer_tfstate_subnet_mgmt_id" {
  type    = string
  default = ""
}

# Overridable fields for negative validation tests
variable "test_environment" {
  type    = string
  default = "DEV"
  validation {
    condition     = length(trimspace(var.test_environment)) > 0
    error_message = "Environment must not be empty."
  }
}

variable "test_region" {
  type    = string
  default = "eastus"
  validation {
    condition     = length(trimspace(var.test_region)) > 0
    error_message = "Region must not be empty."
  }
}

variable "test_keyvault_deploy_cred_id" {
  type    = string
  default = ""
  validation {
    condition     = var.test_keyvault_deploy_cred_id == "" || length(split("/", var.test_keyvault_deploy_cred_id)) == 9
    error_message = "If specified, keyvault_id_for_deployment_credentials must be a valid Azure resource ID (9 segments)."
  }
}

module "sap_library" {
  source = "../../../terraform-units/modules/sap_library"

  providers = {
    azurerm.main                     = azurerm
    azurerm.deployer                 = azurerm
    azurerm.dnsmanagement            = azurerm
    azurerm.privatelinkdnsmanagement = azurerm
  }

  infrastructure = {
    environment = var.test_environment
    region      = var.test_region
    codename    = ""
    resource_group = {
      name   = var.rg_name_override
      id     = var.rg_id
      exists = var.rg_exists
    }
    tags               = {}
    assign_permissions = var.assign_permissions
    spn_id             = ""
  }

  storage_account_sapbits = {
    id                       = ""
    exists                   = false
    name                     = var.sapbits_name_override
    account_tier             = "Standard"
    account_replication_type = "LRS"
    account_kind             = "StorageV2"
    file_share = {
      enable_deployment = true
      is_existing       = false
      name              = "sapbits"
    }
    sapbits_blob_container = {
      enable_deployment = true
      is_existing       = false
      name              = "sapbits"
    }
    shared_access_key_enabled                 = var.shared_access_key_enabled
    public_network_access_enabled             = var.public_network_access_enabled
    enable_firewall_for_keyvaults_and_storage = var.enable_firewall_for_keyvaults_and_storage
  }

  storage_account_tfstate = {
    id                       = ""
    exists                   = false
    name                     = var.tfstate_name_override
    account_tier             = "Standard"
    account_replication_type = "LRS"
    account_kind             = "StorageV2"
    tfstate_blob_container = {
      is_existing = false
      name        = "tfstate"
    }
    tfvars_blob_container = {
      is_existing = false
      name        = "tfvars"
    }
    ansible_blob_container = {
      is_existing = false
      name        = "ansible"
    }
    shared_access_key_enabled                 = var.shared_access_key_enabled
    public_network_access_enabled             = var.public_network_access_enabled
    enable_firewall_for_keyvaults_and_storage = var.enable_firewall_for_keyvaults_and_storage
  }

  deployer = {
    use                          = var.deployer_use
    application_configuration_id = ""
    control_plane_name           = ""
    resource_group_name          = ""
    management_network_id        = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet"
  }

  key_vault = {
    id                                     = var.key_vault_id
    keyvault_id_for_deployment_credentials = var.test_keyvault_deploy_cred_id
  }

  deployer_tfstate = var.deployer_tfstate_subnet_mgmt_id != "" ? {
    subnet_mgmt_id = var.deployer_tfstate_subnet_mgmt_id
  } : {}

  dns_settings = {
    use_custom_dns_a_registration = var.use_custom_dns_a_registration
    dns_label                     = var.dns_label
    dns_zone_names = {
      blob_dns_zone_name      = "privatelink.blob.core.windows.net"
      vault_dns_zone_name     = "privatelink.vaultcore.azure.net"
      table_dns_zone_name     = "privatelink.table.core.windows.net"
      file_dns_zone_name      = "privatelink.file.core.windows.net"
      appconfig_dns_zone_name = "privatelink.azconfig.io"
    }
    management_dns_resourcegroup_name            = ""
    management_dns_subscription_id               = ""
    privatelink_dns_subscription_id              = ""
    privatelink_dns_resourcegroup_name           = ""
    register_storage_accounts_keyvaults_with_dns = var.register_storage_accounts_keyvaults_with_dns
    register_endpoints_with_dns                  = false
    create_privatelink_dns_zones                 = var.create_privatelink_dns_zones
    additional_network_id                        = ""
  }

  naming = {
    prefix = {
      DEPLOYER      = "DEV-EAUS-DEP"
      SDU           = "DEV-EAUS-SAP-HN1"
      WORKLOAD_ZONE = "DEV-EAUS-SAP"
      LIBRARY       = "DEV-EAUS"
    }
    separator = "_"
    resource_prefixes = {
      admin_nic                 = ""
      admin_subnet              = ""
      admin_subnet_nsg          = ""
      agent_subnet              = ""
      ams_subnet                = ""
      anf_subnet                = ""
      anf_subnet_nsg            = ""
      ansible                   = ""
      app_alb                   = ""
      app_asg                   = ""
      app_avset                 = ""
      app_service_plan          = ""
      app_subnet                = ""
      app_subnet_nsg            = ""
      appconfig_private_link    = ""
      appconfig_private_svc     = ""
      appconfig_link            = ""
      bastion_host              = ""
      bastion_pip               = ""
      db_alb                    = ""
      db_subnet                 = ""
      db_subnet_nsg             = ""
      deployer_rg               = ""
      deployer_state            = ""
      deployer_subnet           = ""
      deployer_subnet_nsg       = ""
      "deployer_web-subnet"     = ""
      dev_center                = ""
      disk                      = ""
      dns_link                  = ""
      firewall                  = ""
      firewall_rule_app         = ""
      firewall_rule_db          = ""
      fw_route                  = ""
      keyvault_private_link     = ""
      keyvault_private_svc      = ""
      kv                        = ""
      library_rg                = ""
      msi                       = ""
      nat_gateway               = ""
      nic                       = ""
      osdisk                    = ""
      pip                       = ""
      ppg                       = ""
      routetable                = ""
      storage_private_link_diag = ""
      storage_private_link_tf   = ""
      storage_private_link_sap  = ""
      storage_private_svc_diag  = ""
      storage_private_svc_tf    = ""
      storage_private_svc_sap   = ""
      storage_subnet            = ""
      tfstate                   = ""
      vm                        = ""
      vmss                      = ""
      vnet                      = ""
      vnet_rg                   = ""
    }
    resource_suffixes = {
      admin_nic                 = "-admin-nic"
      admin_subnet              = "admin-subnet"
      admin_subnet_nsg          = "adminSubnet-nsg"
      agent_subnet              = "_agent-subnet"
      anf_subnet                = "anf-subnet"
      anf_subnet_nsg            = "anfSubnet-nsg"
      ansible                   = "ansible"
      app_alb                   = "app-alb"
      app_asg                   = "app-asg"
      app_avset                 = "app-avset"
      app_service_plan          = "-app-service-plan"
      app_subnet                = "app-subnet"
      app_subnet_nsg            = "appSubnet-nsg"
      appconfig_private_link    = "-appconfig-private-endpoint"
      appconfig_private_svc     = "-appconfig-private-service"
      appconfig_link            = "appconfig-link"
      bastion_host              = "bastion-host"
      bastion_pip               = "bastion-pip"
      db_alb                    = "db-alb"
      db_subnet                 = "db-subnet"
      db_subnet_nsg             = "dbSubnet-nsg"
      deployer_rg               = "-INFRASTRUCTURE"
      deployer_state            = "_DEPLOYER.terraform.tfstate"
      deployer_subnet           = "_deployment-subnet"
      deployer_subnet_nsg       = "_deployment-nsg"
      "deployer_web-subnet"     = "_deployment-web-subnet"
      deployment_objects        = "-deployment-objects"
      dev_center                = "-devcenter"
      disk                      = ""
      dns_link                  = "dns-link"
      firewall                  = "firewall"
      firewall_rule_app         = "firewall-rule-app"
      firewall_rule_db          = "firewall-rule-db"
      fw_route                  = "firewall-route"
      keyvault_private_link     = "-keyvault-private-endpoint"
      keyvault_private_svc      = "-keyvault-private-service"
      kv                        = ""
      library_rg                = "-SAP_LIBRARY"
      msi                       = "-msi"
      nat_gateway               = "-nat-gateway"
      nic                       = "-nic"
      osdisk                    = "-OsDisk"
      pip                       = "-pip"
      ppg                       = "-ppg"
      routetable                = "route-table"
      sapbits                   = "sapbits"
      storage_private_link_diag = "-diag-storage-private-endpoint"
      storage_private_link_tf   = "-tf-storage-private-endpoint"
      storage_private_link_sap  = "-sap-storage-private-endpoint"
      storage_private_svc_diag  = "-diag-storage-private-service"
      storage_private_svc_tf    = "-tf-storage-private-service"
      storage_private_svc_sap   = "-sap-storage-private-service"
      storage_subnet            = "storage-subnet"
      tfstate                   = "tfstate"
      vm                        = ""
      vmss                      = "-vmss"
      vnet                      = "-vnet"
      vnet_rg                   = "-INFRASTRUCTURE"
      webapp_url                = "-sapdeployment"
    }
    storageaccount_names = {
      LIBRARY = {
        library_storageaccount_name        = "deveaussaplibabc"
        terraformstate_storageaccount_name = "deveaustfstateabc"
      }
    }
    keyvault_names = {
      LIBRARY = {
        private_access = "DEVEAUSprvtABC"
        user_access    = "DEVEAUSuserABC"
      }
    }
  }

  use_private_endpoint                 = var.use_private_endpoint
  use_custom_dns_a_registration        = var.use_custom_dns_a_registration
  enable_purge_control_for_keyvaults   = var.enable_purge_control_for_keyvaults
  place_delete_lock_on_resources       = var.place_delete_lock_on_resources
  bootstrap                            = var.bootstrap
  application_configuration_deployment = var.application_configuration_deployment
  Agent_IP                             = ""
  short_named_endpoints_nics           = var.short_named_endpoints_nics
}

# Section 1: Resource Group outputs
output "resource_group_name" {
  value = module.sap_library.created_resource_group_name
}

# Section 2: TFState storage account outputs
output "tfstate_storage_account" {
  value = module.sap_library.tfstate_storage_account
}

output "storagecontainer_tfstate" {
  value = module.sap_library.storagecontainer_tfstate
}

output "remote_state_storage_account_name" {
  value = module.sap_library.remote_state_storage_account_name
}

# Section 3: SAPBits storage account outputs
output "sapbits_storage_account_name" {
  value = module.sap_library.sapbits_storage_account_name
}

output "storagecontainer_sapbits_name" {
  value = module.sap_library.storagecontainer_sapbits_name
}

output "sapbits_sa_resource_group_name" {
  value = module.sap_library.sapbits_sa_resource_group_name
}
