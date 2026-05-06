# Test harness for sap_system/app_tier terraform-units module
# Constructs minimal valid input objects and invokes the module with mock providers.
# This allows testing conditional resource creation logic without real Azure access.

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    tls = {
      source = "hashicorp/tls"
    }
  }
}

resource "tls_private_key" "test" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

#########################################################################################
#  Test toggle variables — each controls a feature flag tested independently            #
#########################################################################################

variable "enable_deployment" {
  type    = bool
  default = true
}

variable "scs_high_availability" {
  type    = bool
  default = false
}

variable "application_server_count" {
  type    = number
  default = 1
}

variable "scs_server_count" {
  type    = number
  default = 1
}

variable "webdispatcher_count" {
  type    = number
  default = 0
}

variable "deploy_application_security_groups" {
  type    = bool
  default = true
}

variable "use_secondary_ips" {
  type    = bool
  default = false
}

variable "use_scalesets_for_deployment" {
  type    = bool
  default = false
}

variable "NFS_provider" {
  type    = string
  default = "NFS"
}

variable "dual_network_interfaces" {
  type    = bool
  default = false
}

variable "nsg_asg_with_vnet" {
  type    = bool
  default = false
}

variable "web_use_ppg" {
  type    = bool
  default = false
}

variable "app_use_avset" {
  type    = bool
  default = false
}

variable "scs_use_avset" {
  type    = bool
  default = false
}

variable "web_use_avset" {
  type    = bool
  default = false
}

#########################################################################################
#  Module instantiation                                                                 #
#########################################################################################

module "app_tier" {
  source = "../../../../terraform-units/modules/sap_system/app_tier"

  providers = {
    azurerm.main                     = azurerm
    azurerm.deployer                 = azurerm
    azurerm.dnsmanagement            = azurerm
    azurerm.privatelinkdnsmanagement = azurerm
  }

  admin_subnet = {
    is_existing = true
    id          = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-admin-subnet"
    name        = "test-admin-subnet"
    prefix      = "10.1.4.0/24"
  }

  application_tier = {
    sid                            = "HN1"
    enable_deployment              = var.enable_deployment
    use_DHCP                       = true
    dual_network_interfaces        = var.dual_network_interfaces
    vm_sizing_dictionary_key       = "Optimized"
    app_instance_number            = "00"
    application_server_count       = var.application_server_count
    app_sku                        = "Standard_D4ds_v5"
    app_use_ppg                    = true
    app_use_avset                  = var.app_use_avset
    app_zone_count                 = 0
    app_zones                      = []
    scs_server_count               = var.scs_server_count
    scs_high_availability          = var.scs_high_availability
    scs_cluster_type               = "AFA"
    scs_instance_number            = "00"
    ers_instance_number            = "02"
    scs_sku                        = "Standard_D4ds_v5"
    scs_use_ppg                    = true
    scs_use_avset                  = var.scs_use_avset
    scs_zone_count                 = 0
    scs_zones                      = []
    scs_cluster_disk_lun           = 0
    scs_cluster_disk_size          = 128
    scs_cluster_disk_type          = "Premium_LRS"
    webdispatcher_count            = var.webdispatcher_count
    web_instance_number            = "00"
    web_sid                        = "WEB"
    web_sku                        = ""
    web_use_ppg                    = var.web_use_ppg
    web_use_avset                  = var.web_use_avset
    web_zone_count                 = 0
    web_zones                      = []
    deploy_v1_monitoring_extension = false
    avset_arm_ids                  = []
    avset_arm_ids_count            = 0
    user_assigned_identity_id      = ""
    disk_controller_type_app_tier  = "SCSI"
    app_os = {
      os_type         = "LINUX"
      source_image_id = ""
      publisher       = "SUSE"
      offer           = "sles-sap-15-sp5"
      sku             = "gen1"
      version         = "latest"
      type            = "marketplace"
    }
    scs_os = {
      os_type         = "LINUX"
      source_image_id = ""
      publisher       = "SUSE"
      offer           = "sles-sap-15-sp5"
      sku             = "gen1"
      version         = "latest"
      type            = "marketplace"
    }
    web_os = {
      os_type         = "LINUX"
      source_image_id = ""
      publisher       = "SUSE"
      offer           = "sles-sap-15-sp5"
      sku             = "gen1"
      version         = "latest"
      type            = "marketplace"
    }
    authentication = {
      type = "key"
    }
    app_tags               = {}
    scs_tags               = {}
    web_tags               = {}
    tags                   = {}
    use_AFS_for_sapmnt     = false
    fence_kdump_disk_size  = 0
    fence_kdump_lun_number = -1
  }

