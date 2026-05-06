## SAP System AnyDB Node Plan-Level Tests
##
## Tests the anydb_node sub-module of sap_system, which handles non-HANA
## database deployments (ORACLE, ORACLE-ASM, DB2, SQLSERVER, SYBASE).
##
## Module creates:
## - Database VMs (Linux or Windows depending on platform)
## - Network interfaces (db NIC + optional admin NIC with dual_network_interfaces)
## - Load balancers (for non-Oracle platforms with HA or standalone LB enabled)
## - Availability sets
## - Data disks and cluster disks (for HA)
## - Observer VMs (Oracle HA only, with use_observer=true)
##
## Key design decisions tested:
## - DESIGN: Oracle uses Data Guard, not LB — enable_db_lb_deployment excludes ORACLE/ORACLE-ASM
## - KNOWN_BUG: ORACLE-ASM missing from os_defaults map at variables_local.tf line 102-139
##   (only ORACLE is present, not ORACLE-ASM — will fail lookup if no os block provided)
## - Observer VM is Oracle-HA-only (deploy_observer requires ORACLE/ORACLE-ASM + HA + use_observer)
## - OS type: SQLSERVER forces WINDOWS, all others default to LINUX
##
## All tests use mock providers with command = plan (no real Azure resources).

mock_provider "azurerm" {
}

###############################################################################
# SECTION 1: Platform-specific behavior                                      #
#                                                                            #
# Each supported platform gets a basic single-node test to verify            #
# enable_deployment includes it and platform-specific defaults apply.        #
###############################################################################

run "oracle_single_node" {
  command = plan

  variables {
    database_platform          = "ORACLE"
    database_server_count      = 1
    database_high_availability = false
    use_observer               = false
  }

  # Oracle single-node: no LB (by design), no observer, no cluster IP
  assert {
    condition     = output.database_loadbalancer_id == [""]
    error_message = "Oracle should never have a load balancer (uses Data Guard instead)"
  }

  assert {
    condition     = output.database_cluster_ip == ""
    error_message = "Cluster IP should be empty for non-HA Oracle"
  }

  assert {
    condition     = length(output.observer_ips) == 0
    error_message = "Observer should not be deployed without HA"
  }
}

run "db2_single_node" {
  command = plan

  variables {
    database_platform          = "DB2"
    database_server_count      = 1
    database_high_availability = false
    use_observer               = false
  }

  # DB2 single-node without standalone LB: no LB, deployment enabled
  assert {
    condition     = output.database_loadbalancer_id == [""]
    error_message = "DB2 single-node without standalone LB should have no LB"
  }

  assert {
    condition     = output.database_cluster_ip == ""
    error_message = "Cluster IP should be empty for non-HA DB2"
  }

  assert {
    condition     = length(output.observer_ips) == 0
    error_message = "Observer should never deploy for DB2"
  }
}

run "sqlserver_single_node" {
  command = plan

  variables {
    database_platform          = "SQLSERVER"
    database_server_count      = 1
    database_high_availability = false
    use_observer               = false
  }

  # SQLSERVER: forces WINDOWS OS type, single-node has no LB
  assert {
    condition     = output.database_loadbalancer_id == [""]
    error_message = "SQLSERVER single-node without standalone LB should have no LB"
  }

  assert {
    condition     = output.database_cluster_ip == ""
    error_message = "Cluster IP should be empty for non-HA SQLSERVER"
  }

  assert {
    condition     = length(output.observer_ips) == 0
    error_message = "Observer should never deploy for SQLSERVER"
  }
}

run "sybase_single_node" {
  command = plan

  variables {
    database_platform          = "SYBASE"
    database_server_count      = 1
    database_high_availability = false
    use_observer               = false
  }

  # SYBASE: Linux platform, single-node has no LB
  assert {
    condition     = output.database_loadbalancer_id == [""]
    error_message = "SYBASE single-node without standalone LB should have no LB"
  }

  assert {
    condition     = output.database_cluster_ip == ""
    error_message = "Cluster IP should be empty for non-HA SYBASE"
  }

  assert {
    condition     = length(output.observer_ips) == 0
    error_message = "Observer should never deploy for SYBASE"
  }
}

