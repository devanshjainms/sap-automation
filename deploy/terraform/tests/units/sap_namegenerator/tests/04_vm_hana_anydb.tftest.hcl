## Section 4: VM Naming - HANA and AnyDB
##
## Tests database VM naming for both HANA and AnyDB platforms:
## - HANA computer names: {sid}d{dbsid}{nn}l{ha_flag}{random_2char}
## - HANA VM names: {sid}d{dbsid}[_z{zone}_]{nn}l{ha_flag}{random_3char}
## - AnyDB computer names: {sid}db{nn}{os}{ha_flag}{random_3char}
## - AnyDB VM names: {sid}db[_z{zone}_]{nn}{os}{ha_flag}{random_3char}
##
## Key behaviors:
## - HA = true → concat(primary, ha) names; HA names use reversed zone order
## - scale_out = true (with HA) → interleaved pairs: db_server_count * 2
## - Zones affect VM names only (not computer names)
## - use_zonal_markers = false disables zone markers even with zones defined

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
  app_server_count           = 1
  scs_server_count           = 1
  web_server_count           = 1
  deployer_vm_count          = 1
  iscsi_server_count         = 1
  db_ostype                  = "LINUX"
  app_ostype                 = "LINUX"
  anchor_ostype              = "LINUX"
  resource_offset            = 0
  database_high_availability = false
  use_zonal_markers          = true
  scale_out                  = false
  db_zones                   = []
  app_zones                  = []
  scs_zones                  = []
  web_zones                  = []
}

## ─────────────────────────────────────────────────────────────────────────────
## HANA Computer Names (no HA, no zones)
## Formula: format("{sid}d{dbsid}{nn}l{0}{random_2char}")
## random_2char = substr(random_id_vm_verified, 0, 2) = substr("abc", 0, 2) = "ab"
## ─────────────────────────────────────────────────────────────────────────────

run "hana_computer_name_basic" {
  command = plan

  # format("hn1dhdb%02dl%d%s", 0+0, 0, "ab") = "hn1dhdb00l0ab"
  assert {
    condition     = output.naming.virtualmachine_names.HANA_COMPUTERNAME[0] == "hn1dhdb00l0ab"
    error_message = "HANA computer name: {sid}d{dbsid}{nn}l{ha_flag=0}{random_2char}"
  }

  assert {
    condition     = length(output.naming.virtualmachine_names.HANA_COMPUTERNAME) == 1
    error_message = "Without HA, HANA count = db_server_count (1)"
  }
}

run "hana_computer_name_multiple_servers" {
  command = plan

  variables {
    db_server_count = 3
  }

  assert {
    condition     = output.naming.virtualmachine_names.HANA_COMPUTERNAME[0] == "hn1dhdb00l0ab"
    error_message = "First HANA: index 00"
  }

  assert {
    condition     = output.naming.virtualmachine_names.HANA_COMPUTERNAME[1] == "hn1dhdb01l0ab"
    error_message = "Second HANA: index 01"
  }

  assert {
    condition     = output.naming.virtualmachine_names.HANA_COMPUTERNAME[2] == "hn1dhdb02l0ab"
    error_message = "Third HANA: index 02"
  }
}

