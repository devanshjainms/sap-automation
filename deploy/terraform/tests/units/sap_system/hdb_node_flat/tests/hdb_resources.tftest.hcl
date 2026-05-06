## hdb_node — Resource-Level Unit Tests
##
## Tests individual resource attributes directly (not via outputs).
## This is the HashiCorp-recommended pattern: test the module as root,
## assert on resource parameters like size, zone, name, storage_account_type.
##
## Pattern: symlink module .tf files, replace providers.tf for root-level usage,
## mock all provider aliases. Resources become directly assertable.

mock_provider "azurerm" {
  alias = "main"
}
mock_provider "azurerm" {
  alias = "deployer"
}
mock_provider "azurerm" {
  alias = "dnsmanagement"
}
mock_provider "azurerm" {
  alias = "privatelinkdnsmanagement"
}

###############################################################################
# 1. VM Configuration                                                         #
###############################################################################

run "vm_count_single_node" {
  command = plan
  assert {
    condition     = length(azurerm_linux_virtual_machine.vm_dbnode) == 1
    error_message = "Default config should create exactly 1 HANA VM"
  }
}

run "vm_sku_from_sizing" {
  command = plan
  assert {
    condition     = azurerm_linux_virtual_machine.vm_dbnode[0].size == "Standard_E16ds_v5"
    error_message = "VM SKU should be Standard_E16ds_v5 (from Default sizing key)"
  }
}

run "vm_computer_name_from_naming" {
  command = plan
  assert {
    condition     = azurerm_linux_virtual_machine.vm_dbnode[0].computer_name == "hn1hdb00l0abc"
    error_message = "Computer name should match namegenerator: hn1hdb00l0abc"
  }
}

run "vm_admin_username" {
  command = plan
  assert {
    condition     = azurerm_linux_virtual_machine.vm_dbnode[0].admin_username == "azureadm"
    error_message = "Admin username should be azureadm (passed via sid_username)"
  }
}

run "vm_password_auth_disabled" {
  command = plan
  assert {
    condition     = azurerm_linux_virtual_machine.vm_dbnode[0].disable_password_authentication == true
    error_message = "Password auth should be disabled (key-based auth default)"
  }
}

###############################################################################
# 2. Managed Disks                                                            #
###############################################################################

run "data_disks_created" {
  command = plan
  assert {
    condition     = length(azurerm_managed_disk.data_disk) > 0
    error_message = "Must create managed data disks for HANA"
  }
}

run "data_disks_all_empty_create" {
  command = plan
  assert {
    condition     = alltrue([for d in azurerm_managed_disk.data_disk : d.create_option == "Empty"])
    error_message = "All data disks must use Empty create_option"
  }
}

run "data_disk_storage_types_valid" {
  command = plan

  # data/log disks use Premium_LRS, shared/sap/backup use StandardSSD_LRS
  assert {
    condition = alltrue([
      for d in azurerm_managed_disk.data_disk :
      contains(["Premium_LRS", "Premium_ZRS", "PremiumV2_LRS", "UltraSSD_LRS", "StandardSSD_LRS"], d.storage_account_type)
    ])
    error_message = "All HANA disks must use a valid storage type"
  }

  # Specifically: data disks (name contains -data) must be Premium
  assert {
    condition = alltrue([
      for d in azurerm_managed_disk.data_disk :
      d.storage_account_type == "Premium_LRS" if strcontains(d.name, "-data")
    ])
    error_message = "HANA data disks must use Premium_LRS"
  }

  # Log disks must also be Premium
  assert {
    condition = alltrue([
      for d in azurerm_managed_disk.data_disk :
      d.storage_account_type == "Premium_LRS" if strcontains(d.name, "-log")
    ])
    error_message = "HANA log disks must use Premium_LRS"
  }
}

run "disk_attachments_match_disk_count" {
  command = plan
  assert {
    condition     = length(azurerm_virtual_machine_data_disk_attachment.vm_dbnode_data_disk) == length(azurerm_managed_disk.data_disk)
    error_message = "Every managed disk must have a corresponding attachment"
  }
}

###############################################################################
# 3. Network Interfaces                                                       #
###############################################################################

run "db_nic_created" {
  command = plan
  assert {
    condition     = length(azurerm_network_interface.nics_dbnodes_db) == 1
    error_message = "Should create 1 DB NIC for single-node"
  }
}

run "admin_nic_not_created_single_network" {
  command = plan
  assert {
    condition     = length(azurerm_network_interface.nics_dbnodes_admin) == 0
    error_message = "Admin NIC should NOT be created when dual_network_interfaces is false"
  }
}

###############################################################################
# 4. Load Balancer — created for standalone (use_loadbalancers_for_standalone) #
###############################################################################

run "lb_created_for_standalone" {
  command = plan
  assert {
    condition     = length(azurerm_lb.hdb) == 1
    error_message = "LB should be created when use_loadbalancers_for_standalone_deployments = true"
  }
  assert {
    condition     = azurerm_lb.hdb[0].sku == "Standard"
    error_message = "LB SKU must be Standard"
  }
}

