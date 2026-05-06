## Section 7: Secondary DNS Names
##
## Tests virtual hostname naming for use_secondary_ips scenarios:
## - App: format("v{sid}a{nn}{app_os}{random_2char}")
## - SCS: format("v{sid}s{nn}{app_os}{random_2char}")
## - Web: format("v{web_sid}w{nn}{app_os}{random_2char}")
## - HANA primary: format("v{sid}d{dbsid}{nn}l{0}{random_2char}")
## - HANA HA: format("v{sid}d{dbsid}{nn}l{1}{random_virt}")
## - AnyDB: format("v{sid}d{nn}l{0}{random_2char}")
## - AnyDB HA: format("v{sid}d{dbsid}{floor(idx/2)}l{idx%2}{random_2char}")
## - Anchor: same as anchor_computer_names (no "v" prefix!)
##
## Key observations:
## - "v" prefix distinguishes virtual from physical hostname
## - random_id_virt_vm_verified (2 char) used in SCS, Web, HANA HA secondary
## - AnyDB HA secondary DNS uses a different pattern from primary

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
  scale_out                  = false
  db_zones                   = []
  app_zones                  = []
  scs_zones                  = []
  web_zones                  = []
}

## ─────────────────────────────────────────────────────────────────────────────
## App Secondary DNS
## Formula: format("v{sid}a{nn}{app_os}{random_2char}")
## random_2char = substr(random_id_vm_verified, 0, 2) = "ab"
## ─────────────────────────────────────────────────────────────────────────────

run "app_secondary_dns_basic" {
  command = plan

  assert {
    condition     = output.naming.virtualmachine_names.APP_SECONDARY_DNSNAME[0] == "vhn1a00lab"
    error_message = "App secondary DNS: v{sid}a{nn}{os}{random_2char}"
  }

  assert {
    condition     = output.naming.virtualmachine_names.APP_SECONDARY_DNSNAME[1] == "vhn1a01lab"
    error_message = "App secondary DNS 1: index increments"
  }

  assert {
    condition     = length(output.naming.virtualmachine_names.APP_SECONDARY_DNSNAME) == 2
    error_message = "App secondary DNS count = app_server_count"
  }
}