run "hana_computer_name_with_resource_offset" {
  command = plan

  variables {
    resource_offset = 5
  }

  assert {
    condition     = output.naming.virtualmachine_names.HANA_COMPUTERNAME[0] == "hn1dhdb05l0ab"
    error_message = "Resource offset shifts HANA index to 05"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## HANA VM Names (no HA)
## Without zones: same format as computer name but with full 3-char random
## With zones: format("{sid}d{dbsid}_z{zone}_{nn}l{ha_flag}{random_3char}")
## ─────────────────────────────────────────────────────────────────────────────

run "hana_vm_name_no_zones" {
  command = plan

  # format("hn1dhdb%02dl%d%s", 0, 0, "abc") = "hn1dhdb00l0abc"
  assert {
    condition     = output.naming.virtualmachine_names.HANA_VMNAME[0] == "hn1dhdb00l0abc"
    error_message = "HANA VM no zones: {sid}d{dbsid}{nn}l{0}{random_3char}"
  }
}

run "hana_vm_name_with_zones" {
  command = plan

  variables {
    db_zones        = ["1", "2"]
    db_server_count = 2
  }

  # format("hn1dhdb_z%s_%02dl%d%s", zone[idx%2], idx+0, 0, "abc")
  assert {
    condition     = output.naming.virtualmachine_names.HANA_VMNAME[0] == "hn1dhdb_z1_00l0abc"
    error_message = "HANA VM zone 1: _z1_ marker"
  }

  assert {
    condition     = output.naming.virtualmachine_names.HANA_VMNAME[1] == "hn1dhdb_z2_01l0abc"
    error_message = "HANA VM zone 2: _z2_ marker"
  }
}

run "hana_vm_name_zones_disabled" {
  command = plan

  variables {
    db_zones          = ["1", "2"]
    use_zonal_markers = false
  }

  # Even with zones defined, use_zonal_markers=false removes markers
  assert {
    condition     = output.naming.virtualmachine_names.HANA_VMNAME[0] == "hn1dhdb00l0abc"
    error_message = "With use_zonal_markers=false, no zone marker despite zones being defined"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## HANA with HA (no scale-out)
## HA = true → concat(primary_names, ha_names)
## Primary: ha_flag=0, uses db_zones order
## HA: ha_flag=1, uses ha_zones = reverse(db_zones)
## Total count: db_server_count * 2
## ─────────────────────────────────────────────────────────────────────────────

run "hana_ha_doubles_computer_names" {
  command = plan

  variables {
    database_high_availability = true
    db_server_count            = 2
  }

  assert {
    condition     = length(output.naming.virtualmachine_names.HANA_COMPUTERNAME) == 4
    error_message = "HA doubles: 2 primary + 2 HA = 4 total"
  }

  # Primary names (first half): l0
  assert {
    condition     = output.naming.virtualmachine_names.HANA_COMPUTERNAME[0] == "hn1dhdb00l0ab"
    error_message = "Primary 0: ha_flag=0"
  }

  assert {
    condition     = output.naming.virtualmachine_names.HANA_COMPUTERNAME[1] == "hn1dhdb01l0ab"
    error_message = "Primary 1: ha_flag=0"
  }

  # HA names (second half): l1
  assert {
    condition     = output.naming.virtualmachine_names.HANA_COMPUTERNAME[2] == "hn1dhdb00l1ab"
    error_message = "HA 0: same index 00 but ha_flag=1"
  }

  assert {
    condition     = output.naming.virtualmachine_names.HANA_COMPUTERNAME[3] == "hn1dhdb01l1ab"
    error_message = "HA 1: same index 01 but ha_flag=1"
  }
}

run "hana_ha_vm_names_with_zones_use_reversed_zones" {
  command = plan

  variables {
    database_high_availability = true
    db_zones                   = ["1", "2"]
    db_server_count            = 2
  }

  # Primary uses db_zones order: 1, 2
  assert {
    condition     = output.naming.virtualmachine_names.HANA_VMNAME[0] == "hn1dhdb_z1_00l0abc"
    error_message = "Primary VM 0: zone 1"
  }

  assert {
    condition     = output.naming.virtualmachine_names.HANA_VMNAME[1] == "hn1dhdb_z2_01l0abc"
    error_message = "Primary VM 1: zone 2"
  }

  # HA uses ha_zones = reverse(db_zones) = ["2", "1"]
  assert {
    condition     = output.naming.virtualmachine_names.HANA_VMNAME[2] == "hn1dhdb_z2_00l1abc"
    error_message = "HA VM 0: reversed zones → zone 2"
  }

  assert {
    condition     = output.naming.virtualmachine_names.HANA_VMNAME[3] == "hn1dhdb_z1_01l1abc"
    error_message = "HA VM 1: reversed zones → zone 1"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## HANA Scale-Out (HA + scale_out)
## Interleaved pairs: floor(idx/2) for server index, idx%2 for ha_flag
## Total count: db_server_count * 2
## Computer names: {sid}d{dbsid}{floor(idx/2)+offset}l{idx%2}{random_2char}
## ─────────────────────────────────────────────────────────────────────────────

run "hana_scaleout_interleaved_computer_names" {
  command = plan

  variables {
    database_high_availability = true
    scale_out                  = true
    db_server_count            = 2
  }

  assert {
    condition     = length(output.naming.virtualmachine_names.HANA_COMPUTERNAME) == 4
    error_message = "Scale-out: db_server_count * 2 = 4 entries"
  }

  # Interleaved: (idx=0: floor(0/2)=0, 0%2=0), (idx=1: floor(1/2)=0, 1%2=1), etc.
  assert {
    condition     = output.naming.virtualmachine_names.HANA_COMPUTERNAME[0] == "hn1dhdb00l0ab"
    error_message = "Scale-out idx=0: server 00, primary (l0)"
  }

  assert {
    condition     = output.naming.virtualmachine_names.HANA_COMPUTERNAME[1] == "hn1dhdb00l1ab"
    error_message = "Scale-out idx=1: server 00, standby (l1)"
  }

  assert {
    condition     = output.naming.virtualmachine_names.HANA_COMPUTERNAME[2] == "hn1dhdb01l0ab"
    error_message = "Scale-out idx=2: server 01, primary (l0)"
  }

  assert {
    condition     = output.naming.virtualmachine_names.HANA_COMPUTERNAME[3] == "hn1dhdb01l1ab"
    error_message = "Scale-out idx=3: server 01, standby (l1)"
  }
}

run "hana_scaleout_vm_names_with_zones" {
  command = plan

  variables {
    database_high_availability = true
    scale_out                  = true
    db_server_count            = 2
    db_zones                   = ["1", "2"]
  }

  # VM names with zones: zone cycles through db_zones[idx % len(zones)]
  # idx=0: zone=1, server=0, ha=0
  assert {
    condition     = output.naming.virtualmachine_names.HANA_VMNAME[0] == "hn1dhdb_z1_00l0abc"
    error_message = "Scale-out VM idx=0: zone 1, server 00, l0"
  }

  # idx=1: zone=2, server=0, ha=1
  assert {
    condition     = output.naming.virtualmachine_names.HANA_VMNAME[1] == "hn1dhdb_z2_00l1abc"
    error_message = "Scale-out VM idx=1: zone 2, server 00, l1"
  }

  # idx=2: zone=1, server=1, ha=0
  assert {
    condition     = output.naming.virtualmachine_names.HANA_VMNAME[2] == "hn1dhdb_z1_01l0abc"
    error_message = "Scale-out VM idx=2: zone 1, server 01, l0"
  }

  # idx=3: zone=2, server=1, ha=1
  assert {
    condition     = output.naming.virtualmachine_names.HANA_VMNAME[3] == "hn1dhdb_z2_01l1abc"
    error_message = "Scale-out VM idx=3: zone 2, server 01, l1"
  }
}

run "hana_scaleout_secondary_dns_inverted_flags" {
  command = plan

  variables {
    database_high_availability = true
    scale_out                  = true
    db_server_count            = 1
  }

  # Scale-out secondary DNS uses (idx+1)%2 for ha_flag (inverted)
  # format("v{sid}d{dbsid}{floor(idx/2)+offset}l{(idx+1)%2}{random_3char}")
  # idx=0: floor(0/2)=0, (0+1)%2=1 → "vhn1dhdb00l1abc"
  assert {
    condition     = output.naming.virtualmachine_names.HANA_SECONDARY_DNSNAME[0] == "vhn1dhdb00l1abc"
    error_message = "Scale-out sec DNS idx=0: inverted flag → l1"
  }

  # idx=1: floor(1/2)=0, (1+1)%2=0 → "vhn1dhdb00l0abc"
  assert {
    condition     = output.naming.virtualmachine_names.HANA_SECONDARY_DNSNAME[1] == "vhn1dhdb00l0abc"
    error_message = "Scale-out sec DNS idx=1: inverted flag → l0"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## AnyDB Computer Names
## Formula: format("{sid}db{nn}{os_code}{ha_flag}{random_3char}")
## os_code: LINUX→"l", WINDOWS→"w"
## ─────────────────────────────────────────────────────────────────────────────

run "anydb_computer_name_linux" {
  command = plan

  assert {
    condition     = output.naming.virtualmachine_names.ANYDB_COMPUTERNAME[0] == "hn1db00l0abc"
    error_message = "AnyDB Linux: {sid}db{nn}l{ha_flag=0}{random}"
  }
}

run "anydb_computer_name_windows" {
  command = plan

  variables {
    db_ostype = "WINDOWS"
  }

  assert {
    condition     = output.naming.virtualmachine_names.ANYDB_COMPUTERNAME[0] == "hn1db00w0abc"
    error_message = "AnyDB Windows: os_code='w'"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## AnyDB with HA
## HA = true → concat(primary, ha) — same pattern as HANA
## ─────────────────────────────────────────────────────────────────────────────

run "anydb_ha_doubles_names" {
  command = plan

  variables {
    database_high_availability = true
    db_server_count            = 2
  }

  assert {
    condition     = length(output.naming.virtualmachine_names.ANYDB_COMPUTERNAME) == 4
    error_message = "AnyDB HA: 2 primary + 2 HA = 4"
  }

  # Primary: ha_flag=0
  assert {
    condition     = output.naming.virtualmachine_names.ANYDB_COMPUTERNAME[0] == "hn1db00l0abc"
    error_message = "AnyDB primary 0: ha_flag=0"
  }

  # HA: ha_flag=1
  assert {
    condition     = output.naming.virtualmachine_names.ANYDB_COMPUTERNAME[2] == "hn1db00l1abc"
    error_message = "AnyDB HA 0: ha_flag=1"
  }
}

run "anydb_ha_vm_names_with_zones_reversed" {
  command = plan

  variables {
    database_high_availability = true
    db_zones                   = ["1", "2"]
    db_server_count            = 2
  }

  # Primary: uses db_zones order [1, 2]
  assert {
    condition     = output.naming.virtualmachine_names.ANYDB_VMNAME[0] == "hn1db_z1_00l0abc"
    error_message = "AnyDB primary VM 0: zone 1"
  }

  assert {
    condition     = output.naming.virtualmachine_names.ANYDB_VMNAME[1] == "hn1db_z2_01l0abc"
    error_message = "AnyDB primary VM 1: zone 2"
  }

  # HA: uses ha_zones = reverse(db_zones) = [2, 1]
  assert {
    condition     = output.naming.virtualmachine_names.ANYDB_VMNAME[2] == "hn1db_z2_00l1abc"
    error_message = "AnyDB HA VM 0: reversed → zone 2"
  }

  assert {
    condition     = output.naming.virtualmachine_names.ANYDB_VMNAME[3] == "hn1db_z1_01l1abc"
    error_message = "AnyDB HA VM 1: reversed → zone 1"
  }
}

run "anydb_vm_name_no_zones" {
  command = plan

  variables {
    db_zones = []
  }

  # No zones: no zonal marker even with use_zonal_markers=true
  assert {
    condition     = output.naming.virtualmachine_names.ANYDB_VMNAME[0] == "hn1db00l0abc"
    error_message = "AnyDB no zones: no marker in name"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Zero DB Server Count
## All DB-related lists should be empty, even with HA
## ─────────────────────────────────────────────────────────────────────────────

run "zero_db_count_all_empty" {
  command = plan

  variables {
    db_server_count = 0
  }

  assert {
    condition     = length(output.naming.virtualmachine_names.HANA_COMPUTERNAME) == 0
    error_message = "Zero DB count → empty HANA computer names"
  }

  assert {
    condition     = length(output.naming.virtualmachine_names.HANA_VMNAME) == 0
    error_message = "Zero DB count → empty HANA VM names"
  }

  assert {
    condition     = length(output.naming.virtualmachine_names.ANYDB_COMPUTERNAME) == 0
    error_message = "Zero DB count → empty AnyDB computer names"
  }

  assert {
    condition     = length(output.naming.virtualmachine_names.ANYDB_VMNAME) == 0
    error_message = "Zero DB count → empty AnyDB VM names"
  }
}

run "zero_db_count_with_ha_still_empty" {
  command = plan

  variables {
    db_server_count            = 0
    database_high_availability = true
  }

  # concat([], []) = []
  assert {
    condition     = length(output.naming.virtualmachine_names.HANA_COMPUTERNAME) == 0
    error_message = "HA with zero count: concat(empty, empty) = empty"
  }

  assert {
    condition     = length(output.naming.virtualmachine_names.ANYDB_VMNAME) == 0
    error_message = "AnyDB HA with zero count still empty"
  }
}