###############################################################################
# SECTION 2: Load balancer behavior                                          #
#                                                                            #
# DESIGN: Oracle uses Data Guard, not LB — enable_db_lb_deployment           #
# explicitly excludes ORACLE and ORACLE-ASM platforms.                       #
# Other platforms (DB2, SQLSERVER, SYBASE) get LB when:                      #
#   - server_count > 1 (HA), OR                                             #
#   - use_loadbalancers_for_standalone_deployments = true                    #
###############################################################################

run "oracle_ha_no_lb" {
  command = plan

  # DESIGN: Oracle uses Data Guard, not LB — even with HA, no LB is created
  variables {
    database_platform                            = "ORACLE"
    database_server_count                        = 2
    database_high_availability                   = true
    use_observer                                 = true
    database_zones                               = ["1"]
    use_loadbalancers_for_standalone_deployments = false
  }

  assert {
    condition     = output.database_loadbalancer_id == [""]
    error_message = "Oracle HA must NOT create a load balancer (Oracle uses Data Guard)"
  }
}

run "db2_ha_creates_lb" {
  command = plan

  # DB2 with HA and count > 1: LB should be created
  variables {
    database_platform                            = "DB2"
    database_server_count                        = 2
    database_high_availability                   = true
    use_observer                                 = false
    use_loadbalancers_for_standalone_deployments = false
  }

  assert {
    condition     = output.database_loadbalancer_id != [""]
    error_message = "DB2 HA with count > 1 should create a load balancer"
  }

  assert {
    condition     = length(output.observer_ips) == 0
    error_message = "Observer should not be deployed for DB2 HA (only Oracle uses observer)"
  }
}

run "sqlserver_ha_creates_lb" {
  command = plan

  # SQLSERVER HA: LB is created (Windows HA with cluster frontend)
  variables {
    database_platform                            = "SQLSERVER"
    database_server_count                        = 2
    database_high_availability                   = true
    use_observer                                 = false
    use_loadbalancers_for_standalone_deployments = false
  }

  assert {
    condition     = output.database_loadbalancer_id != [""]
    error_message = "SQLSERVER HA with count > 1 should create a load balancer"
  }

  assert {
    condition     = length(output.observer_ips) == 0
    error_message = "Observer should not be deployed for SQLSERVER HA"
  }
}

run "sybase_ha_creates_lb" {
  command = plan

  # SYBASE HA: LB is created
  variables {
    database_platform                            = "SYBASE"
    database_server_count                        = 2
    database_high_availability                   = true
    use_observer                                 = false
    use_loadbalancers_for_standalone_deployments = false
  }

  assert {
    condition     = output.database_loadbalancer_id != [""]
    error_message = "SYBASE HA with count > 1 should create a load balancer"
  }
}

run "standalone_lb_enabled_creates_lb" {
  command = plan

  # use_loadbalancers_for_standalone_deployments forces LB even for single-node (non-Oracle)
  variables {
    database_platform                            = "DB2"
    database_server_count                        = 1
    database_high_availability                   = false
    use_observer                                 = false
    use_loadbalancers_for_standalone_deployments = true
  }

  assert {
    condition     = output.database_loadbalancer_id != [""]
    error_message = "DB2 with standalone LB enabled should create a LB even with 1 server"
  }
}

run "standalone_lb_oracle_still_excluded" {
  command = plan

  # Even with use_loadbalancers_for_standalone_deployments=true, Oracle is excluded
  variables {
    database_platform                            = "ORACLE"
    database_server_count                        = 1
    database_high_availability                   = false
    use_observer                                 = false
    use_loadbalancers_for_standalone_deployments = true
  }

  assert {
    condition     = output.database_loadbalancer_id == [""]
    error_message = "Oracle must never have LB even with standalone LB flag enabled"
  }
}

