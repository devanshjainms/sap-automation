# Test harness for sap_system/anydb_node terraform-units module
# Constructs minimal valid input objects and invokes the module with mock providers.
# This allows testing conditional resource creation logic without real Azure access.
#
# anydb_node handles non-HANA databases: ORACLE, DB2, SQLSERVER, SYBASE.
# It creates VMs, NICs, load balancers, availability sets, data disks,
# cluster disks (for HA), and observer VMs (for Oracle HA).

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

variable "database_platform" {
  type    = string
  default = "ORACLE"
}

variable "database_high_availability" {
  type    = bool
  default = false
}

variable "database_server_count" {
  type    = number
  default = 1
}

variable "use_DHCP" {
  type    = bool
  default = true
}

variable "use_observer" {
  type    = bool
  default = false
}

variable "deploy_application_security_groups" {
  type    = bool
  default = true
}

variable "use_scalesets_for_deployment" {
  type    = bool
  default = false
}

variable "dual_network_interfaces" {
  type    = bool
  default = false
}

variable "use_secondary_ips" {
  type    = bool
  default = false
}

variable "use_loadbalancers_for_standalone_deployments" {
  type    = bool
  default = false
}

variable "use_avset" {
  type    = bool
  default = true
}

variable "database_zones" {
  type    = list(string)
  default = []
}

#########################################################################################
#  Module instantiation                                                                 #
#########################################################################################

module "anydb_node" {
  source = "../../../../terraform-units/modules/sap_system/anydb_node"

