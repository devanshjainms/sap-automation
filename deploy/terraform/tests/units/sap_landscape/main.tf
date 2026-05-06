# Test harness for sap_landscape terraform-units module
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
  }
}

variable "use_ANF" {
  type    = bool
  default = false
}

variable "iscsi_count" {
  type    = number
  default = 0
}

variable "use_private_endpoint" {
  type    = bool
  default = false
}

variable "use_service_endpoint" {
  type    = bool
  default = false
}

variable "peer_with_control_plane_vnet" {
  type    = bool
  default = false
}

variable "place_delete_lock_on_resources" {
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

variable "create_transport_storage" {
  type    = bool
  default = true
}

variable "use_AFS_for_shared_storage" {
  type    = bool
  default = false
}

###############################################################################
# Brownfield control variables — ARM IDs for pre-existing infrastructure      #
###############################################################################

variable "brownfield_rg_arm_id" {
  type    = string
  default = ""
}

variable "brownfield_vnet_arm_id" {
  type    = string
  default = ""
}

variable "brownfield_subnet_admin_arm_id" {
  type    = string
  default = ""
}

variable "brownfield_subnet_db_arm_id" {
  type    = string
  default = ""
}

variable "brownfield_subnet_app_arm_id" {
  type    = string
  default = ""
}

variable "brownfield_subnet_web_arm_id" {
  type    = string
  default = ""
}

variable "brownfield_nsg_admin_arm_id" {
  type    = string
  default = ""
}

variable "brownfield_nsg_db_arm_id" {
  type    = string
  default = ""
}

variable "brownfield_nsg_app_arm_id" {
  type    = string
  default = ""
}

variable "brownfield_nsg_web_arm_id" {
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

variable "test_vnet_logical_name" {
  type    = string
  default = "SAP"
  validation {
    condition     = length(trimspace(var.test_vnet_logical_name)) > 0
    error_message = "VNet logical name must not be empty."
  }
}

variable "test_flow_timeout" {
  type    = number
  default = 4
  validation {
    condition     = var.test_flow_timeout == null ? true : (var.test_flow_timeout >= 4 && var.test_flow_timeout <= 30)
    error_message = "Flow timeout must be between 4 and 30 minutes."
  }
}

variable "test_username" {
  type    = string
  default = "azureadm"
  validation {
    condition     = length(trimspace(var.test_username)) > 0
    error_message = "Authentication username must not be empty."
  }
}

locals {
  infrastructure = {
    environment                    = var.test_environment
    region                         = var.test_region
    codename                       = ""
    tags                           = {}
    shared_access_key_enabled      = true
    shared_access_key_enabled_nfs  = true
    user_assigned_identity_id      = ""
    additional_network_id          = ""
    additional_subnet_id           = ""
    encryption_at_host_enabled     = false
    patch_mode                     = "ImageDefault"
    patch_assessment_mode          = "ImageDefault"
    platform_updates               = false
    deploy_monitoring_extension    = false
    deploy_defender_extension      = false
    use_application_configuration  = false
    application_configuration_id   = ""
    workload_zone_name             = "DEV-EAUS-SAP00"
    control_plane_name             = "DEV-EAUS-DEP00"
    terraform_storage_account_name = "deveausaptfstate"

    resource_group = {
      name = ""
      id   = var.brownfield_rg_arm_id
    }

    virtual_networks = {
      sap = {
        logical_name             = var.test_vnet_logical_name
        name                     = "sap-vnet"
        id                       = var.brownfield_vnet_arm_id
        exists                   = length(var.brownfield_vnet_arm_id) > 0
        address_space            = ["10.1.0.0/16"]
        flow_timeout_in_minutes  = var.test_flow_timeout
        enable_route_propagation = false

        subnet_admin = {
          name    = ""
          id      = var.brownfield_subnet_admin_arm_id
          prefix  = length(var.brownfield_subnet_admin_arm_id) > 0 ? "" : "10.1.1.0/24"
          defined = length(var.brownfield_subnet_admin_arm_id) > 0 ? false : true
          exists  = length(var.brownfield_subnet_admin_arm_id) > 0
          nsg = {
            name   = ""
            id     = var.brownfield_nsg_admin_arm_id
            exists = length(var.brownfield_nsg_admin_arm_id) > 0
          }
        }
        subnet_db = {
          name    = ""
          id      = var.brownfield_subnet_db_arm_id
          prefix  = length(var.brownfield_subnet_db_arm_id) > 0 ? "" : "10.1.2.0/24"
          defined = length(var.brownfield_subnet_db_arm_id) > 0 ? false : true
          exists  = length(var.brownfield_subnet_db_arm_id) > 0
          nsg = {
            name   = ""
            id     = var.brownfield_nsg_db_arm_id
            exists = length(var.brownfield_nsg_db_arm_id) > 0
          }
        }
        subnet_app = {
          name    = ""
          id      = var.brownfield_subnet_app_arm_id
          prefix  = length(var.brownfield_subnet_app_arm_id) > 0 ? "" : "10.1.3.0/24"
          defined = length(var.brownfield_subnet_app_arm_id) > 0 ? false : true
          exists  = length(var.brownfield_subnet_app_arm_id) > 0
          nsg = {
            name   = ""
            id     = var.brownfield_nsg_app_arm_id
            exists = length(var.brownfield_nsg_app_arm_id) > 0
          }
        }
        subnet_web = {
          name    = ""
          id      = var.brownfield_subnet_web_arm_id
          prefix  = length(var.brownfield_subnet_web_arm_id) > 0 ? "" : "10.1.4.0/24"
          defined = length(var.brownfield_subnet_web_arm_id) > 0 ? false : true
          exists  = length(var.brownfield_subnet_web_arm_id) > 0
          nsg = {
            name   = ""
            id     = var.brownfield_nsg_web_arm_id
            exists = length(var.brownfield_nsg_web_arm_id) > 0
          }
        }
        subnet_storage = {
          name    = ""
          id      = ""
          prefix  = ""
          defined = false
          exists  = false
          nsg = {
            name   = ""
            id     = ""
            exists = false
          }
        }
        subnet_anf = {
          name    = ""
          id      = ""
          prefix  = var.use_ANF ? "10.1.6.0/24" : ""
          defined = var.use_ANF
          exists  = false
          nsg = {
            name   = ""
            id     = ""
            exists = false
          }
        }
        subnet_iscsi = {
          name    = ""
          id      = ""
          prefix  = var.iscsi_count > 0 ? "10.1.7.0/24" : ""
          defined = var.iscsi_count > 0
          exists  = false
          nsg = {
            name   = ""
            id     = ""
            exists = false
          }
        }
        subnet_ams = {
          name    = ""
          id      = ""
          prefix  = ""
          defined = false
          exists  = false
          nsg = {
            name   = ""
            id     = ""
            exists = false
          }
        }
      }
    }

    ams_instance = {
      name                = ""
      create_ams_instance = false
      ams_laws_id         = ""
    }

    nat_gateway = {
      create_nat_gateway      = false
      name                    = ""
      id                      = ""
      region                  = "eastus"
      public_ip_zones         = ["1", "2", "3"]
      public_ip_id            = ""
      idle_timeout_in_minutes = 4
      ip_tags                 = {}
    }

    iscsi = {
      iscsi_count   = var.iscsi_count
      use_DHCP      = true
      iscsi_nic_ips = []
      size          = "Standard_D2s_v3"
      os = {
        source_image_id = ""
        publisher       = "SUSE"
        offer           = "sles-sap-15-sp5"
        sku             = "gen2"
        version         = "latest"
      }
      authentication = {
        type     = "key"
        username = "azureadm"
      }
      zones                     = []
      user_assigned_identity_id = ""
    }
  }
}

module "sap_landscape" {
  source = "../../../terraform-units/modules/sap_landscape"

  providers = {
    azurerm.main                     = azurerm
    azurerm.deployer                 = azurerm
    azurerm.dnsmanagement            = azurerm
    azurerm.privatelinkdnsmanagement = azurerm
    azurerm.peering                  = azurerm
    azapi.api                        = azapi
  }

  infrastructure = local.infrastructure

  options = {
    enable_secure_transfer = true
    use_spn                = false
    assign_permissions     = false
    spn_id                 = "00000000-0000-0000-0000-000000000004"
  }

  authentication = {
    username            = var.test_username
    password            = "TestP@ssw0rd123!"
    path_to_public_key  = ""
    path_to_private_key = ""
  }

  key_vault = {
    user = {
      id     = ""
      exists = false
    }
    spn = {
      id     = ""
      exists = false
    }
    private_key_secret_name    = ""
    public_key_secret_name     = ""
    username_secret_name       = ""
    password_secret_name       = ""
    enable_rbac_authorization  = false
    set_secret_expiry          = false
    exists                     = false
    enable_purge_control       = false
    soft_delete_retention_days = 7
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
      admin_nic                      = ""
      admin_subnet                   = ""
      admin_subnet_nsg               = ""
      agent_subnet                   = ""
      ams_subnet                     = ""
      anf_subnet                     = ""
      anf_subnet_nsg                 = ""
      ansible                        = ""
      app_alb                        = ""
      app_asg                        = ""
      app_avset                      = ""
      app_service_plan               = ""
      app_subnet                     = ""
      app_subnet_nsg                 = ""
      bastion_host                   = ""
      bastion_pip                    = ""
      db_alb                         = ""
      db_subnet                      = ""
      db_subnet_nsg                  = ""
      deployer_rg                    = ""
      deployer_state                 = ""
      deployer_subnet                = ""
      deployer_subnet_nsg            = ""
      disk                           = ""
      dns_link                       = ""
      firewall                       = ""
      firewall_rule_app              = ""
      firewall_rule_db               = ""
      fw_route                       = ""
      install_volume                 = ""
      iscsi_subnet                   = ""
      iscsi_subnet_nsg               = ""
      keyvault_private_link          = ""
      keyvault_private_svc           = ""
      kv                             = ""
      library_rg                     = ""
      msi                            = ""
      nat_gateway                    = ""
      netapp_account                 = ""
      netapp_pool                    = ""
      nic                            = ""
      osdisk                         = ""
      pip                            = ""
      ppg                            = ""
      routetable                     = ""
      storage_private_link_diag      = ""
      storage_private_link_install   = ""
      storage_private_link_tf        = ""
      storage_private_link_transport = ""
      storage_private_link_witness   = ""
      storage_private_svc_diag       = ""
      storage_private_svc_install    = ""
      storage_private_svc_tf         = ""
      storage_private_svc_transport  = ""
      storage_private_svc_witness    = ""
      storage_subnet                 = ""
      storage_subnet_nsg             = ""
      tfstate                        = ""
      transport_volume               = ""
      vm                             = ""
      vmss                           = ""
      vnet                           = ""
      vnet_rg                        = ""
      web_subnet                     = ""
      web_subnet_nsg                 = ""
    }
    resource_suffixes = {
      admin_nic                      = "-admin-nic"
      admin_subnet                   = "admin-subnet"
      admin_subnet_nsg               = "adminSubnet-nsg"
      agent_subnet                   = "_agent-subnet"
      ams_instance                   = "-ams"
      ams_subnet                     = "ams-subnet"
      anf_subnet                     = "anf-subnet"
      anf_subnet_nsg                 = "anfSubnet-nsg"
      ansible                        = "ansible"
      app_alb                        = "app-alb"
      app_asg                        = "app-asg"
      app_avset                      = "app-avset"
      app_service_plan               = "-app-service-plan"
      app_subnet                     = "app-subnet"
      app_subnet_nsg                 = "appSubnet-nsg"
      bastion_host                   = "bastion-host"
      bastion_pip                    = "bastion-pip"
      db_alb                         = "db-alb"
      db_subnet                      = "db-subnet"
      db_subnet_nsg                  = "dbSubnet-nsg"
      deployer_rg                    = "-INFRASTRUCTURE"
      deployer_state                 = "_DEPLOYER.terraform.tfstate"
      deployer_subnet                = "_deployment-subnet"
      deployer_subnet_nsg            = "_deployment-nsg"
      disk                           = ""
      dns_link                       = "dns-link"
      firewall                       = "firewall"
      firewall_rule_app              = "firewall-rule-app"
      firewall_rule_db               = "firewall-rule-db"
      fw_route                       = "firewall-route"
      install_volume                 = "-install"
      iscsi_subnet                   = "iscsi-subnet"
      iscsi_subnet_nsg               = "iscsiSubnet-nsg"
      keyvault_private_link          = "-keyvault-private-endpoint"
      keyvault_private_svc           = "-keyvault-private-service"
      kv                             = ""
      library_rg                     = "-SAP_LIBRARY"
      msi                            = "-msi"
      nat_gateway                    = "-nat-gateway"
      nat_gateway_pip                = "-nat-gateway-pip"
      nic                            = "-nic"
      osdisk                         = "-OsDisk"
      pip                            = "-pip"
      ppg                            = "-ppg"
      routetable                     = "route-table"
      storage_private_link_diag      = "-diag-storage-private-endpoint"
      storage_private_link_install   = "-install-storage-private-endpoint"
      storage_private_link_tf        = "-tf-storage-private-endpoint"
      storage_private_link_transport = "-transport-storage-private-endpoint"
      storage_private_link_witness   = "-witness-storage-private-endpoint"
      storage_private_svc_diag       = "-diag-storage-private-service"
      storage_private_svc_install    = "-install-storage-private-service"
      storage_private_svc_tf         = "-tf-storage-private-service"
      storage_private_svc_transport  = "-transport-storage-private-service"
      storage_private_svc_witness    = "-witness-storage-private-service"
      storage_subnet                 = "storage-subnet"
      storage_subnet_nsg             = "storageSubnet-nsg"
      tfstate                        = "tfstate"
      transport_volume               = "-transport"
      vm                             = ""
      vmss                           = "-vmss"
      vnet                           = "-vnet"
      vnet_rg                        = "-INFRASTRUCTURE"
      web_subnet                     = "web-subnet"
      web_subnet_nsg                 = "webSubnet-nsg"
      witness                        = "witness"
      witness_accesskey              = "-witness-accesskey"
      netapp_account                 = "-netapp-account"
      netapp_pool                    = "-netapp-pool"
      install_volume_smb             = "-install-smb"
    }
    keyvault_names = {
      WORKLOAD_ZONE = {
        private_access = "DEVEAUSSAPprvtABC"
        user_access    = "DEVEAUSSAPuserABC"
      }
      SDU = {
        private_access = "DEVEAUSSAPprvtABC"
        user_access    = "DEVEAUSSAPuserABC"
      }
    }
    storageaccount_names = {
      WORKLOAD_ZONE = {
        landscape_shared_install_storage_account_name   = "deveaussapinstabc"
        landscape_shared_transport_storage_account_name = "deveaussaptransabc"
        landscape_storageaccount_name                   = "deveaussapdiagabc"
        witness_storageaccount_name                     = "deveaussapwitabc"
      }
    }
    virtualmachine_names = {
      ISCSI_COMPUTERNAME = ["deveaussapiscsi00"]
    }
  }

  deployer_tfstate = {
    deployer_kv_user_name           = ""
    deployer_kv_user_arm_id         = ""
    subnet_mgmt_address_prefixes    = []
    subnet_bastion_address_prefixes = []
    network_security_access_mode    = "enforced"
    deployer_uai = {
      principal_id = ""
      tenant_id    = ""
    }
  }
  use_deployer                              = false
  peer_with_control_plane_vnet              = var.peer_with_control_plane_vnet
  use_private_endpoint                      = var.use_private_endpoint
  use_service_endpoint                      = var.use_service_endpoint
  place_delete_lock_on_resources            = var.place_delete_lock_on_resources
  enable_firewall_for_keyvaults_and_storage = var.enable_firewall_for_keyvaults_and_storage
  public_network_access_enabled             = var.public_network_access_enabled
  create_transport_storage                  = var.create_transport_storage
  use_AFS_for_shared_storage                = var.use_AFS_for_shared_storage
  AFS_enable_encryption_in_transit          = false

  NFS_provider = var.use_ANF ? "ANF" : "NONE"
  ANF_settings = {
    use                              = var.use_ANF
    name                             = ""
    arm_id                           = ""
    id                               = ""
    pool_name                        = ""
    use_existing_pool                = false
    service_level                    = "Standard"
    size_in_tb                       = 4
    qos_type                         = "Manual"
    use_existing_transport_volume    = false
    transport_volume_name            = ""
    transport_volume_size            = 50
    transport_volume_throughput      = 32
    transport_volume_zone            = ""
    use_existing_install_volume      = false
    install_volume_name              = ""
    install_volume_size              = 128
    install_volume_throughput        = 32
    install_volume_zone              = ""
    export_policy_client_access_list = []
  }

  diagnostics_storage_account = { arm_id = "", id = "" }
  witness_storage_account     = { arm_id = "", id = "" }

  transport_volume_size            = 128
  install_volume_size              = 256
  transport_storage_account_id     = ""
  transport_private_endpoint_id    = ""
  install_storage_account_id       = ""
  install_private_endpoint_id      = ""
  install_always_create_fileshares = false

  additional_users_to_add_to_keyvault_policies = []
  keyvault_private_endpoint_id                 = ""

  dns_settings = {
    use_custom_dns_a_registration                = false
    dns_label                                    = ""
    dns_zone_names                               = {}
    dns_server_list                              = []
    management_dns_resourcegroup_name            = "deployer-rg"
    management_dns_subscription_id               = "00000000-0000-0000-0000-000000000003"
    privatelink_dns_resourcegroup_name           = "deployer-rg"
    privatelink_dns_subscription_id              = "00000000-0000-0000-0000-000000000003"
    register_storage_accounts_keyvaults_with_dns = false
    register_endpoints_with_dns                  = false
    register_virtual_network_to_dns              = false
  }

  vm_settings = {
    count    = 0
    size     = "Standard_D2s_v3"
    use_DHCP = true
    image = {
      os_type         = "LINUX"
      source_image_id = ""
      publisher       = "Canonical"
      offer           = "0001-com-ubuntu-server-jammy"
      sku             = "22_04-lts-gen2"
      version         = "latest"
      type            = "marketplace"
    }
    private_ip_address = []
    disk_size          = 128
    disk_type          = "Premium_LRS"
  }

  tags                             = {}
  terraform_template_version       = "test"
  storage_account_replication_type = "ZRS"
  Agent_IP                         = ""
  additional_network_id            = ""
}

###############################################################################
# Outputs — expose module values for test assertions                          #
###############################################################################

# Section 1: Resource Group and VNet
output "resource_group_name" {
  value = module.sap_landscape.created_resource_group_name
}

output "vnet_sap_id" {
  value = module.sap_landscape.vnet_sap_id
}

output "workload_zone_prefix" {
  value = module.sap_landscape.workload_zone_prefix
}

output "route_table_id" {
  value = module.sap_landscape.route_table_id
}

output "random_id" {
  value = module.sap_landscape.random_id
}

# Section 2: Subnets
output "admin_subnet_id" {
  value = module.sap_landscape.admin_subnet_id
}

output "db_subnet_id" {
  value = module.sap_landscape.db_subnet_id
}

output "app_subnet_id" {
  value = module.sap_landscape.app_subnet_id
}

output "web_subnet_id" {
  value = module.sap_landscape.web_subnet_id
}

output "storage_subnet_id" {
  value = module.sap_landscape.storage_subnet_id
}

output "anf_subnet_id" {
  value = module.sap_landscape.anf_subnet_id
}

output "ams_subnet_id" {
  value = module.sap_landscape.ams_subnet_id
}

# Section 3: NSGs
output "admin_nsg_id" {
  value = module.sap_landscape.admin_nsg_id
}

output "db_nsg_id" {
  value = module.sap_landscape.db_nsg_id
}

output "app_nsg_id" {
  value = module.sap_landscape.app_nsg_id
}

output "web_nsg_id" {
  value = module.sap_landscape.web_nsg_id
}

output "storage_nsg_id" {
  value = module.sap_landscape.storage_nsg_id
}

# Section 4: Key Vault
output "sid_public_key_secret_name" {
  value = module.sap_landscape.sid_public_key_secret_name
}

output "sid_private_key_secret_name" {
  value = module.sap_landscape.sid_private_key_secret_name
}

output "sid_username_secret_name" {
  value = module.sap_landscape.sid_username_secret_name
}

output "sid_password_secret_name" {
  value = module.sap_landscape.sid_password_secret_name
}

# Section 5: Storage accounts
output "storageaccount_name" {
  value = module.sap_landscape.storageaccount_name
}

output "witness_storage_account" {
  value = module.sap_landscape.witness_storage_account
}

output "transport_storage_account_id" {
  value = module.sap_landscape.transport_storage_account_id
}

# Section 6: ANF
output "ANF_pool_settings" {
  value = module.sap_landscape.ANF_pool_settings
}

# Section 7: iSCSI
output "iscsi_authentication_type" {
  value = module.sap_landscape.iscsi_authentication_type
}

output "iscsi_authentication_username" {
  value = module.sap_landscape.iscsi_authentication_username
}

output "iSCSI_server_names" {
  value = module.sap_landscape.iSCSI_server_names
}

output "iSCSI_server_ips" {
  value = module.sap_landscape.iSCSI_server_ips
}

output "nics_iscsi" {
  value = module.sap_landscape.nics_iscsi
}

# Section 8: DNS
output "privatelink_file_id" {
  value = module.sap_landscape.privatelink_file_id
}

output "privatelink_storage_id" {
  value = module.sap_landscape.privatelink_storage_id
}

output "privatelink_keyvault_id" {
  value = module.sap_landscape.privatelink_keyvault_id
}

# Section 9: AMS and NAT Gateway
output "ams_resource_id" {
  value = module.sap_landscape.ams_resource_id
}

output "ng_resource_id" {
  value = module.sap_landscape.ng_resource_id
}
