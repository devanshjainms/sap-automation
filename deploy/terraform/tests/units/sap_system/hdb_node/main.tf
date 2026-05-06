# Test harness for sap_system/hdb_node terraform-units module
# Constructs minimal valid input objects and invokes the module with mock providers.
# This allows testing conditional resource creation logic without real Azure access.

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

#########################################################################################
#  Test toggle variables — each controls a feature flag tested independently            #
#########################################################################################

variable "database_high_availability" {
  type    = bool
  default = false
}

variable "database_server_count" {
  type    = number
  default = 1
}

variable "use_private_endpoint" {
  type    = bool
  default = false
}

variable "enable_firewall_for_keyvaults_and_storage" {
  type    = bool
  default = false
}

variable "deploy_application_security_groups" {
  type    = bool
  default = true
}

variable "NFS_provider" {
  type    = string
  default = "NFS"
}

variable "use_scalesets_for_deployment" {
  type    = bool
  default = false
}

variable "dual_network_interfaces" {
  type    = bool
  default = false
}

variable "use_ANF" {
  type    = bool
  default = false
}

variable "use_observer" {
  type    = bool
  default = false
}

variable "use_secondary_ips" {
  type    = bool
  default = false
}

variable "database_active_active" {
  type    = bool
  default = false
}

variable "use_DHCP" {
  type    = bool
  default = true
}

variable "scale_out" {
  type    = bool
  default = false
}

#########################################################################################
#  Module instantiation                                                                 #
#########################################################################################

module "hdb_node" {
  source = "../../../../terraform-units/modules/sap_system/hdb_node"

  providers = {
    azurerm.main                     = azurerm
    azurerm.deployer                 = azurerm
    azurerm.dnsmanagement            = azurerm
    azurerm.privatelinkdnsmanagement = azurerm
  }

  admin_subnet = {
    id               = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-admin-subnet"
    address_prefixes = ["10.1.4.0/24"]
  }

  db_subnet = {
    id               = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-db-subnet"
    address_prefixes = ["10.1.1.0/24"]
  }

  resource_group = [
    {
      name     = "DEV-EAUS-SAP-HN1"
      location = "eastus"
      id       = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/DEV-EAUS-SAP-HN1"
    }
  ]

  ppg = ["/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Compute/proximityPlacementGroups/test-ppg"]

  sdu_public_key       = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCYDQJOAtl9hI2WRjUuofU52Kp3EibGHvECLaq+Xlhapaw2kDfM2aNBJiOljOQ40iukU9LlXijofd7CAkfRRi0CKS813bserJHkzOUor/yjBFP8HPolPAgFrgVR5oBinXk/kdIIHjb8l8/2ZEAE9GnRh1zkiffIO/jYnSJ65sFpW4jf3elynkQe+JTFTOluhilXu7pEJe67Vtt1cZT5Nr1KvB7appflK4js4ZGsQmyPyQJ1Vutlyy/5tEJ2DPzy6xaYqR7hmkzlm8PnLk7ovwSrQ4uBqiA3a7GSKY6RhuU6QuW9AZI6noZuwF3FeN1AGBonHfzEgWM6fnK48XXL4Lv7 test@test"
  sid_keyvault_user_id = ""
  sid_password         = "Test1234!fake"
  sid_username         = "azureadm"
  sap_sid              = "HN1"

  storage_bootdiag_endpoint = "https://devsapdiag001.blob.core.windows.net/"
  storage_subnet_id         = ""
  random_id                 = "abc123"

  anchor_vm    = null
  scale_set_id = ""

  db_asg_id                          = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/applicationSecurityGroups/test-db-asg"
  deploy_application_security_groups = var.deploy_application_security_groups
  deployment                         = "new"
  terraform_template_version         = "1.0.0"
  license_type                       = ""
  fencing_role_name                  = ""

  database_server_count                        = var.database_server_count
  database_use_premium_v2_storage              = false
  database_active_active                       = var.database_active_active
  enable_storage_nic                           = false
  use_loadbalancers_for_standalone_deployments = true
  use_msi_for_clusters                         = false
  use_observer                                 = var.use_observer
  use_secondary_ips                            = var.use_secondary_ips
  use_scalesets_for_deployment                 = var.use_scalesets_for_deployment
  use_private_endpoint                         = var.use_private_endpoint
  use_admin_nic_suffix_for_observer            = false
  use_admin_nic_for_asg                        = false
  use_single_hana_shared                       = false
  enable_firewall_for_keyvaults_and_storage    = var.enable_firewall_for_keyvaults_and_storage