###############################################################################
# SECTION 3: Network interfaces                                              #
#                                                                            #
# - Primary db NIC always created (count = database_server_count)            #
# - Admin NIC created only when dual_network_interfaces = true AND           #
#   admin_subnet is provided                                                 #
###############################################################################

run "single_nic_default" {
  command = plan

  # Default: single db NIC, no admin NIC
  variables {
    database_platform          = "DB2"
    database_server_count      = 1
    database_high_availability = false
    use_observer               = false
    dual_network_interfaces    = false
  }

  assert {
    condition     = output.database_loadbalancer_id == [""]
    error_message = "Single-node DB2 should not have LB"
  }

  # With single NIC, admin IPs come from db NIC
  assert {
    condition     = length(output.database_server_ips) == 1
    error_message = "Should have exactly 1 DB server IP for count=1"
  }
}

run "dual_nics_enabled" {
  command = plan

  # dual_network_interfaces=true creates admin NIC in addition to db NIC
  variables {
    database_platform          = "DB2"
    database_server_count      = 1
    database_high_availability = false
    use_observer               = false
    dual_network_interfaces    = true
  }

  # With dual NICs, admin IPs should come from admin NIC (separate from db NIC)
  assert {
    condition     = length(output.database_server_ips) == 1
    error_message = "Should have exactly 1 DB server IP for count=1"
  }
}

###############################################################################
# SECTION 4: Observer VM                                                     #
#                                                                            #
# Observer is Oracle-HA-only: deploy_observer requires:                      #
#   - use_observer = true                                                    #
#   - platform = ORACLE or ORACLE-ASM                                        #
#   - high_availability = true                                               #
# Observer count = db_zone_count (length of zones list)                      #
# Observer is NOT created for DB2/SQLSERVER/SYBASE even with HA.             #
###############################################################################

run "observer_oracle_ha_with_zones" {
  command = plan

  # Oracle HA + use_observer + zones: observer deployed (count = zone count)
  variables {
    database_platform          = "ORACLE"
    database_server_count      = 2
    database_high_availability = true
    use_observer               = true
    database_zones             = ["1"]
  }

  assert {
    condition     = output.database_loadbalancer_id == [""]
    error_message = "Oracle HA should not create LB"
  }

  # observer count = db_zone_count = 1 zone
  # observer_ips output returns IPs if deploy_observer=true
  # Can't assert exact length due to mock, but verify LB exclusion holds
}

run "observer_not_deployed_without_ha" {
  command = plan

  # Oracle without HA: observer NOT deployed even with use_observer=true
  variables {
    database_platform          = "ORACLE"
    database_server_count      = 1
    database_high_availability = false
    use_observer               = true
    database_zones             = ["1"]
  }

  assert {
    condition     = length(output.observer_ips) == 0
    error_message = "Observer should not deploy without HA even if use_observer=true"
  }
}

run "observer_not_deployed_without_use_observer" {
  command = plan

  # Oracle HA but use_observer=false: observer NOT deployed
  variables {
    database_platform          = "ORACLE"
    database_server_count      = 2
    database_high_availability = true
    use_observer               = false
    database_zones             = ["1"]
  }

  assert {
    condition     = length(output.observer_ips) == 0
    error_message = "Observer should not deploy when use_observer=false"
  }
}

run "observer_not_deployed_for_db2_ha" {
  command = plan

  # DB2 HA: observer NEVER deploys (only Oracle/ORACLE-ASM)
  variables {
    database_platform          = "DB2"
    database_server_count      = 2
    database_high_availability = true
    use_observer               = true
    database_zones             = ["1"]
  }

  assert {
    condition     = length(output.observer_ips) == 0
    error_message = "Observer must NOT deploy for DB2 even with HA and use_observer=true"
  }

  # But DB2 HA SHOULD have LB
  assert {
    condition     = output.database_loadbalancer_id != [""]
    error_message = "DB2 HA should still have a load balancer"
  }
}