  cloudinit_growpart_config = null

  custom_disk_sizes_filename = ""

  deploy_application_security_groups = var.deploy_application_security_groups

  deployment = "new"

  fencing_role_name = ""

  firewall_id = ""

  idle_timeout_scs_ers = 4

  infrastructure = {
    environment = "DEV"
    region      = "eastus"
    codename    = ""
    resource_group = {
      name   = ""
      id     = ""
      exists = false
    }
    tags = {}
    virtual_networks = {
      sap = {
        name                 = "sap-vnet"
        id                   = ""
        exists               = false
        address_space        = "10.1.0.0/16"
        network_logical_name = "sap"
        logical_name         = "sap"
        subnet_db = {
          name               = ""
          exists             = false
          id                 = ""
          prefix             = "10.1.1.0/24"
          defined            = false
          exists_in_workload = true
          id_in_workload     = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-db-subnet"
          nsg = {
            name               = ""
            exists             = false
            id                 = ""
            exists_in_workload = true
            id_in_workload     = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/networkSecurityGroups/test-db-nsg"
          }
        }
        subnet_app = {
          name               = ""
          exists             = false
          id                 = ""
          prefix             = "10.1.2.0/24"
          defined            = false
          exists_in_workload = true
          id_in_workload     = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-app-subnet"
          nsg = {
            name               = ""
            exists             = false
            id                 = ""
            exists_in_workload = true
            id_in_workload     = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/networkSecurityGroups/test-app-nsg"
          }
        }
        subnet_web = {
          name               = ""
          exists             = false
          id                 = ""
          prefix             = "10.1.3.0/24"
          defined            = false
          exists_in_workload = true
          id_in_workload     = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-web-subnet"
          nsg = {
            name               = ""
            exists             = false
            id                 = ""
            exists_in_workload = true
            id_in_workload     = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/networkSecurityGroups/test-web-nsg"
          }
        }
        subnet_admin = {
          name               = ""
          exists             = false
          id                 = ""
          prefix             = "10.1.4.0/24"
          defined            = false
          exists_in_workload = true
          id_in_workload     = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-admin-subnet"
          nsg = {
            name               = ""
            exists             = false
            id                 = ""
            exists_in_workload = true
            id_in_workload     = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/networkSecurityGroups/test-admin-nsg"
          }
        }
        subnet_storage = {
          name               = ""
          exists             = false
          id                 = ""
          prefix             = "10.1.5.0/24"
          defined            = false
          exists_in_workload = true
          id_in_workload     = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-storage-subnet"
          nsg = {
            name               = ""
            exists             = false
            id                 = ""
            exists_in_workload = true
            id_in_workload     = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/networkSecurityGroups/test-storage-nsg"
          }
        }
        subnet_ams = {
          name   = ""
          exists = false
          id     = ""
          prefix = "10.1.6.0/24"
        }
        subnet_anf = {
          name   = ""
          exists = false
          id     = ""
          prefix = "10.1.7.0/24"
          nsg = {
            name               = ""
            exists             = false
            id                 = ""
            exists_in_workload = true
            id_in_workload     = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/networkSecurityGroups/test-anf-nsg"
          }
        }
      }
    }
    user_assigned_identity_id          = ""
    shared_access_key_enabled          = true
    shared_access_key_enabled_nfs      = true
    deploy_monitoring_extension        = false
    deploy_defender_extension          = false
    encryption_at_host_enabled         = false
    patch_mode                         = "AutomaticByPlatform"
    patch_assessment_mode              = "AutomaticByPlatform"
    platform_updates                   = false
    use_app_proximityplacementgroups   = false
    storage_account_replication_type   = "LRS"
    disk_controller_type_app_tier      = "SCSI"
    disk_controller_type_database_tier = "SCSI"
    application_configuration_id       = ""
    use_application_configuration      = false
    workload_zone_name                 = ""
  }

