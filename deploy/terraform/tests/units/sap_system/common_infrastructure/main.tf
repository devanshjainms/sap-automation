# Test harness for sap_system/common_infrastructure terraform-units module
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

variable "scs_high_availability" {
  type    = bool
  default = false
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

variable "use_AFS_for_shared_storage" {
  type    = bool
  default = false
}

variable "use_AFS_for_sapmnt" {
  type    = bool
  default = false
}

variable "NFS_provider" {
  type    = string
  default = "NFS"
}

variable "use_scalesets_for_deployment" {
  type    = bool
  default = false
}

variable "use_app_proximityplacementgroups" {
  type    = bool
  default = true
}

variable "enable_deployment" {
  type    = bool
  default = true
}

variable "dual_network_interfaces" {
  type    = bool
  default = false
}

variable "nsg_asg_with_vnet" {
  type    = bool
  default = false
}

variable "db_use_ppg" {
  type    = bool
  default = true
}

variable "storage_account_replication_type" {
  type    = string
  default = "LRS"
}

variable "brownfield_resource_group_id" {
  description = "ARM ID of an existing resource group (brownfield). Empty = create new."
  type        = string
  default     = ""
}

variable "brownfield_keyvault_id" {
  description = "ARM ID of an existing Key Vault for system credentials (brownfield). Empty = create new."
  type        = string
  default     = ""
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

variable "test_sid" {
  type    = string
  default = "HN1"
  validation {
    condition     = length(trimspace(var.test_sid)) == 3
    error_message = "The SID must be exactly 3 characters."
  }
}

variable "test_db_platform" {
  type    = string
  default = "HANA"
}

variable "test_db_sizing_key" {
  type    = string
  default = "Default"
  validation {
    condition     = length(trimspace(var.test_db_sizing_key)) > 0
    error_message = "The db_sizing_key must not be empty."
  }
}

variable "test_ha_validator" {
  type    = string
  default = "0-NONE"
  validation {
    condition     = !(substr(var.test_ha_validator, 0, 1) != "0" && endswith(var.test_ha_validator, "-NONE"))
    error_message = "NFS provider must be specified when HA is enabled (first char != 0)."
  }
}

variable "test_vnet_logical_name" {
  type    = string
  default = "sap"
  validation {
    condition     = length(trimspace(var.test_vnet_logical_name)) > 0
    error_message = "VNet logical name must not be empty."
  }
}

variable "test_landscape_vnet_arm_id" {
  type    = string
  default = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet"
  validation {
    condition     = length(trimspace(var.test_landscape_vnet_arm_id)) > 0
    error_message = "The landscape VNet ARM ID (vnet_sap_arm_id) must be defined."
  }
}

#########################################################################################
#  Module instantiation                                                                 #
#########################################################################################

module "common_infra" {
  source = "../../../../terraform-units/modules/sap_system/common_infrastructure"

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
      name   = ""
      id     = var.brownfield_resource_group_id
      exists = length(var.brownfield_resource_group_id) > 0
    }
    tags = {}
    virtual_networks = {
      sap = {
        name                 = "sap-vnet"
        id                   = ""
        exists               = false
        address_space        = "10.1.0.0/16"
        network_logical_name = "sap"
        logical_name         = var.test_vnet_logical_name
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
    use_app_proximityplacementgroups   = var.use_app_proximityplacementgroups
    storage_account_replication_type   = var.storage_account_replication_type
    disk_controller_type_app_tier      = ""
    disk_controller_type_database_tier = ""
    application_configuration_id       = ""
    use_application_configuration      = false
    workload_zone_name                 = ""
  }

  database = {
    platform                           = var.test_db_platform
    high_availability                  = var.database_high_availability
    db_sizing_key                      = var.test_db_sizing_key
    use_DHCP                           = true
    use_ANF                            = false
    use_avset                          = false
    use_ppg                            = var.db_use_ppg
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
    os = {
      os_type         = "LINUX"
      source_image_id = ""
      publisher       = "SUSE"
      offer           = "sles-sap-15-sp5"
      sku             = "gen1"
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
    scale_out                 = false
    stand_by_node_count       = 0
    observer_sku              = ""
    observer_vm_ips           = []
    tags                      = {}
    user_assigned_identity_id = ""
    fence_kdump_disk_size     = 0
    fence_kdump_lun_number    = -1
    loadbalancer              = { frontend_ips = [] }
  }

  application_tier = {
    sid                            = var.test_sid
    enable_deployment              = var.enable_deployment
    use_DHCP                       = true
    dual_network_interfaces        = var.dual_network_interfaces
    vm_sizing_dictionary_key       = "Optimized"
    app_instance_number            = "00"
    application_server_count       = 1
    app_sku                        = "Standard_D4ds_v5"
    app_use_ppg                    = true
    app_use_avset                  = false
    app_zone_count                 = 0
    scs_server_count               = 1
    scs_high_availability          = var.scs_high_availability
    scs_cluster_type               = "AFA"
    scs_instance_number            = "00"
    ers_instance_number            = "02"
    scs_sku                        = "Standard_D4ds_v5"
    scs_use_ppg                    = true
    scs_use_avset                  = false
    scs_zone_count                 = 0
    scs_cluster_disk_lun           = 0
    scs_cluster_disk_size          = 128
    scs_cluster_disk_type          = "Premium_LRS"
    webdispatcher_count            = 0
    web_instance_number            = "00"
    web_sid                        = "WEB"
    web_sku                        = ""
    web_use_ppg                    = false
    web_use_avset                  = false
    web_zone_count                 = 0
    deploy_v1_monitoring_extension = false
    avset_arm_ids                  = []
    avset_arm_ids_count            = 0
    user_assigned_identity_id      = ""
    disk_controller_type_app_tier  = ""
    app_os = {
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
    use_AFS_for_sapmnt     = var.use_AFS_for_sapmnt
    fence_kdump_disk_size  = 0
    fence_kdump_lun_number = -1
  }

  application_tier_ppg_names = ["-app-ppg"]

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
      ANCHOR_COMPUTERNAME = []
      ANCHOR_VMNAME       = []
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

  authentication = {
    username            = "azureadm"
    password            = ""
    path_to_public_key  = ""
    path_to_private_key = ""
  }

  options = {
    enable_secure_transfer                       = true
    use_spn                                      = false
    disk_encryption_set_id                       = ""
    nsg_asg_with_vnet                            = var.nsg_asg_with_vnet
    legacy_nic_order                             = false
    resource_offset                              = 0
    use_loadbalancers_for_standalone_deployments = true
  }

  key_vault = {
    id                                 = ""
    exists                             = false
    keyvault_id_for_system_credentials = var.brownfield_keyvault_id
    private_key_secret_name            = ""
    public_key_secret_name             = ""
    username_secret_name               = ""
    password_secret_name               = ""
    enable_rbac_authorization          = false
  }

  ha_validator = var.test_ha_validator

  custom_prefix                             = ""
  is_single_node_hana                       = "true"
  deployer_tfstate                          = null
  custom_disk_sizes_filename                = ""
  deployment                                = "new"
  terraform_template_version                = "1.0.0"
  license_type                              = ""
  enable_purge_control_for_keyvaults        = false
  sapmnt_volume_size                        = 128
  NFS_provider                              = var.NFS_provider
  azure_files_sapmnt_id                     = ""
  use_random_id_for_storageaccounts         = true
  Agent_IP                                  = ""
  use_private_endpoint                      = var.use_private_endpoint
  enable_firewall_for_keyvaults_and_storage = var.enable_firewall_for_keyvaults_and_storage
  use_AFS_for_shared_storage                = var.use_AFS_for_shared_storage
  AFS_enable_encryption_in_transit          = false
  sapmnt_private_endpoint_id                = ""
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

  deploy_application_security_groups = var.deploy_application_security_groups
  use_scalesets_for_deployment       = var.use_scalesets_for_deployment
  scaleset_id                        = ""
  tags                               = {}

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
    vnet_sap_arm_id                 = var.test_landscape_vnet_arm_id
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
}

#########################################################################################
#  Outputs — expose key module outputs for assertions in test scenarios                 #
#########################################################################################

output "resource_group_name" {
  value = module.common_infra.created_resource_group_name
}

output "resource_group_id" {
  value = module.common_infra.created_resource_group_id
}

output "random_id" {
  value = module.common_infra.random_id
}

output "ppg" {
  value = module.common_infra.ppg
}

output "app_ppg" {
  value = module.common_infra.app_ppg
}

output "network_resource_group" {
  value = module.common_infra.network_resource_group
}

output "db_asg_id" {
  value = module.common_infra.db_asg_id
}

output "route_table_id" {
  value = module.common_infra.route_table_id
}

output "firewall_id" {
  value = module.common_infra.firewall_id
}

output "use_local_credentials" {
  value = module.common_infra.use_local_credentials
}

output "storage_subnet_id" {
  value = module.common_infra.storage_subnet_id
}

output "use_AFS_encryption_in_transit" {
  value = module.common_infra.use_AFS_encryption_in_transit
}

output "scale_set_id" {
  value = module.common_infra.scale_set_id
}

output "sid_keyvault_user_id" {
  value = module.common_infra.sid_keyvault_user_id
}

## Bug detection outputs — expose additional module outputs for bug tests
output "sapmnt_path" {
  value = module.common_infra.sapmnt_path
}

output "db_subnet_netmask" {
  value = module.common_infra.db_subnet_netmask
}