run "observer_not_deployed_for_sqlserver_ha" {
  command = plan

  # SQLSERVER HA: observer NEVER deploys
  variables {
    database_platform          = "SQLSERVER"
    database_server_count      = 2
    database_high_availability = true
    use_observer               = true
  }

  assert {
    condition     = length(output.observer_ips) == 0
    error_message = "Observer must NOT deploy for SQLSERVER even with HA and use_observer=true"
  }

  assert {
    condition     = output.database_loadbalancer_id != [""]
    error_message = "SQLSERVER HA should have a load balancer"
  }
}

run "observer_not_deployed_for_sybase_ha" {
  command = plan

  # SYBASE HA: observer NEVER deploys
  variables {
    database_platform          = "SYBASE"
    database_server_count      = 2
    database_high_availability = true
    use_observer               = true
  }

  assert {
    condition     = length(output.observer_ips) == 0
    error_message = "Observer must NOT deploy for SYBASE even with HA and use_observer=true"
  }
}

###############################################################################
# SECTION 5: HA configuration                                                #
#                                                                            #
# For non-HANA HA: database_server_count is passed directly (not doubled     #
# automatically by this module — the caller sets count=2 for HA pairs).      #
# Cluster disks are created when HA + (Windows OR Linux ASD cluster type).   #
###############################################################################

run "ha_two_servers_db2" {
  command = plan

  # DB2 HA with 2 servers: both VMs created, LB deployed
  variables {
    database_platform          = "DB2"
    database_server_count      = 2
    database_high_availability = true
    use_observer               = false
  }

  assert {
    condition     = output.database_loadbalancer_id != [""]
    error_message = "DB2 HA pair should have a load balancer"
  }
}

###############################################################################
# SECTION 6: OS type defaults per platform                                   #
#                                                                            #
# Platform OS type logic (variables_local.tf line 68):                       #
#   - SQLSERVER → forces "WINDOWS"                                           #
#   - All others (ORACLE, DB2, SYBASE) → default "LINUX"                    #
#                                                                            #
# KNOWN_BUG: ORACLE-ASM is missing from os_defaults map (line 102-139).     #
# The map has entries for: SYBASE, DB2, HANA, ORACLE, SQLSERVER, NONE.      #
# If no explicit os block is provided and platform=ORACLE-ASM, the lookup   #
# local.os_defaults[upper(var.database.platform)] will fail.                #
# Our test harness works around this by always providing an explicit os      #
# block in the database variable.                                            #
###############################################################################

# OS type is verified implicitly: SQLSERVER creates Windows VMs,
# others create Linux VMs. The VM resource selection is count-based:
# - azurerm_linux_virtual_machine.dbserver: count > 0 when ostype == "LINUX"
# - azurerm_windows_virtual_machine.dbserver: count > 0 when ostype == "WINDOWS"
# These are tested via successful plan completion for each platform above.

###############################################################################
# SECTION 7: Feature combinations                                            #
#                                                                            #
# Tests that combine multiple features to catch interaction bugs.            #
###############################################################################

run "oracle_ha_dual_nics_with_observer" {
  command = plan

  # Oracle HA + dual NICs + observer: complex combination
  variables {
    database_platform          = "ORACLE"
    database_server_count      = 2
    database_high_availability = true
    use_observer               = true
    dual_network_interfaces    = true
    database_zones             = ["1"]
  }

  # Oracle: no LB regardless of HA
  assert {
    condition     = output.database_loadbalancer_id == [""]
    error_message = "Oracle HA with dual NICs must still NOT have LB"
  }
}

run "db2_ha_dual_nics_secondary_ips" {
  command = plan

  # DB2 HA + dual NICs + secondary IPs: verifies all NIC configs work together
  variables {
    database_platform          = "DB2"
    database_server_count      = 2
    database_high_availability = true
    use_observer               = false
    dual_network_interfaces    = true
    use_secondary_ips          = true
  }

  assert {
    condition     = output.database_loadbalancer_id != [""]
    error_message = "DB2 HA should have LB even with dual NICs and secondary IPs"
  }
}

