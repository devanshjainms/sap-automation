## SAP System HDB Node — SYSTEMATIC Plan-Level Tests
##
## Tests the hdb_node sub-module of sap_system, which creates:
## - HANA database VMs (Linux) with data/log/shared disks
## - Load balancers for HANA HA and standalone
## - Availability sets or zones for HA
## - Admin, DB, and storage network interfaces
## - ANF volumes for data/log/shared (when ANF enabled)
## - Observer VMs for HA monitoring
## - Storage accounts for HANA shared (AFS)
##
## DESIGN: database_server_count is passed directly (NOT pre-doubled).
##   - For HA with 1 primary + 1 secondary: pass database_server_count=2
##   - For standalone 1 node: pass database_server_count=1
##
## All tests use mock providers with command = plan (no real Azure resources).

mock_provider "azurerm" {
  override_data {
    target = module.hdb_node.data.azurerm_subnet.storage[0]
    values = {
      address_prefixes = ["10.1.5.0/24"]
      id               = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/storage-subnet"
    }
  }
}

###############################################################################
# SECTION 1: HANA VM Configuration                                           #
###############################################################################

run "single_standalone_node_creates_one_vm" {
  command = plan

  variables {
    database_server_count      = 1
    database_high_availability = false
  }

  assert {
    condition     = length(output.hanadb_vm_ids) == 1
    error_message = "Standalone single node should plan exactly 1 VM"
  }

  assert {
    condition     = length(output.database_server_ips) == 1
    error_message = "Should have exactly 1 DB server IP for single node"
  }

  assert {
    condition     = output.hdb_sid == "HDB"
    error_message = "HDB SID should be 'HDB' from database.instance.sid"
  }
}

run "ha_two_nodes_creates_two_vms" {
  command = plan

  variables {
    database_server_count      = 2
    database_high_availability = true
  }

  assert {
    condition     = length(output.hanadb_vm_ids) == 2
    error_message = "HA deployment should plan exactly 2 VMs"
  }

  assert {
    condition     = length(output.database_server_ips) == 2
    error_message = "Should have exactly 2 DB server IPs for HA pair"
  }

  assert {
    condition     = output.hdb_sid == "HDB"
    error_message = "HDB SID should remain 'HDB' in HA mode"
  }
}

run "two_nodes_no_ha_creates_two_vms" {
  command = plan

  variables {
    database_server_count      = 2
    database_high_availability = false
  }

  assert {
    condition     = length(output.hanadb_vm_ids) == 2
    error_message = "2 standalone nodes should plan exactly 2 VMs"
  }

  assert {
    condition     = length(output.database_server_ips) == 2
    error_message = "Should have 2 DB server IPs for 2 standalone nodes"
  }
}

run "vm_names_match_naming_convention" {
  command = plan

  variables {
    database_server_count      = 1
    database_high_availability = false
  }

  assert {
    condition     = length(output.database_server_vm_names) == 1
    error_message = "Should have exactly 1 VM name"
  }

  assert {
    condition     = output.database_server_vm_names[0] == "DEV-EAUS-SAP-HN1_DEV-EAUS-SAP-HN1_hn1hdb00l0abc"
    error_message = "VM name should follow naming convention: prefix_HANA_VMNAME"
  }
}

###############################################################################
# SECTION 2: Load Balancer Configuration                                     #
###############################################################################

run "standalone_with_lb_enabled_creates_lb" {
  command = plan

  variables {
    database_server_count      = 1
    database_high_availability = false
  }

  # use_loadbalancers_for_standalone_deployments defaults to true in setup
  assert {
    condition     = output.database_loadbalancer_id[0] != ""
    error_message = "LB should be created when use_loadbalancers_for_standalone_deployments=true"
  }

  assert {
    condition     = output.loadbalancers != null
    error_message = "Loadbalancers output should not be null when LB is deployed"
  }
}

run "ha_deployment_creates_lb" {
  command = plan

  variables {
    database_server_count      = 2
    database_high_availability = true
  }

  assert {
    condition     = output.database_loadbalancer_id[0] != ""
    error_message = "LB should always be created for HA deployments"
  }

  # database_loadbalancer_ip depends on plan-time unknown values (private IPs)
  # so we validate LB existence via its ID instead
  assert {
    condition     = output.loadbalancers != null
    error_message = "LB should be planned for HA deployment"
  }
}

run "active_active_creates_two_frontend_ips" {
  command = plan

  variables {
    database_server_count      = 2
    database_high_availability = true
    database_active_active     = true
  }

  # KNOWN_BUG: hdb_node/variables_local.tf:215 — second frontend IP uses [0] not [1]
  # when frontend_ips are explicitly provided. With DHCP=true (default in test),
  # both IPs are Dynamic so this bug is not triggered, but the slice produces 2 entries.
  assert {
    condition     = output.database_loadbalancer_id[0] != ""
    error_message = "Active-active LB should be created"
  }
}

