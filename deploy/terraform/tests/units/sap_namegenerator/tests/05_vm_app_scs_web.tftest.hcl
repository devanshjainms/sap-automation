## Section 5: VM Naming - App, SCS, Web Tiers
##
## Tests application-tier VM naming:
## - App: computer={sid}app{nn}{app_os}{random}, VM adds zonal marker from app_zones
## - SCS: computer={sid}scs{nn}{app_os}{random}, VM adds zonal marker from scs_zones
## - Web: computer={sid}web{nn}{app_os}{random}, VM uses web_sid (NOT sap_sid)
##
## DESIGN: web_computer_names use sap_sid, but web_server_vm_names use web_sid.
## This is intentional: hostnames (computer names) use the SAP system SID,
## while VM resource names use web_sid for the Web Dispatcher SID.

variables {
  environment                = "DEV"
  location                   = "eastus"
  sap_sid                    = "HN1"
  db_sid                     = "HDB"
  web_sid                    = "WEB"
  random_id                  = "abc123"
  management_vnet_name       = "DEP-VNET"
  sap_vnet_name              = "SAP-VNET"
  db_server_count            = 1
  app_server_count           = 2
  scs_server_count           = 1
  web_server_count           = 2
  deployer_vm_count          = 1
  iscsi_server_count         = 1
  db_ostype                  = "LINUX"
  app_ostype                 = "LINUX"
  anchor_ostype              = "LINUX"
  resource_offset            = 0
  database_high_availability = false
  use_zonal_markers          = true
  db_zones                   = []
  app_zones                  = []
  scs_zones                  = []
  web_zones                  = []
}

## ─────────────────────────────────────────────────────────────────────────────
## App Server Computer Names
## Formula: format("{sid}app{nn}{app_oscode}{random_3char}")
## app_oscode: LINUX→"l", WINDOWS→"w"
## ─────────────────────────────────────────────────────────────────────────────

run "app_computer_names_basic" {
  command = plan

  assert {
    condition     = output.naming.virtualmachine_names.APP_COMPUTERNAME[0] == "hn1app00labc"
    error_message = "App computer 0: {sid}app{nn}{os}{random}"
  }

  assert {
    condition     = output.naming.virtualmachine_names.APP_COMPUTERNAME[1] == "hn1app01labc"
    error_message = "App computer 1: index increments"
  }

  assert {
    condition     = length(output.naming.virtualmachine_names.APP_COMPUTERNAME) == 2
    error_message = "App count matches app_server_count=2"
  }
}

run "app_computer_name_windows" {
  command = plan

  variables {
    app_ostype = "WINDOWS"
  }

  assert {
    condition     = output.naming.virtualmachine_names.APP_COMPUTERNAME[0] == "hn1app00wabc"
    error_message = "Windows app: os_code='w'"
  }
}