  providers = {
    azurerm.main                     = azurerm
    azurerm.deployer                 = azurerm
    azurerm.dnsmanagement            = azurerm
    azurerm.privatelinkdnsmanagement = azurerm
  }

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
    disk_controller_type_app_tier      = null
    disk_controller_type_database_tier = null
    application_configuration_id       = ""
    use_application_configuration      = false
    workload_zone_name                 = ""
  }

  database = {
    platform                           = var.database_platform
    high_availability                  = var.database_high_availability
    db_sizing_key                      = "1024"
    use_DHCP                           = var.use_DHCP
    use_ANF                            = false
    use_avset                          = var.use_avset
    use_ppg                            = true
    avset_arm_ids                      = []
    zones                              = var.database_zones
    no_ppg                             = false
    no_avset                           = false
    database_vm_count                  = 1
    database_cluster_type              = "AFA"
    dual_network_interfaces            = var.dual_network_interfaces
    database_cluster_disk_lun          = 0
    database_cluster_disk_size         = 128
    database_cluster_disk_type         = "Premium_LRS"
    database_server_count              = var.database_server_count
    database_vm_sku                    = "Standard_E16ds_v5"
    database_hana_use_saphanasr_angi   = false
    deploy_v1_monitoring_extension     = false
    disk_controller_type_database_tier = null
    os = {
      os_type         = var.database_platform == "SQLSERVER" ? "WINDOWS" : "LINUX"
      source_image_id = ""
      publisher       = var.database_platform == "SQLSERVER" ? "MicrosoftSqlServer" : (var.database_platform == "ORACLE" || var.database_platform == "ORACLE-ASM" ? "Oracle" : "RedHat")
      offer           = var.database_platform == "SQLSERVER" ? "SQL2017-WS2016" : (var.database_platform == "ORACLE" || var.database_platform == "ORACLE-ASM" ? "Oracle-Linux" : "RHEL-SAP-HA")
      sku             = var.database_platform == "SQLSERVER" ? "standard-gen2" : (var.database_platform == "ORACLE" || var.database_platform == "ORACLE-ASM" ? "ol8_6-gen2" : "86sapha-gen2")
      version         = "latest"
      type            = "marketplace"
    }
    size      = "Standard_E16ds_v5"
    disk_type = "Premium_LRS"
    authentication = {
      type = "key"
    }
    dbnodes = [{}]
    sid     = "ORA"
    instance = {
      sid    = "ORA"
      number = "00"
    }
    scale_out                 = false
    stand_by_node_count       = 0
    observer_sku              = ""
    observer_vm_ips           = []
    tags                      = {}
    user_assigned_identity_id = ""
    fence_kdump_disk_size     = 0
    fence_kdump_lun_number    = -1
    loadbalancer              = { frontend_ips = [] }
    credentials               = {}
  }

  admin_subnet = {
    id               = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-admin-subnet"
    name             = "test-admin-subnet"
    address_prefixes = ["10.1.4.0/24"]
    defined          = true
    exists           = true
  }

  db_subnet = {
    id               = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-db-subnet"
    name             = "test-db-subnet"
    address_prefixes = ["10.1.1.0/24"]
    defined          = true
    exists           = true
  }

  resource_group = [
    {
      name     = "DEV-EAUS-SAP-ORA"
      location = "eastus"
      id       = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/DEV-EAUS-SAP-ORA"
    }
  ]

  ppg = ["/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/DEV-EAUS-SAP-ORA/providers/Microsoft.Compute/proximityPlacementGroups/test-ppg"]

  anchor_vm = null

  scale_set_id = ""

  sdu_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDPoa+jafoAJnLNWAlCvI5fSa/hsctml9bJnrCqWR64JDJsupLUfdpKCtKQ3D3AByUkw6kHGWGM9JizvMQ6yyk16H8/0RJ48kTAFkM+LXbbiS8ts0Yls8y9z73gDUz3NoJ62/eYKZ8r8XVcunGeC/oclRh+XElpSEfH2XPnRyu9cOgUqMaaBS4NFZXWhJBpv6npduBFQNcKxeAIBAZH+jh+xrmU97lBQ3tBmCDTbDq5ma2cyVaMQaOYXrIzoYHdfYMDL9E/LOhdrnWuMdIq9qgy5iB2Mh/YhHUGshJYwBqYQXkPapEG5wDXd6dZTUwqHVWsSCEoRS7HifbnP3hGJf3t test@test"

  sid_keyvault_user_id = ""

  sid_password = "Test1234567890!"
  sid_username = "azureadm"

  storage_bootdiag_endpoint = "https://devsapdiag001.blob.core.windows.net/"

  sap_sid = "ORA"

  db_asg_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/applicationSecurityGroups/test-db-asg"

  database_server_count = var.database_server_count

  database_vm_db_nic_ips           = []
  database_vm_db_nic_secondary_ips = []
  database_vm_admin_nic_ips        = []

  deploy_application_security_groups = var.deploy_application_security_groups
  deployment                         = "new"
  fencing_role_name                  = ""
  license_type                       = ""
  terraform_template_version         = "1.0.0"
  custom_disk_sizes_filename         = ""
  cloudinit_growpart_config          = null
  order_deployment                   = null

  use_observer                                 = var.use_observer
  observer_vm_size                             = "Standard_D4s_v3"
  observer_vm_tags                             = {}
  observer_vm_zones                            = []
  use_admin_nic_suffix_for_observer            = false
  use_admin_nic_for_asg                        = false
  use_loadbalancers_for_standalone_deployments = var.use_loadbalancers_for_standalone_deployments
  use_msi_for_clusters                         = false
  use_scalesets_for_deployment                 = var.use_scalesets_for_deployment
  use_secondary_ips                            = var.use_secondary_ips

  options = {
    enable_secure_transfer                       = true
    use_spn                                      = false
    disk_encryption_set_id                       = null
    nsg_asg_with_vnet                            = false
    legacy_nic_order                             = false
    resource_offset                              = 0
    use_loadbalancers_for_standalone_deployments = var.use_loadbalancers_for_standalone_deployments
  }

  naming = {
    prefix = {
      DEPLOYER      = "DEV-EAUS-DEP"
      SDU           = "DEV-EAUS-SAP-ORA"
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
      fence_kdump_disk               = "-fence-kdump-disk"
    }
    storageaccount_names = {
      SDU = "deveaussapdiagabc"
    }
    virtualmachine_names = {
      ANCHOR_COMPUTERNAME     = []
      ANCHOR_VMNAME           = []
      ANYDB_COMPUTERNAME      = ["db00l0000", "db00l0001"]
      ANYDB_VMNAME            = ["db00l0000", "db00l0001"]
      ANYDB_SECONDARY_DNSNAME = ["db00l0000-dbnic", "db00l0001-dbnic"]
      OBSERVER_COMPUTERNAME   = ["observer00l00"]
      OBSERVER_VMNAME         = ["observer00l00"]
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
    dns_label                       = ""
    dns_resource_group_name         = ""
  }

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

  tags = {}
}

#########################################################################################
#  Outputs — expose key module outputs for assertions in test scenarios                 #
#########################################################################################

output "database_loadbalancer_id" {
  value = module.anydb_node.database_loadbalancer_id
}

output "database_loadbalancer_ip" {
  value = module.anydb_node.database_loadbalancer_ip
}

output "database_server_ips" {
  value = module.anydb_node.database_server_ips
}

output "database_server_vm_ids" {
  value = module.anydb_node.database_server_vm_ids
}

output "database_server_vm_names" {
  value = module.anydb_node.database_server_vm_names
}

output "database_disks" {
  value = module.anydb_node.database_disks
}

output "dns_info_vms" {
  value = module.anydb_node.dns_info_vms
}

output "dns_info_loadbalancers" {
  value = module.anydb_node.dns_info_loadbalancers
}

output "observer_ips" {
  value = module.anydb_node.observer_ips
}

output "observer_vms" {
  value = module.anydb_node.observer_vms
}

output "database_shared_disks" {
  value = module.anydb_node.database_shared_disks
}

output "database_cluster_ip" {
  value = module.anydb_node.database_cluster_ip
}