  database_vm_admin_nic_ips        = []
  database_vm_db_nic_ips           = []
  database_vm_db_nic_secondary_ips = []
  database_vm_storage_nic_ips      = []

  cloudinit_growpart_config  = null
  custom_disk_sizes_filename = ""
  deployer_tfstate           = {}
  observer_vm_size           = "Standard_D4s_v3"
  observer_vm_zones          = []
  observer_vm_tags           = {}

  NFS_provider                   = var.NFS_provider
  hanashared_volume_size         = 128
  hanashared_id                  = [""]
  hanashared_private_endpoint_id = [""]
  Agent_IP                       = [""]

  tags = {}

  infrastructure = {
    environment = "DEV"
    region      = "eastus"
    codename    = ""
    resource_group = {
      name   = ""
      id     = ""
      exists = false
    }
    tags                               = {}
    deploy_monitoring_extension        = false
    user_assigned_identity_id          = ""
    shared_access_key_enabled          = true
    shared_access_key_enabled_nfs      = true
    encryption_at_host_enabled         = false
    patch_mode                         = "AutomaticByPlatform"
    patch_assessment_mode              = "AutomaticByPlatform"
    platform_updates                   = false
    storage_account_replication_type   = "LRS"
    disk_controller_type_app_tier      = ""
    disk_controller_type_database_tier = null
    application_configuration_id       = ""
    use_application_configuration      = false
    workload_zone_name                 = ""
    deploy_defender_extension          = false
    use_app_proximityplacementgroups   = true
    virtual_networks = {
      sap = {
        name                 = "sap-vnet"
        id                   = ""
        exists               = false
        address_space        = "10.1.0.0/16"
        network_logical_name = "sap"
        logical_name         = "sap"
        subnet_admin = {
          exists             = false
          exists_in_workload = false
        }
      }
    }
  }