run "app_computer_name_with_offset" {
  command = plan

  variables {
    resource_offset = 3
  }

  assert {
    condition     = output.naming.virtualmachine_names.APP_COMPUTERNAME[0] == "hn1app03labc"
    error_message = "App with offset=3: starts at 03"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## App Server VM Names (with zones)
## Without zones: same as computer name
## With zones: format("{sid}app_z{zone}_{nn}{os}{random}")
## ─────────────────────────────────────────────────────────────────────────────

run "app_vm_name_no_zones" {
  command = plan

  assert {
    condition     = output.naming.virtualmachine_names.APP_VMNAME[0] == "hn1app00labc"
    error_message = "App VM no zones: same as computer name"
  }
}

run "app_vm_name_with_zones" {
  command = plan

  variables {
    app_zones = ["1", "2"]
  }

  # Zone cycles: idx % len(zones)
  assert {
    condition     = output.naming.virtualmachine_names.APP_VMNAME[0] == "hn1app_z1_00labc"
    error_message = "App VM 0: zone 1 marker"
  }

  assert {
    condition     = output.naming.virtualmachine_names.APP_VMNAME[1] == "hn1app_z2_01labc"
    error_message = "App VM 1: zone 2 marker"
  }
}

run "app_vm_name_zones_wrap_around" {
  command = plan

  variables {
    app_zones        = ["1"]
    app_server_count = 3
  }

  # Single zone, 3 servers — all get zone 1
  assert {
    condition     = output.naming.virtualmachine_names.APP_VMNAME[0] == "hn1app_z1_00labc"
    error_message = "App VM 0: zone 1 (only zone)"
  }

  assert {
    condition     = output.naming.virtualmachine_names.APP_VMNAME[2] == "hn1app_z1_02labc"
    error_message = "App VM 2: wraps back to zone 1"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## SCS Server Computer Names
## Formula: format("{sid}scs{nn}{app_oscode}{random_3char}")
## Note: SCS uses app_oscode (not a separate scs_ostype)
## ─────────────────────────────────────────────────────────────────────────────

run "scs_computer_name_basic" {
  command = plan

  assert {
    condition     = output.naming.virtualmachine_names.SCS_COMPUTERNAME[0] == "hn1scs00labc"
    error_message = "SCS computer: {sid}scs{nn}{app_os}{random}"
  }

  assert {
    condition     = length(output.naming.virtualmachine_names.SCS_COMPUTERNAME) == 1
    error_message = "SCS count matches scs_server_count=1"
  }
}

run "scs_vm_name_with_zones" {
  command = plan

  variables {
    scs_zones        = ["2", "3"]
    scs_server_count = 2
  }

  assert {
    condition     = output.naming.virtualmachine_names.SCS_VMNAME[0] == "hn1scs_z2_00labc"
    error_message = "SCS VM 0: zone 2"
  }

  assert {
    condition     = output.naming.virtualmachine_names.SCS_VMNAME[1] == "hn1scs_z3_01labc"
    error_message = "SCS VM 1: zone 3"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Web Dispatcher Computer Names
## Formula: format("{sap_sid}web{nn}{app_oscode}{random_3char}")
## DESIGN: Computer names use sap_sid, NOT web_sid
## ─────────────────────────────────────────────────────────────────────────────

run "web_computer_name_uses_sap_sid" {
  command = plan

  # DESIGN: web_computer_names uses lower(var.sap_sid) = "hn1", not web_sid
  assert {
    condition     = output.naming.virtualmachine_names.WEB_COMPUTERNAME[0] == "hn1web00labc"
    error_message = "Web computer name uses sap_sid (hn1), not web_sid"
  }

  assert {
    condition     = output.naming.virtualmachine_names.WEB_COMPUTERNAME[1] == "hn1web01labc"
    error_message = "Web computer 1: increments index"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Web Dispatcher VM Names
## Formula (with zones): format("{web_sid}web_z{zone}_{nn}{app_os}{random}")
## Formula (no zones): format("{web_sid}web{nn}{app_os}{random}")
## DESIGN: VM names use web_sid, creating an INCONSISTENCY with computer names
## ─────────────────────────────────────────────────────────────────────────────

run "web_vm_name_no_zones_uses_web_sid" {
  command = plan

  # DESIGN: web_server_vm_names uses lower(var.web_sid) = "web"
  assert {
    condition     = output.naming.virtualmachine_names.WEB_VMNAME[0] == "webweb00labc"
    error_message = "Web VM no zones uses web_sid: 'web' + 'web' (sid + tier)"
  }
}

run "web_vm_name_with_zones_uses_web_sid" {
  command = plan

  variables {
    web_zones = ["2"]
  }

  # format("{web_sid}web_z{zone}_{nn}{os}{random}")
  assert {
    condition     = output.naming.virtualmachine_names.WEB_VMNAME[0] == "webweb_z2_00labc"
    error_message = "Web VM with zones: {web_sid}web_z{zone}_{nn}{os}{random}"
  }
}

run "web_vm_name_custom_web_sid" {
  command = plan

  variables {
    web_sid = "WD1"
  }

  assert {
    condition     = output.naming.virtualmachine_names.WEB_VMNAME[0] == "wd1web00labc"
    error_message = "Custom web_sid 'WD1' appears in VM name: wd1web..."
  }

  # Computer name still uses sap_sid
  assert {
    condition     = output.naming.virtualmachine_names.WEB_COMPUTERNAME[0] == "hn1web00labc"
    error_message = "Web computer name still uses sap_sid even with web_sid override"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Zero App/SCS/Web Counts
## ─────────────────────────────────────────────────────────────────────────────

run "zero_app_count" {
  command = plan

  variables {
    app_server_count = 0
  }

  assert {
    condition     = length(output.naming.virtualmachine_names.APP_COMPUTERNAME) == 0
    error_message = "Zero app count → empty app names"
  }

  assert {
    condition     = length(output.naming.virtualmachine_names.APP_VMNAME) == 0
    error_message = "Zero app count → empty app VM names"
  }

  assert {
    condition     = length(output.naming.virtualmachine_names.APP_SECONDARY_DNSNAME) == 0
    error_message = "Zero app count → empty app secondary DNS"
  }
}

run "zero_scs_count" {
  command = plan

  variables {
    scs_server_count = 0
  }

  assert {
    condition     = length(output.naming.virtualmachine_names.SCS_COMPUTERNAME) == 0
    error_message = "Zero SCS count → empty SCS names"
  }
}

run "zero_web_count" {
  command = plan

  variables {
    web_server_count = 0
  }

  assert {
    condition     = length(output.naming.virtualmachine_names.WEB_COMPUTERNAME) == 0
    error_message = "Zero web count → empty web names"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Zonal Markers Disabled
## use_zonal_markers=false → even with zones defined, VM names omit markers
## ─────────────────────────────────────────────────────────────────────────────

run "zonal_markers_disabled_app_scs_web" {
  command = plan

  variables {
    use_zonal_markers = false
    app_zones         = ["1", "2"]
    scs_zones         = ["1"]
    web_zones         = ["2"]
  }

  assert {
    condition     = output.naming.virtualmachine_names.APP_VMNAME[0] == "hn1app00labc"
    error_message = "App VM: no zone marker when disabled"
  }

  assert {
    condition     = output.naming.virtualmachine_names.SCS_VMNAME[0] == "hn1scs00labc"
    error_message = "SCS VM: no zone marker when disabled"
  }

  assert {
    condition     = output.naming.virtualmachine_names.WEB_VMNAME[0] == "webweb00labc"
    error_message = "Web VM: no zone marker when disabled"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Empty SID Edge Case
## ─────────────────────────────────────────────────────────────────────────────

run "empty_sid_app_scs_web" {
  command = plan

  variables {
    sap_sid = ""
    web_sid = ""
  }

  assert {
    condition     = output.naming.virtualmachine_names.APP_COMPUTERNAME[0] == "app00labc"
    error_message = "Empty SID: app name starts with tier directly"
  }

  assert {
    condition     = output.naming.virtualmachine_names.SCS_COMPUTERNAME[0] == "scs00labc"
    error_message = "Empty SID: scs name starts with tier directly"
  }

  assert {
    condition     = output.naming.virtualmachine_names.WEB_COMPUTERNAME[0] == "web00labc"
    error_message = "Empty SID: web computer uses sap_sid (empty)"
  }

  assert {
    condition     = output.naming.virtualmachine_names.WEB_VMNAME[0] == "web00labc"
    error_message = "Empty web_sid: web VM name starts with tier"
  }
}
