# Test harness for sap_deployer terraform-units module
# Constructs minimal valid input objects and invokes the module with mock providers.
# This allows testing conditional resource creation logic without real Azure access.

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    azapi = {
      source = "azure/azapi"
    }
    azuread = {
      source = "hashicorp/azuread"
    }
  }
}

variable "deployer_vm_count" {
  type    = number
  default = 1
}

variable "bastion_deployment" {
  type    = bool
  default = false
}

variable "firewall_deployment" {
  type    = bool
  default = false
}

variable "enable_deployer_public_ip" {
  type    = bool
  default = false
}

variable "use_private_endpoint" {
  type    = bool
  default = false
}

variable "use_service_endpoint" {
  type    = bool
  default = false
}

variable "place_delete_lock" {
  type    = bool
  default = false
}

variable "use_spn" {
  type    = bool
  default = false
}

variable "assign_subscription_permissions" {
  type    = bool
  default = false
}

variable "nsg_deploy" {
  type    = bool
  default = true
}

variable "app_service_deployment" {
  type    = bool
  default = false
}

variable "enable_firewall_for_keyvaults_and_storage" {
  type    = bool
  default = false
}

variable "public_network_access_enabled" {
  type    = bool
  default = true
}

variable "dev_center_deployment" {
  type    = bool
  default = false
}

variable "network_security_perimeter_deploy" {
  type    = bool
  default = false
}

variable "app_config_deploy" {
  type    = bool
  default = false
}

variable "use_existing_rg" {
  type    = bool
  default = false
}

variable "use_existing_vnet" {
  type    = bool
  default = false
}

variable "use_existing_subnet" {
  type    = bool
  default = false
}

variable "use_existing_nsg" {
  type    = bool
  default = false
}

variable "use_existing_kv" {
  type    = bool
  default = false
}

module "deployer" {
  source = "../../../terraform-units/modules/sap_deployer"

  providers = {
    azurerm.main                     = azurerm
    azurerm.dnsmanagement            = azurerm
    azurerm.privatelinkdnsmanagement = azurerm
    azapi.restapi                    = azapi
    azuread.main                     = azuread
  }