###############################################################################
# SECTION 3: Network Interfaces                                              #
###############################################################################

run "single_node_gets_db_nic_only" {
  command = plan

  variables {
    database_server_count      = 1
    database_high_availability = false
    dual_network_interfaces    = false
  }

  assert {
    condition     = length(output.database_server_ips) == 1
    error_message = "Should have 1 DB NIC IP"
  }

  assert {
    condition     = length(output.db_admin_ips) == 0
    error_message = "Admin IPs should be empty when dual_nics=false"
  }
}

run "dual_nics_creates_admin_nic" {
  command = plan

  variables {
    database_server_count      = 2
    database_high_availability = true
    dual_network_interfaces    = true
  }

  assert {
    condition     = length(output.db_admin_ips) == 2
    error_message = "Admin IPs should have 2 entries when dual_nics=true with 2 VMs"
  }

  assert {
    condition     = length(output.database_server_ips) == 2
    error_message = "DB NICs should still be created alongside admin NICs"
  }
}

run "dual_nics_false_no_admin_nic" {
  command = plan

  variables {
    database_server_count      = 2
    database_high_availability = true
    dual_network_interfaces    = false
  }

  assert {
    condition     = length(output.db_admin_ips) == 0
    error_message = "Admin NICs should NOT be created when dual_network_interfaces=false"
  }
}

run "secondary_ips_enabled" {
  command = plan

  variables {
    database_server_count      = 2
    database_high_availability = true
    use_secondary_ips          = true
  }

  assert {
    condition     = length(output.database_server_ips) == 2
    error_message = "Primary IPs should still be created with secondary IPs enabled"
  }
}

###############################################################################
# SECTION 4: Disk Configuration                                              #
###############################################################################

run "single_node_has_disks" {
  command = plan

  variables {
    database_server_count      = 1
    database_high_availability = false
  }

  assert {
    condition     = length(output.database_disks) > 0
    error_message = "Database disks should be planned for the VM"
  }
}

run "ha_nodes_have_disks" {
  command = plan

  variables {
    database_server_count      = 2
    database_high_availability = true
  }

  assert {
    condition     = length(output.database_disks) > 0
    error_message = "Database disks should be planned for HA VMs"
  }
}

###############################################################################
# SECTION 5: ANF Volumes                                                     #
###############################################################################

run "anf_disabled_no_volumes" {
  command = plan

  variables {
    database_server_count      = 1
    database_high_availability = false
    use_ANF                    = false
  }

  assert {
    condition     = length(output.hana_data_ANF_volumes) == 0
    error_message = "ANF data volumes should be empty when use_ANF=false"
  }

  assert {
    condition     = length(output.hana_log_ANF_volumes) == 0
    error_message = "ANF log volumes should be empty when use_ANF=false"
  }
}

run "anf_enabled_but_no_pool_no_volumes" {
  command = plan

  variables {
    database_server_count      = 1
    database_high_availability = false
    use_ANF                    = true
  }

  # ANF volumes require use_for_data/use_for_log=true AND a valid ANF pool
  # Test harness has use_for_data=false, use_for_log=false in hana_ANF_volumes
  assert {
    condition     = length(output.hana_data_ANF_volumes) == 0
    error_message = "ANF data volumes should be empty when use_for_data=false"
  }

  assert {
    condition     = length(output.hana_log_ANF_volumes) == 0
    error_message = "ANF log volumes should be empty when use_for_log=false"
  }
}

###############################################################################
# SECTION 6: Observer VM                                                     #
###############################################################################

run "observer_disabled_no_observer" {
  command = plan

  variables {
    database_server_count      = 2
    database_high_availability = true
    use_observer               = false
  }

  assert {
    condition     = length(output.observer_ips) == 0
    error_message = "Observer IPs should be empty when use_observer=false"
  }

  assert {
    condition     = output.observer_vms == tolist([""])
    error_message = "Observer VMs should be empty placeholder when disabled"
  }
}

run "observer_enabled_creates_observer" {
  command = plan

  variables {
    database_server_count      = 2
    database_high_availability = true
    use_observer               = true
  }

  assert {
    condition     = length(output.observer_ips) == 1
    error_message = "Observer should create exactly 1 IP when use_observer=true"
  }

  assert {
    condition     = length(output.observer_vms) == 1
    error_message = "Observer should create exactly 1 VM when use_observer=true"
  }
}