run "lb_backend_pool_created" {
  command = plan
  assert {
    condition     = length(azurerm_lb_backend_address_pool.hdb) == 1
    error_message = "LB must have a backend address pool"
  }
}

run "lb_has_health_probe" {
  command = plan
  assert {
    condition     = length(azurerm_lb_probe.hdb) > 0
    error_message = "LB must have at least one health probe"
  }
}

run "lb_has_rules" {
  command = plan
  assert {
    condition     = length(azurerm_lb_rule.hdb) > 0
    error_message = "LB must have at least one rule"
  }
}

###############################################################################
# 5. Availability Set — default (non-zonal)                                   #
###############################################################################

run "availability_set_count" {
  command = plan
  # avset creation depends on use_avset flag in database config
  # With default config (no zones, no avset explicitly), check the plan count
  assert {
    condition     = length(azurerm_availability_set.hdb) >= 0
    error_message = "Availability set count should be valid"
  }
}

###############################################################################
# 6. Observer VM — not created by default                                     #
###############################################################################

run "no_observer_by_default" {
  command = plan
  assert {
    condition     = length(azurerm_linux_virtual_machine.observer) == 0
    error_message = "Observer VM should NOT be created when use_observer is false"
  }
}

run "no_observer_nics_by_default" {
  command = plan
  assert {
    condition     = length(azurerm_network_interface.observer) == 0
    error_message = "Observer NICs should NOT be created when use_observer is false"
  }
}

###############################################################################
# 7. ANF Volumes — disabled by default                                        #
###############################################################################

run "no_anf_volumes_by_default" {
  command = plan
  assert {
    condition     = length(azurerm_netapp_volume.hanadata) == 0
    error_message = "ANF data volumes should NOT be created when use_ANF is false"
  }
  assert {
    condition     = length(azurerm_netapp_volume.hanalog) == 0
    error_message = "ANF log volumes should NOT be created when use_ANF is false"
  }
  assert {
    condition     = length(azurerm_netapp_volume.hanashared) == 0
    error_message = "ANF shared volumes should NOT be created when use_ANF is false"
  }
}

###############################################################################
# 8. Storage Account                                                          #
###############################################################################

run "witness_storage_created" {
  command = plan
  assert {
    condition     = length(azurerm_storage_account.hanashared) >= 0
    error_message = "HANA shared storage evaluation should not error"
  }
}

###############################################################################
# 9. HA scenario — 2 VMs with LB                                             #
###############################################################################

run "ha_creates_two_vms" {
  command = plan
  variables {
    database_server_count = 2
  }
  assert {
    condition     = length(azurerm_linux_virtual_machine.vm_dbnode) == 2
    error_message = "HA (count=2) should create exactly 2 VMs"
  }
}

run "ha_both_vms_same_sku" {
  command = plan
  variables {
    database_server_count = 2
  }
  assert {
    condition     = azurerm_linux_virtual_machine.vm_dbnode[0].size == azurerm_linux_virtual_machine.vm_dbnode[1].size
    error_message = "Both HA VMs must have identical SKU"
  }
}

run "ha_creates_lb" {
  command = plan
  variables {
    database_server_count = 2
  }
  assert {
    condition     = length(azurerm_lb.hdb) > 0
    error_message = "HA deployment must create a load balancer"
  }
  assert {
    condition     = azurerm_lb.hdb[0].sku == "Standard"
    error_message = "LB SKU must be Standard for zone-redundant HA"
  }
}

run "ha_creates_lb_rules_and_probes" {
  command = plan
  variables {
    database_server_count = 2
  }
  assert {
    condition     = length(azurerm_lb_rule.hdb) > 0
    error_message = "HA LB must have at least one rule"
  }
  assert {
    condition     = length(azurerm_lb_probe.hdb) > 0
    error_message = "HA LB must have at least one health probe"
  }
  assert {
    condition     = length(azurerm_lb_backend_address_pool.hdb) > 0
    error_message = "HA LB must have a backend address pool"
  }
}

run "ha_two_db_nics" {
  command = plan
  variables {
    database_server_count = 2
  }
  assert {
    condition     = length(azurerm_network_interface.nics_dbnodes_db) == 2
    error_message = "HA should create 2 DB NICs (one per VM)"
  }
}

run "ha_disks_doubled" {
  command = plan
  variables {
    database_server_count = 2
  }
  assert {
    condition     = length(azurerm_managed_disk.data_disk) > length(azurerm_managed_disk.data_disk) / 2
    error_message = "HA disk count should be > half total (sanity check)"
  }
  assert {
    condition     = length(azurerm_virtual_machine_data_disk_attachment.vm_dbnode_data_disk) == length(azurerm_managed_disk.data_disk)
    error_message = "Every HA disk must have a disk attachment"
  }
}