  infrastructure = {
    environment = "DEV"
    region      = "eastus"
    codename    = ""
    resource_group = {
      name   = ""
      id     = var.use_existing_rg ? "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-deployer-rg" : ""
      exists = var.use_existing_rg
    }
    tags = {}
    virtual_network = {
      logical_name = "DEP"
      management = {
        name                    = "dep-vnet"
        id                      = var.use_existing_vnet ? "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-deployer-rg/providers/Microsoft.Network/virtualNetworks/existing-dep-vnet" : ""
        exists                  = var.use_existing_vnet
        address_space           = "10.0.0.0/24"
        flow_timeout_in_minutes = 4
        subnet_mgmt = {
          name   = ""
          exists = var.use_existing_subnet
          id     = var.use_existing_subnet ? "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-deployer-rg/providers/Microsoft.Network/virtualNetworks/existing-dep-vnet/subnets/existing-dep-subnet" : ""
          prefix = "10.0.0.0/25"
          nsg = {
            name        = ""
            exists      = var.use_existing_nsg
            id          = var.use_existing_nsg ? "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-deployer-rg/providers/Microsoft.Network/networkSecurityGroups/existing-dep-nsg" : ""
            allowed_ips = []
          }
        }
        subnet_firewall = {
          id     = ""
          exists = false
          prefix = "10.0.0.128/26"
        }
        subnet_bastion = {
          id     = ""
          exists = false
          prefix = "10.0.0.192/27"
        }
        subnet_webapp = {
          id     = ""
          exists = false
          prefix = "10.0.0.224/28"
        }
        subnet_agent = {
          name   = ""
          id     = ""
          exists = false
          prefix = "10.0.0.240/28"
        }
      }
    }
    deploy_monitoring_extension = false
    deploy_defender_extension   = false
    custom_random_id            = ""
    bastion_public_ip_tags      = {}
    dev_center_deployment       = var.dev_center_deployment
    devops = {
      agent_ado_url                  = ""
      agent_ado_project              = ""
      agent_pat                      = ""
      agent_pool                     = ""
      ansible_core_version           = ""
      tf_version                     = ""
      DevOpsInfrastructure_object_id = ""
      app_token                      = ""
      repository                     = ""
      server_url                     = ""
      api_url                        = ""
      platform                       = ""
      organization                   = ""
      branch                         = ""
    }
    tfstate_resource_id          = ""
    tfstate_storage_account_name = "testdeployertfstate"
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
      deployer_web-subnet       = ""
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
      storage_private_svc_diag  = ""
      storage_private_svc_tf    = ""
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
      deployer_web-subnet       = "_deployment-web-subnet"
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
      storage_private_link_diag = "-diag-storage-private-endpoint"
      storage_private_link_tf   = "-tf-storage-private-endpoint"
      storage_private_svc_diag  = "-diag-storage-private-service"
      storage_private_svc_tf    = "-tf-storage-private-service"
      storage_subnet            = "storage-subnet"
      tfstate                   = "tfstate"
      vm                        = ""
      vmss                      = "-vmss"
      vnet                      = "-vnet"
      vnet_rg                   = "-INFRASTRUCTURE"
      webapp_url                = "-sapdeployment"
    }
    storageaccount_names = {
      DEPLOYER = "deveausdepdiagabc"
    }
    virtualmachine_names = {
      DEPLOYER = ["deveausdep00"]
    }
    keyvault_names = {
      DEPLOYER = {
        private_access = "DEVEAUSDEPprvtABC"
        user_access    = "DEVEAUSDEPuserABC"
      }
    }
  }

  naming_new = {
    app_ppg_names                   = ["-app-ppg"]
    appconfig_name                  = "deveausapcabc"
    location_short                  = "EAUS"
    network_security_perimeter_name = "DEV-EAUS_NETWORK_SECURITY_PERIMETER"
  }

  authentication = {
    username            = "azureadm"
    password            = ""
    path_to_public_key  = ""
    path_to_private_key = ""
  }

  deployer = {
    size                         = "Standard_D4ds_v4"
    disk_type                    = "Premium_LRS"
    use_DHCP                     = true
    authentication               = { type = "key" }
    add_system_assigned_identity = false
    os = {
      os_type         = "LINUX"
      type            = "marketplace"
      source_image_id = ""
      publisher       = "Canonical"
      offer           = "0001-com-ubuntu-server-jammy"
      sku             = "22_04-lts-gen2"
      version         = "latest"
    }
    private_ip_address                  = ""
    deployer_diagnostics_account_arm_id = ""
    app_service_SKU                     = "P1v3"
    user_assigned_identity_id           = ""
    shared_access_key_enabled           = true
    devops_authentication_type          = "pat"
    encryption_at_host_enabled          = false
    deployer_public_ip_tags             = {}
    license_type                        = ""
  }

  key_vault = {
    id                        = var.use_existing_kv ? "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-deployer-rg/providers/Microsoft.KeyVault/vaults/existingkvuser" : ""
    exists                    = var.use_existing_kv
    private_key_secret_name   = ""
    public_key_secret_name    = ""
    username_secret_name      = ""
    password_secret_name      = ""
    enable_rbac_authorization = false
  }

  options = {
    enable_deployer_public_ip       = var.enable_deployer_public_ip
    use_spn                         = var.use_spn
    assign_resource_permissions     = false
    assign_subscription_permissions = var.assign_subscription_permissions
    network_security_perimeter = {
      name                         = "DEV-EAUS_NETWORK_SECURITY_PERIMETER"
      id                           = ""
      exists                       = false
      deploy                       = var.network_security_perimeter_deploy
      network_security_access_mode = "enforced"
    }
  }

  firewall = {
    deployment          = var.firewall_deployment
    rule_subnets        = []
    allowed_ipaddresses = []
    ip_tags             = {}
  }

  dns_settings = {
    use_custom_dns_a_registration                = false
    register_storage_accounts_keyvaults_with_dns = false
    register_endpoints_with_dns                  = false
    dns_zone_names                               = {}
    local_dns_resourcegroup_name                 = "deployer-rg"
    management_dns_resourcegroup_name            = ""
    management_dns_subscription_id               = ""
    privatelink_dns_subscription_id              = ""
    privatelink_dns_resourcegroup_name           = ""
  }

  bastion_deployment                           = var.bastion_deployment
  bastion_sku                                  = "Basic"
  bootstrap                                    = false
  configure                                    = false
  deployer_vm_count                            = var.deployer_vm_count
  use_private_endpoint                         = var.use_private_endpoint
  use_service_endpoint                         = var.use_service_endpoint
  place_delete_lock_on_resources               = var.place_delete_lock
  ssh-timeout                                  = "30s"
  network_logical_name                         = "DEP"
  additional_users_to_add_to_keyvault_policies = []
  enable_purge_control_for_keyvaults           = false
  enable_firewall_for_keyvaults_and_storage    = var.enable_firewall_for_keyvaults_and_storage
  public_network_access_enabled                = var.public_network_access_enabled
  set_secret_expiry                            = false
  soft_delete_retention_days                   = 7
  sa_connection_string                         = ""
  webapp_client_secret                         = ""
  subnets_to_add                               = []
  assign_subscription_permissions              = var.assign_subscription_permissions
  arm_client_id                                = ""
  spn_id                                       = ""
  Agent_IP                                     = ""
  additional_network_id                        = ""

  auto_configure_deployer = false

  app_service = {
    use                          = var.app_service_deployment
    app_registration_id          = ""
    client_secret                = ""
    tfstate_storage_account_name = "testdeployertfstate"
  }

  app_config_service = {
    name               = "deveausapcabc"
    id                 = ""
    exists             = false
    deploy             = var.app_config_deploy
    control_plane_name = "DEV-EAUS-DEP"
  }

  platform = "devops"
}