  database = {
    platform                           = "HANA"
    high_availability                  = var.database_high_availability
    db_sizing_key                      = "Default"
    use_DHCP                           = var.use_DHCP
    use_ANF                            = var.use_ANF
    use_avset                          = false
    use_ppg                            = true
    avset_arm_ids                      = []
    zones                              = []
    no_ppg                             = false
    no_avset                           = false
    database_vm_count                  = 1
    database_cluster_type              = "AFA"
    dual_network_interfaces            = var.dual_network_interfaces
    database_cluster_disk_lun          = 0
    database_cluster_disk_size         = 128
    database_cluster_disk_type         = "Premium_LRS"
    database_server_count              = 1
    database_vm_sku                    = "Standard_E16ds_v5"
    database_hana_use_saphanasr_angi   = false
    deploy_v1_monitoring_extension     = false
    disk_controller_type_database_tier = ""
    db_version                         = "2.00.066"
    os = {
      os_type         = "LINUX"
      source_image_id = ""
      publisher       = "SUSE"
      offer           = "sles-sap-15-sp5"
      sku             = "gen2"
      version         = "latest"
      type            = "marketplace"
    }
    size      = "Standard_E16ds_v5"
    disk_type = "Premium_LRS"
    authentication = {
      type = "key"
    }
    dbnodes = [{}]
    sid     = "HDB"
    instance = {
      sid    = "HDB"
      number = "00"
    }
    scale_out                 = var.scale_out
    stand_by_node_count       = 0
    observer_sku              = ""
    observer_vm_ips           = []
    tags                      = {}
    user_assigned_identity_id = ""
    fence_kdump_disk_size     = 0
    fence_kdump_lun_number    = -1
    loadbalancer              = { frontend_ips = [] }
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
      db_rlb_feip                    = ""
      db_rlb_hp                      = ""
      db_rlb_rule                    = ""
      db_subnet                      = ""
      db_subnet_nsg                  = ""
      disk                           = ""
      fencing_agent_id               = ""
      fencing_agent_pwd              = ""
      fencing_agent_spn              = ""
      fencing_agent_sub              = ""
      fencing_agent_tenant           = ""
      hana_avg                       = ""
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
      storage_privatelink_hanashared = ""
      fence_kdump_disk               = ""
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
      hanasharedafs                  = "hanasharedafs"
      hanasharedafs_id               = "hanasharedafs-id"
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
      fence_kdump_disk               = "fence-kdump-disk"
    }
    storageaccount_names = {
      SDU = "deveaussapdiagabc"
    }
    virtualmachine_names = {
      ANCHOR_COMPUTERNAME    = []
      ANCHOR_VMNAME          = []
      HANA_COMPUTERNAME      = ["hn1hdb00l0abc", "hn1hdb00l1abc"]
      HANA_VMNAME            = ["DEV-EAUS-SAP-HN1_hn1hdb00l0abc", "DEV-EAUS-SAP-HN1_hn1hdb00l1abc"]
      HANA_SECONDARY_DNSNAME = ["hn1hdb00l0abc-db", "hn1hdb00l1abc-db"]
      OBSERVER_COMPUTERNAME  = ["hn1hdb00lobserver"]
      OBSERVER_VMNAME        = ["DEV-EAUS-SAP-HN1_hn1hdb00lobserver"]
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

  options = {
    enable_secure_transfer                       = true
    use_spn                                      = false
    disk_encryption_set_id                       = null
    nsg_asg_with_vnet                            = false
    legacy_nic_order                             = false
    resource_offset                              = 0
    use_loadbalancers_for_standalone_deployments = true
  }

  dns_settings = {
    use_custom_dns_a_registration                = false
    register_storage_accounts_keyvaults_with_dns = false
    register_endpoints_with_dns                  = false
    dns_zone_names                               = {}
    management_dns_resourcegroup_name            = ""
    management_dns_subscription_id               = ""
    privatelink_dns_subscription_id              = ""
    privatelink_dns_resourcegroup_name           = ""
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
    ANF_pool_settings = {
      use_ANF             = false
      account_name        = ""
      account_id          = ""
      pool_name           = ""
      service_level       = ""
      size_in_tb          = ""
      subnet_id           = ""
      resource_group_name = ""
      location            = ""
    }
    use_separate_storage_subnet   = false
    public_network_access_enabled = true
    privatelink_file_id           = ""
    dns_label                     = ""
    dns_resource_group_name       = ""
    automation_version            = "1.0.0"
  }

  hana_ANF_volumes = {
    use_for_usr_sap                    = false
    use_existing_usr_sap_volume        = false
    usr_sap_volume_size                = 64
    usr_sap_volume_name                = ""
    usr_sap_volume_throughput          = 128
    use_for_data                       = false
    use_existing_data_volume           = false
    data_volume_size                   = 512
    data_volume_name                   = ""
    data_volume_throughput             = 128
    data_volume_count                  = 1
    use_for_log                        = false
    use_existing_log_volume            = false
    log_volume_size                    = 128
    log_volume_name                    = ""
    log_volume_throughput              = 128
    log_volume_count                   = 1
    use_for_shared                     = false
    use_existing_shared_volume         = false
    shared_volume_size                 = 256
    shared_volume_name                 = ""
    shared_volume_throughput           = 128
    use_for_sapmnt                     = false
    use_existing_sapmnt_volume         = false
    sapmnt_volume_size                 = 128
    sapmnt_volume_name                 = ""
    sapmnt_volume_throughput           = 64
    sapmnt_use_clone_in_secondary_zone = false
    use_AVG_for_data                   = false
    use_zones                          = false
  }
}

#########################################################################################
#  Outputs — expose key module outputs for assertions in test scenarios                 #
#########################################################################################

output "hdb_sid" {
  value = module.hdb_node.hdb_sid
}

output "hanadb_vm_ids" {
  value = module.hdb_node.hanadb_vm_ids
}

output "database_server_vm_names" {
  value = module.hdb_node.database_server_vm_names
}

output "database_disks" {
  value = module.hdb_node.database_disks
}

output "database_loadbalancer_id" {
  value = module.hdb_node.database_loadbalancer_id
}

output "database_loadbalancer_ip" {
  value = module.hdb_node.database_loadbalancer_ip
}

output "db_admin_ips" {
  value = module.hdb_node.db_admin_ips
}

output "database_server_ips" {
  value = module.hdb_node.database_server_ips
}

output "hana_data_ANF_volumes" {
  value = module.hdb_node.hana_data_ANF_volumes
}

output "hana_log_ANF_volumes" {
  value = module.hdb_node.hana_log_ANF_volumes
}

output "observer_ips" {
  value = module.hdb_node.observer_ips
}

output "observer_vms" {
  value = module.hdb_node.observer_vms
}

output "site_information" {
  value = module.hdb_node.site_information
}

output "loadbalancers" {
  value = module.hdb_node.loadbalancers
}

output "database_shared_disks" {
  value = module.hdb_node.database_shared_disks
}