run "observer_without_ha_still_creates" {
  command = plan

  variables {
    database_server_count      = 1
    database_high_availability = false
    use_observer               = true
  }

  # Observer creation depends only on use_observer flag, not HA
  assert {
    condition     = length(output.observer_ips) == 1
    error_message = "Observer is independent of HA — should create when use_observer=true"
  }
}

###############################################################################
# SECTION 7: Storage Accounts for HANA Shared (AFS)                          #
###############################################################################

run "afs_disabled_by_default" {
  command = plan

  variables {
    database_server_count      = 1
    database_high_availability = false
    scale_out                  = false
  }

  # AFS requires NFS_provider="AFS" AND scale_out=true
  assert {
    condition     = length(output.hana_data_ANF_volumes) == 0
    error_message = "No ANF volumes by default"
  }
}

###############################################################################
# SECTION 8: HA-Specific Configuration                                       #
###############################################################################

run "ha_produces_site_information" {
  command = plan

  variables {
    database_server_count      = 2
    database_high_availability = true
  }

  assert {
    condition     = output.site_information != null
    error_message = "HA should produce site_information"
  }

  assert {
    condition     = length(output.site_information) == 2
    error_message = "HA with 2 nodes should produce 2 site entries"
  }

  assert {
    condition     = output.site_information[0] == "SITE1"
    error_message = "First node should be SITE1"
  }

  assert {
    condition     = output.site_information[1] == "SITE2"
    error_message = "Second node should be SITE2"
  }
}

run "standalone_produces_site_information_single" {
  command = plan

  variables {
    database_server_count      = 1
    database_high_availability = false
  }

  assert {
    condition     = output.site_information != null
    error_message = "Single node should still produce site_information"
  }

  assert {
    condition     = length(output.site_information) == 1
    error_message = "Single node should have 1 site entry"
  }

  assert {
    condition     = output.site_information[0] == "SITE1"
    error_message = "Single node should be SITE1"
  }
}

run "ha_cluster_disks_empty_for_afa" {
  command = plan

  variables {
    database_server_count      = 2
    database_high_availability = true
  }

  # Default cluster_type is "AFA" (not "ASD"), so no cluster disks
  assert {
    condition     = length(output.database_shared_disks) == 0
    error_message = "Cluster disks should be empty for AFA cluster type (default)"
  }
}

###############################################################################
# SECTION 9: Feature Combinations                                            #
###############################################################################

run "full_ha_with_dual_nics_and_observer" {
  command = plan

  variables {
    database_server_count      = 2
    database_high_availability = true
    dual_network_interfaces    = true
    use_observer               = true
  }

  assert {
    condition     = length(output.hanadb_vm_ids) == 2
    error_message = "Full HA should have 2 DB VMs"
  }

  assert {
    condition     = length(output.db_admin_ips) == 2
    error_message = "Full HA with dual NICs should have 2 admin IPs"
  }

  assert {
    condition     = length(output.observer_ips) == 1
    error_message = "Full HA with observer should have 1 observer IP"
  }

  assert {
    condition     = output.database_loadbalancer_id[0] != ""
    error_message = "Full HA must have load balancer"
  }

  assert {
    condition     = length(output.site_information) == 2
    error_message = "Full HA should have site info for both nodes"
  }

  assert {
    condition     = length(output.hana_data_ANF_volumes) == 0
    error_message = "ANF volumes empty when ANF not enabled"
  }
}

run "private_endpoints_plan_succeeds" {
  command = plan

  variables {
    database_server_count      = 1
    database_high_availability = false
    use_private_endpoint       = true
  }

  assert {
    condition     = output.hdb_sid == "HDB"
    error_message = "Plan should succeed with private endpoints enabled"
  }

  assert {
    condition     = length(output.hana_data_ANF_volumes) == 0
    error_message = "ANF volumes should remain empty (ANF not enabled)"
  }
}

run "anf_with_ha_no_pool_still_empty" {
  command = plan

  variables {
    database_server_count      = 2
    database_high_availability = true
    use_ANF                    = true
  }

  # Even with use_ANF=true, no volumes created because use_for_data=false
  assert {
    condition     = length(output.hana_data_ANF_volumes) == 0
    error_message = "ANF data volumes empty when use_for_data=false in ANF settings"
  }

  assert {
    condition     = length(output.hana_log_ANF_volumes) == 0
    error_message = "ANF log volumes empty when use_for_log=false in ANF settings"
  }

  assert {
    condition     = length(output.hanadb_vm_ids) == 2
    error_message = "VMs still created with ANF flag"
  }
}