  landscape_tfstate = {
    route_table_id                  = ""
    admin_subnet_id                 = ""
    app_subnet_id                   = ""
    app_nsg_id                      = ""
    db_subnet_id                    = ""
    web_subnet_id                   = ""
    storage_subnet_id               = ""
    subnet_mgmt_id                  = ""
    vnet_sap_arm_id                 = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet"
    landscape_key_vault_user_arm_id = ""
    storageaccount_name             = "devsapdiag001"
    storageaccount_rg_name          = "DEV-EAUS-SAP-INFRASTRUCTURE"
    sid_password_secret_name        = ""
    sid_public_key_secret_name      = ""
    sid_username_secret_name        = ""
    ANF_pool_settings               = null
    use_separate_storage_subnet     = false
    public_network_access_enabled   = true
    privatelink_file_id             = ""
  }

  license_type = ""

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
      anf_subnet                     = ""
      anf_subnet_nsg                 = ""
      app_alb                        = ""
      app_asg                        = ""
      app_avset                      = ""
      app_subnet                     = ""
      app_subnet_nsg                 = ""
      db_alb                         = ""
      db_alb_bepool                  = ""
      db_alb_feip                    = ""
      db_alb_hp                      = ""
      db_alb_rule                    = ""
      db_asg                         = ""
      db_avset                       = ""
      db_clst_feip                   = ""
      db_nic                         = ""
      db_subnet                      = ""
      db_subnet_nsg                  = ""
      disk                           = ""
      fencing_agent_id               = ""
      fencing_agent_pwd              = ""
      fencing_agent_spn              = ""
      fencing_agent_sub              = ""
      fencing_agent_tenant           = ""
      hanadata                       = ""
      hanalog                        = ""
      hanashared                     = ""
      kv                             = ""
      msi                            = ""
      nic                            = ""
      osdisk                         = ""
      pip                            = ""
      ppg                            = ""
      scs_alb                        = ""
      scs_alb_bepool                 = ""
      scs_alb_feip                   = ""
      scs_alb_hp                     = ""
      scs_alb_rule                   = ""
      scs_avset                      = ""
      scs_clst_feip                  = ""
      scs_clst_hp                    = ""
      scs_clst_rule                  = ""
      scs_ers_feip                   = ""
      scs_ers_hp                     = ""
      scs_ers_rule                   = ""
      scs_fs_feip                    = ""
      scs_fs_hp                      = ""
      scs_fs_rule                    = ""
      scs_scs_rule                   = ""
      sdu_rg                         = ""
      sdu_secret                     = ""
      storage_nic                    = ""
      storage_subnet                 = ""
      storage_subnet_nsg             = ""
      vm                             = ""
      vmss                           = ""
      vnet                           = ""
      vnet_rg                        = ""
      web_alb                        = ""
      web_alb_bepool                 = ""
      web_alb_feip                   = ""
      web_alb_hp                     = ""
      web_alb_inrule                 = ""
      web_asg                        = ""
      web_avset                      = ""
      web_subnet                     = ""
      web_subnet_nsg                 = ""
      witness                        = ""
      witness_accesskey              = ""
      witness_name                   = ""
      database_cluster_disk          = ""
      scs_cluster_disk               = ""
      ers_alb_bepool                 = ""
      hana_avg                       = ""
      storage_private_link_diag      = ""
      storage_private_link_sapmnt    = ""
      storage_private_link_witness   = ""
      storage_private_svc_diag       = ""
      storage_private_svc_sapmnt     = ""
      storage_private_svc_witness    = ""
      keyvault_private_link          = ""
      keyvault_private_svc           = ""
      sapmnt                         = ""
      sapmnt_smb                     = ""
      install_volume                 = ""
      install_volume_smb             = ""
      transport_volume               = ""
      usrsap                         = ""
      storage_privatelink_hanashared = ""
      ams_subnet                     = ""
      dns_link                       = ""
    }
    resource_suffixes = {
      admin_nic                      = "-admin-nic"
      admin_subnet                   = "admin-subnet"
      admin_subnet_nsg               = "adminSubnet-nsg"
      anf_subnet                     = "anf-subnet"
      anf_subnet_nsg                 = "anfSubnet-nsg"
      app_alb                        = "app-alb"
      app_asg                        = "app-asg"
      app_avset                      = "app-avset"
      app_subnet                     = "app-subnet"
      app_subnet_nsg                 = "appSubnet-nsg"
      db_alb                         = "db-alb"
      db_alb_bepool                  = "dbAlb-bePool"
      db_alb_feip                    = "dbAlb-feip"
      db_alb_hp                      = "dbAlb-hp"
      db_alb_rule                    = "dbAlb-rule"
      db_asg                         = "db-asg"
      db_avset                       = "db-avset"
      db_clst_feip                   = "dbClst-feip"
      db_nic                         = "-db-nic"
      db_rlb_feip                    = "dbRlb-feip"
      db_rlb_hp                      = "dbRlb-hp"
      db_rlb_rule                    = "dbRlb-rule"
      db_subnet                      = "db-subnet"
      db_subnet_nsg                  = "dbSubnet-nsg"
      disk                           = ""
      fencing_agent_id               = "-fencing-spn-id"
      fencing_agent_pwd              = "-fencing-spn-pwd"
      fencing_agent_spn              = "fencing-agent"
      fencing_agent_sub              = "-fencing-spn-subscription"
      fencing_agent_tenant           = "-fencing-spn-tenant"
      hana_avg                       = "hana-avg"
      hanadata                       = "hanadata"
      hanalog                        = "hanalog"
      hanashared                     = "hanashared"
      kv                             = ""
      msi                            = "-msi"
      nic                            = "-nic"
      osdisk                         = "-OsDisk"
      pip                            = "-pip"
      ppg                            = "-ppg"
      scs_alb                        = "scs-alb"
      scs_alb_bepool                 = "scsAlb-bePool"
      scs_alb_feip                   = "scsAlb-feip"
      scs_alb_hp                     = "scsAlb-hp"
      scs_alb_rule                   = "scsAlb-rule"
      scs_avset                      = "scs-avset"
      scs_clst_feip                  = "scsClst-feip"
      scs_clst_hp                    = "scsClst-hp"
      scs_clst_rule                  = "scsClst-rule"
      scs_cluster_disk               = "scs-cluster-disk"
      scs_ers_feip                   = "scsErs-feip"
      scs_ers_hp                     = "scsErs-hp"
      scs_ers_rule                   = "scsErs-rule"
      scs_fs_feip                    = "scsFs-feip"
      scs_fs_hp                      = "scsFs-hp"
      scs_fs_rule                    = "scsFs-rule"
      scs_scs_rule                   = "scsScs-rule"
      sdu_rg                         = ""
      sdu_secret                     = ""
      storage_nic                    = "-storage-nic"
      storage_subnet                 = "storage-subnet"
      storage_subnet_nsg             = "storageSubnet-nsg"
      vm                             = ""
      vmss                           = "-vmss"
      vnet                           = "-vnet"
      vnet_rg                        = "-INFRASTRUCTURE"
      web_alb                        = "web-alb"
      web_alb_bepool                 = "webAlb-bePool"
      web_alb_feip                   = "webAlb-feip"
      web_alb_hp                     = "webAlb-hp"
      web_alb_inrule                 = "webAlb-inRule"
      web_asg                        = "web-asg"
      web_avset                      = "web-avset"
      web_subnet                     = "web-subnet"
      web_subnet_nsg                 = "webSubnet-nsg"
      witness                        = "-witness"
      witness_accesskey              = "-witness-accesskey"
      witness_name                   = "-witness-name"
      database_cluster_disk          = "db-cluster-disk"
      ers_alb_bepool                 = "ersAlb-bePool"
      sapmnt                         = "sapmnt"
      sapmnt_smb                     = "sapmnt-smb"
      install_volume                 = "install"
      install_volume_smb             = "install-smb"
      transport_volume               = "transport"
      usrsap                         = "usrsap"
      storage_private_link_diag      = "-diag-storage-private-endpoint"
      storage_private_link_sapmnt    = "-sapmnt-storage-private-endpoint"
      storage_private_link_witness   = "-witness-storage-private-endpoint"
      storage_private_svc_diag       = "-diag-storage-private-service"
      storage_private_svc_sapmnt     = "-sapmnt-storage-private-service"
      storage_private_svc_witness    = "-witness-storage-private-service"
      keyvault_private_link          = "-keyvault-private-endpoint"
      keyvault_private_svc           = "-keyvault-private-service"
      storage_privatelink_hanashared = "-hanashared-storage-private-endpoint"
      ams_subnet                     = "ams-subnet"
      dns_link                       = "dns-link"
    }
    storageaccount_names = {
      SDU = "deveaussapdiagabc"
    }
    virtualmachine_names = {
      ANCHOR_COMPUTERNAME   = []
      ANCHOR_VMNAME         = []
      APP_COMPUTERNAME      = ["hn1app00l000", "hn1app00l001", "hn1app00l002"]
      APP_VMNAME            = ["hn1app00l000", "hn1app00l001", "hn1app00l002"]
      APP_SECONDARY_DNSNAME = ["hn1app00l000", "hn1app00l001", "hn1app00l002"]
      SCS_COMPUTERNAME      = ["hn1scs00l000", "hn1scs00l001"]
      SCS_VMNAME            = ["hn1scs00l000", "hn1scs00l001"]
      SCS_SECONDARY_DNSNAME = ["hn1scs00l000", "hn1scs00l001"]
      WEB_COMPUTERNAME      = ["hn1web00l000", "hn1web00l001"]
      WEB_VMNAME            = ["hn1web00l000", "hn1web00l001"]
      WEB_SECONDARY_DNSNAME = ["hn1web00l000", "hn1web00l001"]
    }
    keyvault_names = {
      SDU = {
        private_access = "DEVEAUSSAPprvtABC"
        user_access    = "DEVEAUSSAPuserABC"
      }
    }
    ppg_names = ["-ppg"]
    availabilityset_names = {
      app = ["app-avset"]
      db  = ["db-avset"]
      scs = ["scs-avset"]
      web = ["web-avset"]
    }
  }

  network_location       = "eastus"
  network_resource_group = "test-rg"

  NFS_provider = var.NFS_provider

  options = {
    enable_secure_transfer                       = true
    use_spn                                      = false
    disk_encryption_set_id                       = null
    nsg_asg_with_vnet                            = var.nsg_asg_with_vnet
    legacy_nic_order                             = false
    resource_offset                              = 0
    use_loadbalancers_for_standalone_deployments = true
  }

  order_deployment = null

  ppg = ["/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Compute/proximityPlacementGroups/test-ppg"]

  resource_group = [
    {
      name     = "DEV-EAUS-SAP-HN1"
      location = "eastus"
      id       = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/DEV-EAUS-SAP-HN1"
    }
  ]

  route_table_id = ""

  sap_sid = "HN1"

  scale_set_id = ""

  sdu_public_key = tls_private_key.test.public_key_openssh

  sid_keyvault_user_id = ""

  sid_password = "Test1234!@#$"

  sid_username = "azureadm"

  storage_bootdiag_endpoint = "https://devsapdiag001.blob.core.windows.net/"

  tags = {}

  terraform_template_version = "1.0.0"

  use_admin_nic_for_asg = false

  use_loadbalancers_for_standalone_deployments = true

  use_msi_for_clusters = false

  use_scalesets_for_deployment = var.use_scalesets_for_deployment

  use_secondary_ips = var.use_secondary_ips

  dns_settings = {
    use_custom_dns_a_registration                = false
    register_storage_accounts_keyvaults_with_dns = false
    register_endpoints_with_dns                  = false
    register_virtual_network_to_dns              = false
    dns_zone_names                               = {}
    management_dns_resourcegroup_name            = ""
    management_dns_subscription_id               = ""
    privatelink_dns_subscription_id              = ""
    privatelink_dns_resourcegroup_name           = ""
  }
}

#########################################################################################
#  Outputs — expose key module outputs for assertions in test scenarios                 #
#########################################################################################

output "scs_server_loadbalancer_id" {
  value = module.app_tier.scs_server_loadbalancer_id
}

output "app_vm_ids" {
  value = module.app_tier.app_vm_ids
}

output "scs_vm_ids" {
  value = module.app_tier.scs_vm_ids
}

output "webdispatcher_server_vm_ids" {
  value = module.app_tier.webdispatcher_server_vm_ids
}

output "app_asg_id" {
  value = module.app_tier.app_asg_id
}

output "web_asg_id" {
  value = module.app_tier.web_asg_id
}

output "scs_high_availability" {
  value = module.app_tier.scs_high_availability
}

output "app_tier_os_types" {
  value = module.app_tier.app_tier_os_types
}

output "webdispatcher_loadbalancer_ip" {
  value = module.app_tier.webdispatcher_loadbalancer_ip
}

output "subnet_cidr_app" {
  value = module.app_tier.subnet_cidr_app
}
