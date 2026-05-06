## Section 6: VM Naming - Deployer, iSCSI, Observer, Anchor, Utility
##
## Tests infrastructure-tier VM naming:
## - Deployer: lower({env}{location}{dep_vnet}deploy{nn})
## - iSCSI: lower({env}{sap_vnet}{location}iscsi{nn})
## - Observer: count = max(len(zones), 1) — always at least 1
## - Anchor: count = len(zones) — can be 0 if no zones
## - Utility: format("wz-vm{nn}"), count = utility_vm_count

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
  utility_vm_count           = 0
  db_zones                   = []
  app_zones                  = []
  scs_zones                  = []
  web_zones                  = []
}

## ─────────────────────────────────────────────────────────────────────────────
## Deployer VM Names
## Formula: lower(format("{env_verified}{location_short}{dep_vnet_verified}deploy{nn}"))
## Uses: env_verified (NOT deployer_env_verified), location_short, dep_vnet_verified
## Note: iSCSI format order differs (env, vnet, location)
## ─────────────────────────────────────────────────────────────────────────────

run "deployer_vm_name_basic" {
  command = plan

  # lower("DEV" + "EAUS" + "DEPVNET" + "deploy" + "00") = "deveausdepvnetdeploy00"
  assert {
    condition     = output.naming.virtualmachine_names.DEPLOYER[0] == "deveausdepvnetdeploy00"
    error_message = "Deployer VM: lower({env}{location}{vnet}deploy{nn})"
  }
}

run "deployer_vm_multiple" {
  command = plan

  variables {
    deployer_vm_count = 3
  }

  assert {
    condition     = length(output.naming.virtualmachine_names.DEPLOYER) == 3
    error_message = "Should have deployer_vm_count (3) entries"
  }

  assert {
    condition     = output.naming.virtualmachine_names.DEPLOYER[0] == "deveausdepvnetdeploy00"
    error_message = "Deployer 0: index 00"
  }

  assert {
    condition     = output.naming.virtualmachine_names.DEPLOYER[1] == "deveausdepvnetdeploy01"
    error_message = "Deployer 1: index 01"
  }

  assert {
    condition     = output.naming.virtualmachine_names.DEPLOYER[2] == "deveausdepvnetdeploy02"
    error_message = "Deployer 2: index 02"
  }
}

run "deployer_vm_with_offset" {
  command = plan

  variables {
    resource_offset = 5
  }

  assert {
    condition     = output.naming.virtualmachine_names.DEPLOYER[0] == "deveausdepvnetdeploy05"
    error_message = "Deployer with offset=5: starts at 05"
  }
}