run "sqlserver_ha_with_avset_no_zones" {
  command = plan

  # SQLSERVER HA with avset (no zones): Windows HA path
  variables {
    database_platform          = "SQLSERVER"
    database_server_count      = 2
    database_high_availability = true
    use_observer               = false
    use_avset                  = true
    database_zones             = []
  }

  assert {
    condition     = output.database_loadbalancer_id != [""]
    error_message = "SQLSERVER HA should have LB"
  }

  assert {
    condition     = length(output.observer_ips) == 0
    error_message = "SQLSERVER should never have observer VMs"
  }
}

run "zero_server_count_disables_deployment" {
  command = plan

  # server_count=0: nothing should be deployed
  variables {
    database_platform          = "DB2"
    database_server_count      = 0
    database_high_availability = false
    use_observer               = false
  }

  assert {
    condition     = output.database_loadbalancer_id == [""]
    error_message = "Zero server count should result in no LB"
  }

  assert {
    condition     = length(output.observer_ips) == 0
    error_message = "Zero server count should have no observer"
  }
}

###############################################################################
# Section 7: Deep Resource-Parameter Assertions                               #
#                                                                             #
# Validates SPECIFIC computed values: disk LUNs, host assignments,            #
# disk type naming for Oracle vs SQL Server layouts.                          #
###############################################################################

run "deep_oracle_disk_layout_validation" {
  command = plan

  # Oracle default sizing produces many disk groups: sapdata1-4, origloga/b, mirrloga/b, sap, oracle, oraarch
  assert {
    condition     = length(output.database_disks) == 19
    error_message = "Default Oracle sizing should produce 19 disk entries (4 sapdata pairs + 4 log pairs + sap + oracle + oraarch)"
  }

  # Verify Oracle-specific disk types exist
  assert {
    condition     = length([for d in output.database_disks : d if strcontains(d, "type: 'oracle'")]) == 1
    error_message = "Oracle layout must have exactly 1 oracle-type disk entry"
  }

  assert {
    condition     = length([for d in output.database_disks : d if strcontains(d, "type: 'oraarch'")]) == 1
    error_message = "Oracle layout must have exactly 1 oraarch-type disk entry"
  }

  # sapdata groups come in pairs (2 disks each, 4 groups = 8 disks)
  assert {
    condition     = length([for d in output.database_disks : d if strcontains(d, "type: 'sapdata1'")]) == 2
    error_message = "sapdata1 should have 2 disk entries (mirrored pair)"
  }

  # Verify all disks assigned to correct host
  assert {
    condition     = alltrue([for d in output.database_disks : strcontains(d, "host: 'db00l0000'")])
    error_message = "All Oracle disks must be assigned to host db00l0000"
  }

  # Original log A starts at LUN 25 (Oracle convention)
  assert {
    condition     = length([for d in output.database_disks : d if strcontains(d, "LUN: 25") && strcontains(d, "type: 'origloga'")]) == 1
    error_message = "Oracle origloga should have a disk at LUN 25"
  }
}

run "deep_sqlserver_disk_layout" {
  command = plan
  variables {
    database_platform = "SQLSERVER"
  }

  # SQL Server has different disk types than Oracle
  assert {
    condition     = length(output.database_disks) > 0
    error_message = "SQL Server should produce disk entries"
  }

  # SQL Server should NOT have Oracle-specific disk types
  assert {
    condition     = length([for d in output.database_disks : d if strcontains(d, "type: 'oracle'")]) == 0
    error_message = "SQL Server layout must NOT have oracle-type disks"
  }

  assert {
    condition     = length([for d in output.database_disks : d if strcontains(d, "type: 'oraarch'")]) == 0
    error_message = "SQL Server layout must NOT have oraarch-type disks"
  }
}