###############################################################################
# Outputs - expose module values for test assertions
###############################################################################

output "resource_group_name" {
  value = module.deployer.created_resource_group_name
}

output "resource_group_location" {
  value = module.deployer.created_resource_group_location
}

output "vnet_mgmt_id" {
  value = module.deployer.vnet_mgmt_id
}

output "subnet_mgmt_id" {
  value = module.deployer.subnet_mgmt_id
}

output "subnet_mgmt_address_prefixes" {
  value = module.deployer.subnet_mgmt_address_prefixes
}

output "nsg_mgmt" {
  value = module.deployer.nsg_mgmt
}

output "user_vault_name" {
  value = module.deployer.user_vault_name
}

output "deployer_id" {
  value = module.deployer.deployer_id
}

output "deployer_public_ip_address" {
  value = module.deployer.deployer_public_ip_address
}

output "deployer_private_ip_address" {
  value = module.deployer.deployer_private_ip_address
}

output "firewall_ip" {
  value = module.deployer.firewall_ip
}

output "firewall_id" {
  value = module.deployer.firewall_id
}

output "webapp_url_base" {
  value = module.deployer.webapp_url_base
}

output "random_id" {
  value = module.deployer.random_id
}

output "ppk_secret_name" {
  value = module.deployer.ppk_secret_name
}

output "pk_secret_name" {
  value = module.deployer.pk_secret_name
}

output "username_secret_name" {
  value = module.deployer.username_secret_name
}

output "pwd_secret_name" {
  value = module.deployer.pwd_secret_name
}

output "subnet_bastion_address_prefixes" {
  value = module.deployer.subnet_bastion_address_prefixes
}

output "deployer_keyvault_user_arm_id" {
  value = module.deployer.deployer_keyvault_user_arm_id
}

output "extension_ids" {
  value = module.deployer.extension_ids
}

output "webapp_identity" {
  value = module.deployer.webapp_identity
}

output "webapp_id" {
  value = module.deployer.webapp_id
}

output "diagnostics_account_id" {
  value = module.deployer.diagnostics_account_id
}