run "deployer_vm_zero_count" {
  command = plan

  variables {
    deployer_vm_count = 0
  }

  assert {
    condition     = length(output.naming.virtualmachine_names.DEPLOYER) == 0
    error_message = "Zero deployer count → empty list"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## iSCSI Server Names
## Formula: lower(format("{env_verified}{sap_vnet_verified}{location_short}iscsi{nn}"))
## Note: Component order is env → sap_vnet → location (differs from deployer)
## Note: Index does NOT use resource_offset (starts at 0 always)
## ─────────────────────────────────────────────────────────────────────────────

run "iscsi_name_basic" {
  command = plan

  # lower("DEV" + "SAPVNET" + "EAUS" + "iscsi" + "00") = "devsapvneteausiscsi00"
  assert {
    condition     = output.naming.virtualmachine_names.ISCSI_COMPUTERNAME[0] == "devsapvneteausiscsi00"
    error_message = "iSCSI: lower({env}{sap_vnet}{location}iscsi{nn})"
  }
}

run "iscsi_multiple" {
  command = plan

  variables {
    iscsi_server_count = 3
  }

  assert {
    condition     = length(output.naming.virtualmachine_names.ISCSI_COMPUTERNAME) == 3
    error_message = "Should have 3 iSCSI servers"
  }

  assert {
    condition     = output.naming.virtualmachine_names.ISCSI_COMPUTERNAME[2] == "devsapvneteausiscsi02"
    error_message = "iSCSI 2: index 02"
  }
}

run "iscsi_zero_count" {
  command = plan

  variables {
    iscsi_server_count = 0
  }

  assert {
    condition     = length(output.naming.virtualmachine_names.ISCSI_COMPUTERNAME) == 0
    error_message = "Zero iSCSI count → empty list"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Observer VM Names
## Count: max(length(zones), 1) — always at least 1 even with no zones
## Computer name: format("{sid}observer{nn}{db_oscode}{random_3char}")
## VM name (zonal): format("{sid}observer_z{zone}_{nn}{db_os}{random}")
## VM name (non-zonal): same as computer name format
## Note: Uses db_oscode (database OS), not app_oscode
## ─────────────────────────────────────────────────────────────────────────────

run "observer_always_at_least_one" {
  command = plan

  # No zones defined → max(0, 1) = 1
  assert {
    condition     = length(output.naming.virtualmachine_names.OBSERVER_COMPUTERNAME) == 1
    error_message = "Observer always has at least 1 entry (max(zones, 1))"
  }

  assert {
    condition     = output.naming.virtualmachine_names.OBSERVER_COMPUTERNAME[0] == "hn1observer00labc"
    error_message = "Observer computer: {sid}observer{nn}{db_os}{random}"
  }
}

run "observer_non_zonal_vm_name" {
  command = plan

  # Non-zonal: VM name same format as computer name
  assert {
    condition     = output.naming.virtualmachine_names.OBSERVER_VMNAME[0] == "hn1observer00labc"
    error_message = "Observer VM non-zonal: same as computer name"
  }
}

run "observer_with_zones" {
  command = plan

  variables {
    db_zones = ["1", "2", "3"]
  }

  # zones = distinct(concat(["1","2","3"], [], [], [])) = ["1","2","3"]
  # Count = max(3, 1) = 3
  assert {
    condition     = length(output.naming.virtualmachine_names.OBSERVER_COMPUTERNAME) == 3
    error_message = "Observer count = number of distinct zones = 3"
  }

  assert {
    condition     = output.naming.virtualmachine_names.OBSERVER_COMPUTERNAME[0] == "hn1observer00labc"
    error_message = "Observer computer 0: index 00"
  }

  assert {
    condition     = output.naming.virtualmachine_names.OBSERVER_COMPUTERNAME[2] == "hn1observer02labc"
    error_message = "Observer computer 2: index 02"
  }

  # VM names with zones get zonal markers
  assert {
    condition     = output.naming.virtualmachine_names.OBSERVER_VMNAME[0] == "hn1observer_z1_00labc"
    error_message = "Observer VM 0 zonal: _z1_ marker"
  }

  assert {
    condition     = output.naming.virtualmachine_names.OBSERVER_VMNAME[2] == "hn1observer_z3_02labc"
    error_message = "Observer VM 2 zonal: _z3_ marker"
  }
}

run "observer_uses_db_ostype" {
  command = plan

  variables {
    db_ostype = "WINDOWS"
  }

  assert {
    condition     = output.naming.virtualmachine_names.OBSERVER_COMPUTERNAME[0] == "hn1observer00wabc"
    error_message = "Observer uses db_oscode: Windows → 'w'"
  }
}

run "observer_zonal_markers_disabled" {
  command = plan

  variables {
    db_zones          = ["1", "2"]
    use_zonal_markers = false
  }

  # zones exist (count=2), but markers disabled
  assert {
    condition     = length(output.naming.virtualmachine_names.OBSERVER_VMNAME) == 2
    error_message = "Still 2 observers (zone count), just no markers in names"
  }

  assert {
    condition     = output.naming.virtualmachine_names.OBSERVER_VMNAME[0] == "hn1observer00labc"
    error_message = "Observer VM no markers when disabled"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Anchor VM Names
## Count: length(zones) — can be 0 if no zones
## Computer name: format("{sid}anchorz{zone}{nn}{anchor_os}{random_3char}")
## VM name: format("{sid}anchor_z{zone}_{nn}{anchor_os}{random_3char}")
## Note: Uses anchor_oscode (separate from db/app)
## Note: Anchor has NO non-zonal variant — it only exists with zones
## ─────────────────────────────────────────────────────────────────────────────

run "anchor_empty_without_zones" {
  command = plan

  # length(local.zones) = 0 → range(0) = []
  assert {
    condition     = length(output.naming.virtualmachine_names.ANCHOR_COMPUTERNAME) == 0
    error_message = "No zones → no anchor VMs"
  }

  assert {
    condition     = length(output.naming.virtualmachine_names.ANCHOR_VMNAME) == 0
    error_message = "No zones → no anchor VM names"
  }
}

run "anchor_with_zones" {
  command = plan

  variables {
    db_zones = ["1", "2"]
  }

  # zones = ["1", "2"], count = 2
  assert {
    condition     = length(output.naming.virtualmachine_names.ANCHOR_COMPUTERNAME) == 2
    error_message = "Anchor count = number of distinct zones = 2"
  }

  # Computer name: {sid}anchorz{zone}{nn}{anchor_os}{random}
  assert {
    condition     = output.naming.virtualmachine_names.ANCHOR_COMPUTERNAME[0] == "hn1anchorz100labc"
    error_message = "Anchor computer 0: zone 1"
  }

  assert {
    condition     = output.naming.virtualmachine_names.ANCHOR_COMPUTERNAME[1] == "hn1anchorz201labc"
    error_message = "Anchor computer 1: zone 2"
  }

  # VM name: {sid}anchor_z{zone}_{nn}{anchor_os}{random}
  assert {
    condition     = output.naming.virtualmachine_names.ANCHOR_VMNAME[0] == "hn1anchor_z1_00labc"
    error_message = "Anchor VM 0: _z1_ marker"
  }

  assert {
    condition     = output.naming.virtualmachine_names.ANCHOR_VMNAME[1] == "hn1anchor_z2_01labc"
    error_message = "Anchor VM 1: _z2_ marker"
  }
}

run "anchor_uses_anchor_ostype" {
  command = plan

  variables {
    db_zones      = ["1"]
    anchor_ostype = "WINDOWS"
  }

  assert {
    condition     = output.naming.virtualmachine_names.ANCHOR_COMPUTERNAME[0] == "hn1anchorz100wabc"
    error_message = "Anchor uses anchor_oscode: Windows → 'w'"
  }
}

run "anchor_zones_from_multiple_tiers_deduplicated" {
  command = plan

  variables {
    db_zones  = ["1", "2"]
    app_zones = ["2", "3"]
    scs_zones = ["1"]
  }

  # zones = distinct(concat(["1","2"], ["2","3"], ["1"], [])) = ["1","2","3"]
  assert {
    condition     = length(output.naming.virtualmachine_names.ANCHOR_COMPUTERNAME) == 3
    error_message = "Anchor count = distinct zones across all tiers = 3"
  }

  assert {
    condition     = output.naming.virtualmachine_names.ANCHOR_COMPUTERNAME[2] == "hn1anchorz302labc"
    error_message = "Anchor 2: zone 3"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Utility VM Names
## Formula: lower(format("wz-vm{nn}"))
## Count: utility_vm_count (default: 0)
## ─────────────────────────────────────────────────────────────────────────────

run "utility_vm_zero_count_default" {
  command = plan

  assert {
    condition     = length(output.naming.virtualmachine_names.WORKLOAD_VMNAME) == 0
    error_message = "Default utility_vm_count=0 → empty list"
  }
}

run "utility_vm_names" {
  command = plan

  variables {
    utility_vm_count = 3
  }

  assert {
    condition     = output.naming.virtualmachine_names.WORKLOAD_VMNAME[0] == "wz-vm00"
    error_message = "Utility VM 0: wz-vm00"
  }

  assert {
    condition     = output.naming.virtualmachine_names.WORKLOAD_VMNAME[1] == "wz-vm01"
    error_message = "Utility VM 1: wz-vm01"
  }

  assert {
    condition     = output.naming.virtualmachine_names.WORKLOAD_VMNAME[2] == "wz-vm02"
    error_message = "Utility VM 2: wz-vm02"
  }
}

run "utility_vm_with_offset" {
  command = plan

  variables {
    utility_vm_count = 1
    resource_offset  = 10
  }

  assert {
    condition     = output.naming.virtualmachine_names.WORKLOAD_VMNAME[0] == "wz-vm10"
    error_message = "Utility with offset=10: wz-vm10"
  }
}