run "app_secondary_dns_with_offset" {
  command = plan

  variables {
    resource_offset = 3
  }

  assert {
    condition     = output.naming.virtualmachine_names.APP_SECONDARY_DNSNAME[0] == "vhn1a03lab"
    error_message = "App secondary DNS with offset: index starts at 03"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## SCS Secondary DNS
## Formula: format("v{sid}s{nn}{app_os}{random_virt_2char}")
## Uses random_id_virt_vm_verified = lower(substr(random_id, 0, 2)) = "ab"
## ─────────────────────────────────────────────────────────────────────────────

run "scs_secondary_dns_basic" {
  command = plan

  assert {
    condition     = output.naming.virtualmachine_names.SCS_SECONDARY_DNSNAME[0] == "vhn1s00lab"
    error_message = "SCS secondary DNS: v{sid}s{nn}{os}{random_virt_2char}"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Web Secondary DNS
## Formula: format("v{web_sid}w{nn}{app_os}{random_virt_2char}")
## DESIGN: Uses web_sid (not sap_sid), consistent with web VM names
## ─────────────────────────────────────────────────────────────────────────────

run "web_secondary_dns_uses_web_sid" {
  command = plan

  # format("v%sw%02d%s%s", lower("WEB"), 0, "l", "ab") = "vwebw00lab"
  assert {
    condition     = output.naming.virtualmachine_names.WEB_SECONDARY_DNSNAME[0] == "vwebw00lab"
    error_message = "Web secondary DNS: v{web_sid}w{nn}{os}{random_virt}"
  }

  assert {
    condition     = output.naming.virtualmachine_names.WEB_SECONDARY_DNSNAME[1] == "vwebw01lab"
    error_message = "Web secondary DNS 1: index increments"
  }
}

run "web_secondary_dns_custom_web_sid" {
  command = plan

  variables {
    web_sid = "WD1"
  }

  assert {
    condition     = output.naming.virtualmachine_names.WEB_SECONDARY_DNSNAME[0] == "vwd1w00lab"
    error_message = "Custom web_sid 'WD1' in secondary DNS"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## HANA Secondary DNS (no HA)
## Formula: format("v{sid}d{dbsid}{nn}l{0}{random_2char}")
## random_2char = substr(random_id_vm_verified, 0, 2) = "ab"
## ─────────────────────────────────────────────────────────────────────────────

run "hana_secondary_dns_no_ha" {
  command = plan

  assert {
    condition     = output.naming.virtualmachine_names.HANA_SECONDARY_DNSNAME[0] == "vhn1dhdb00l0ab"
    error_message = "HANA secondary DNS: v{sid}d{dbsid}{nn}l0{random_2char}"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## HANA Secondary DNS (HA, no scale-out)
## Primary: format("v{sid}d{dbsid}{nn}l{0}{random_2char}")
## HA: format("v{sid}d{dbsid}{nn}l{1}{random_virt}")
## Note: HA uses random_id_virt_vm_verified (2 char), not substr(vm, 0, 2)
## Total count: primary(db_count) + ha(db_count)
## ─────────────────────────────────────────────────────────────────────────────

run "hana_secondary_dns_with_ha" {
  command = plan

  variables {
    database_high_availability = true
    db_server_count            = 2
  }

  # Total = db_count + db_count = 4
  assert {
    condition     = length(output.naming.virtualmachine_names.HANA_SECONDARY_DNSNAME) == 4
    error_message = "HANA sec DNS HA: primary(2) + ha(2) = 4"
  }

  # Primary entries: l0, uses substr(random_id_vm_verified, 0, 2) = "ab"
  assert {
    condition     = output.naming.virtualmachine_names.HANA_SECONDARY_DNSNAME[0] == "vhn1dhdb00l0ab"
    error_message = "HANA sec DNS primary 0: l0 flag, 2-char random"
  }

  assert {
    condition     = output.naming.virtualmachine_names.HANA_SECONDARY_DNSNAME[1] == "vhn1dhdb01l0ab"
    error_message = "HANA sec DNS primary 1: l0 flag"
  }

  # HA entries: l1, uses random_id_virt_vm_verified = "ab"
  assert {
    condition     = output.naming.virtualmachine_names.HANA_SECONDARY_DNSNAME[2] == "vhn1dhdb00l1ab"
    error_message = "HANA sec DNS HA 0: l1 flag"
  }

  assert {
    condition     = output.naming.virtualmachine_names.HANA_SECONDARY_DNSNAME[3] == "vhn1dhdb01l1ab"
    error_message = "HANA sec DNS HA 1: l1 flag"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## AnyDB Secondary DNS (no HA)
## Formula: format("v{sid}d{nn}l{0}{random_2char}")
## Note: Does NOT include db_sid (unlike HANA secondary DNS)
## ─────────────────────────────────────────────────────────────────────────────

run "anydb_secondary_dns_no_ha" {
  command = plan

  # format("v%sd%02dl%d%s", "hn1", 0, 0, "ab") = "vhn1d00l0ab"
  assert {
    condition     = output.naming.virtualmachine_names.ANYDB_SECONDARY_DNSNAME[0] == "vhn1d00l0ab"
    error_message = "AnyDB secondary DNS: v{sid}d{nn}l0{random_2char} — no db_sid!"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## AnyDB Secondary DNS (HA)
## HA entries: format("v{sid}d{dbsid}{floor(idx/2)}l{idx%2}{random_2char}")
## Note: HA formula includes db_sid and uses interleaved pattern
## Count: always concat(primary, ha) regardless of database_high_availability
## Primary always produced, HA = db_server_count * 2 entries
## ─────────────────────────────────────────────────────────────────────────────

run "anydb_secondary_dns_always_has_ha_entries" {
  command = plan

  # DESIGN: anydb_secondary_dnsnames_ha is always concatenated regardless of HA flag
  # concat(primary[db_count], ha[db_count*2])
  # Primary: 1 entry, HA: 1*2=2 entries → total 3
  assert {
    condition     = length(output.naming.virtualmachine_names.ANYDB_SECONDARY_DNSNAME) == 3
    error_message = "AnyDB sec DNS: always primary(db_count) + ha(db_count*2)"
  }

  # Primary: "vhn1d00l0ab"
  assert {
    condition     = output.naming.virtualmachine_names.ANYDB_SECONDARY_DNSNAME[0] == "vhn1d00l0ab"
    error_message = "AnyDB sec DNS primary: no db_sid"
  }

  # HA entries use interleaved pattern with db_sid
  # idx=0: floor(0/2)=0, 0%2=0 → "vhn1dhdb00l0ab"
  assert {
    condition     = output.naming.virtualmachine_names.ANYDB_SECONDARY_DNSNAME[1] == "vhn1dhdb00l0ab"
    error_message = "AnyDB sec DNS HA 0: includes db_sid, floor(0/2)=0, 0%2=0"
  }

  # idx=1: floor(1/2)=0, 1%2=1 → "vhn1dhdb00l1ab"
  assert {
    condition     = output.naming.virtualmachine_names.ANYDB_SECONDARY_DNSNAME[2] == "vhn1dhdb00l1ab"
    error_message = "AnyDB sec DNS HA 1: includes db_sid, floor(1/2)=0, 1%2=1"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Anchor Secondary DNS Names
## Formula: same as anchor_computer_names (no "v" prefix!)
## DESIGN: Unlike other tiers, anchor secondary DNS has NO "v" prefix
## Count: length(zones) — same as anchor
## ─────────────────────────────────────────────────────────────────────────────

run "anchor_secondary_dns_no_v_prefix" {
  command = plan

  variables {
    db_zones = ["1", "2"]
  }

  # format("{sid}anchorz{zone}{nn}{anchor_os}{random_3char}")
  # Same as anchor_computer_names — no "v" prefix
  assert {
    condition     = output.naming.virtualmachine_names.ANCHOR_SECONDARY_DNSNAME[0] == "hn1anchorz100labc"
    error_message = "Anchor secondary DNS: same as computer name (no 'v' prefix)"
  }

  assert {
    condition     = output.naming.virtualmachine_names.ANCHOR_SECONDARY_DNSNAME[1] == "hn1anchorz201labc"
    error_message = "Anchor secondary DNS 1: zone 2"
  }
}

run "anchor_secondary_dns_empty_without_zones" {
  command = plan

  assert {
    condition     = length(output.naming.virtualmachine_names.ANCHOR_SECONDARY_DNSNAME) == 0
    error_message = "No zones → no anchor secondary DNS"
  }
}