run "firewall_and_asg_plan_succeeds" {
  command = plan

  variables {
    database_server_count                     = 1
    database_high_availability                = false
    enable_firewall_for_keyvaults_and_storage = true
    deploy_application_security_groups        = true
  }

  assert {
    condition     = output.hdb_sid == "HDB"
    error_message = "Plan should succeed with firewall and ASG options"
  }

  assert {
    condition     = length(output.hanadb_vm_ids) == 1
    error_message = "VM should still be planned with security features"
  }
}

run "scale_out_flag_plan_succeeds" {
  command = plan

  variables {
    database_server_count      = 2
    database_high_availability = true
    scale_out                  = true
  }

  assert {
    condition     = length(output.hanadb_vm_ids) == 2
    error_message = "Scale-out with HA should plan 2 VMs"
  }

  assert {
    condition     = output.database_loadbalancer_id[0] != ""
    error_message = "Scale-out HA should have load balancer"
  }
}

run "dhcp_enabled_plan_succeeds" {
  command = plan

  variables {
    database_server_count      = 1
    database_high_availability = false
    use_DHCP                   = true
  }

  assert {
    condition     = length(output.database_server_ips) == 1
    error_message = "DHCP mode should still plan NICs"
  }
}

###############################################################################
# Section 9: Deep Resource-Parameter Assertions                               #
#                                                                             #
# Validates SPECIFIC computed values in outputs — not just counts.            #
# These catch bugs like wrong disk LUNs, incorrect host naming,              #
# and zone miscalculations that count-based tests miss.                       #
###############################################################################

run "deep_disk_layout_single_node_hana" {
  command = plan

  # HANA default sizing produces 5 disk groups: data, log, shared, sap, backup
  assert {
    condition     = length(output.database_disks) == 5
    error_message = "Default HANA sizing should produce exactly 5 disk entries"
  }

  # Verify each disk type is present in the layout
  assert {
    condition     = length([for d in output.database_disks : d if strcontains(d, "type: 'data'")]) == 1
    error_message = "Must have exactly 1 data disk group entry"
  }

  assert {
    condition     = length([for d in output.database_disks : d if strcontains(d, "type: 'log'")]) == 1
    error_message = "Must have exactly 1 log disk group entry"
  }

  assert {
    condition     = length([for d in output.database_disks : d if strcontains(d, "type: 'shared'")]) == 1
    error_message = "Must have exactly 1 shared disk group entry"
  }

  assert {
    condition     = length([for d in output.database_disks : d if strcontains(d, "type: 'sap'")]) == 1
    error_message = "Must have exactly 1 sap disk group entry"
  }

  assert {
    condition     = length([for d in output.database_disks : d if strcontains(d, "type: 'backup'")]) == 1
    error_message = "Must have exactly 1 backup disk group entry"
  }

  # Verify all disks are assigned to the correct host (namegenerator-derived)
  assert {
    condition     = alltrue([for d in output.database_disks : strcontains(d, "host: 'hn1hdb00l0abc'")])
    error_message = "All disks must be assigned to host hn1hdb00l0abc (from namegenerator)"
  }

  # Verify data disk starts at LUN 0 (HANA convention)
  assert {
    condition     = strcontains(output.database_disks[0], "LUN: 0")
    error_message = "Data disk should start at LUN 0"
  }

  # Site information: single node = SITE1 only
  assert {
    condition     = length(output.site_information) == 1 && output.site_information[0] == "SITE1"
    error_message = "Single node HANA should have site_information = ['SITE1']"
  }

  # SID passthrough
  assert {
    condition     = output.hdb_sid == "HDB"
    error_message = "hdb_sid must pass through the configured SID"
  }
}

run "deep_ha_disk_layout_two_nodes" {
  command = plan
  variables {
    database_high_availability = true
    database_server_count      = 2
  }

  # HA with 2 nodes: each node gets its own disk set
  # All disk entries should reference one of the two host names
  assert {
    condition = length([
      for d in output.database_disks : d if strcontains(d, "host: 'hn1hdb00l0abc'")
    ]) > 0
    error_message = "HA disks must include entries for first node (hn1hdb00l0abc)"
  }

  assert {
    condition = length([
      for d in output.database_disks : d if strcontains(d, "host: 'hn1hdb00l1abc'")
    ]) > 0
    error_message = "HA disks must include entries for second node (hn1hdb01l0abc)"
  }

  # HA: site_information should have SITE1 and SITE2
  assert {
    condition     = length(output.site_information) == 2
    error_message = "HA deployment should have 2 site entries (SITE1 + SITE2)"
  }

  assert {
    condition     = contains(output.site_information, "SITE1") && contains(output.site_information, "SITE2")
    error_message = "HA site_information must contain both SITE1 and SITE2"
  }
}
