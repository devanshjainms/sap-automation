## Section 8: PPG and Availability Set Naming
##
## Tests Proximity Placement Groups and Availability Sets:
## - Non-zonal: single entry per tier
## - Zonal: one per distinct zone (deduplicated across all tiers)
## - PPG naming includes full SDU prefix in non-zonal, zone marker in zonal
## - Avset naming: "z{zone}_{tier}-avset" (zonal) or "{tier}-avset" (non-zonal)
## - custom_prefix changes non-zonal PPG format
##
## Zone deduplication formula: distinct(concat(db_zones, app_zones, scs_zones, web_zones))

variables {
  environment          = "DEV"
  location             = "eastus"
  sap_sid              = "HN1"
  db_sid               = "HDB"
  web_sid              = "WEB"
  random_id            = "abc123"
  management_vnet_name = "DEP-VNET"
  sap_vnet_name        = "SAP-VNET"
  db_server_count      = 1
  app_server_count     = 1
  scs_server_count     = 1
  web_server_count     = 1
  deployer_vm_count    = 1
  iscsi_server_count   = 1
  db_zones             = []
  app_zones            = []
  scs_zones            = []
  web_zones            = []
}

## ─────────────────────────────────────────────────────────────────────────────
## Non-Zonal Availability Sets
## Formula: [format("{tier}-avset")]
## One entry per tier, no zone prefix
## ─────────────────────────────────────────────────────────────────────────────

run "avset_non_zonal_all_tiers" {
  command = plan

  assert {
    condition     = output.naming.availabilityset_names.app[0] == "app-avset"
    error_message = "Non-zonal app avset: 'app-avset'"
  }

  assert {
    condition     = output.naming.availabilityset_names.db[0] == "db-avset"
    error_message = "Non-zonal db avset: 'db-avset'"
  }

  assert {
    condition     = output.naming.availabilityset_names.scs[0] == "scs-avset"
    error_message = "Non-zonal scs avset: 'scs-avset'"
  }

  assert {
    condition     = output.naming.availabilityset_names.web[0] == "web-avset"
    error_message = "Non-zonal web avset: 'web-avset'"
  }

  assert {
    condition     = length(output.naming.availabilityset_names.app) == 1
    error_message = "Non-zonal: exactly 1 app avset"
  }

  assert {
    condition     = length(output.naming.availabilityset_names.db) == 1
    error_message = "Non-zonal: exactly 1 db avset"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Zonal Availability Sets
## Formula: [for z in zones: format("z{zone}_{tier}-avset")]
## Count = length(distinct zones across all tiers)
## ─────────────────────────────────────────────────────────────────────────────

run "avset_zonal_two_zones" {
  command = plan

  variables {
    db_zones  = ["1", "2"]
    app_zones = ["1", "2"]
  }

  # zones = distinct(["1","2","1","2",...]) = ["1","2"]
  assert {
    condition     = output.naming.availabilityset_names.db[0] == "z1_db-avset"
    error_message = "Zonal db avset zone 1: 'z1_db-avset'"
  }

  assert {
    condition     = output.naming.availabilityset_names.db[1] == "z2_db-avset"
    error_message = "Zonal db avset zone 2: 'z2_db-avset'"
  }

  assert {
    condition     = output.naming.availabilityset_names.app[0] == "z1_app-avset"
    error_message = "Zonal app avset zone 1"
  }

  assert {
    condition     = output.naming.availabilityset_names.scs[0] == "z1_scs-avset"
    error_message = "Zonal scs avset zone 1"
  }

  assert {
    condition     = output.naming.availabilityset_names.web[0] == "z1_web-avset"
    error_message = "Zonal web avset zone 1"
  }

  assert {
    condition     = length(output.naming.availabilityset_names.db) == 2
    error_message = "Zonal: 2 avsets per tier with 2 zones"
  }
}

run "avset_three_zones" {
  command = plan

  variables {
    db_zones = ["1", "2", "3"]
  }

  assert {
    condition     = length(output.naming.availabilityset_names.db) == 3
    error_message = "3 zones → 3 avsets"
  }

  assert {
    condition     = output.naming.availabilityset_names.db[2] == "z3_db-avset"
    error_message = "Third avset: zone 3"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## Zone Deduplication Across Tiers
## zones = distinct(concat(db_zones, app_zones, scs_zones, web_zones))
## ─────────────────────────────────────────────────────────────────────────────

run "zones_deduplicated_across_tiers" {
  command = plan

  variables {
    db_zones  = ["1", "2"]
    app_zones = ["2", "3"]
    scs_zones = ["1"]
    web_zones = ["3"]
  }

  # distinct(concat(["1","2"], ["2","3"], ["1"], ["3"])) = ["1","2","3"]
  assert {
    condition     = length(output.naming.availabilityset_names.app) == 3
    error_message = "Zones deduplicated: 3 distinct zones across all tiers"
  }

  assert {
    condition     = length(output.naming.ppg_names) == 3
    error_message = "PPG count = distinct zone count = 3"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## PPG Names (non-zonal)
## Formula: [format("{sdu_name}-ppg")] when no custom_prefix
##          [format("-ppg")] when custom_prefix is set
## ─────────────────────────────────────────────────────────────────────────────

run "ppg_non_zonal_no_custom_prefix" {
  command = plan

  # sdu_name = "DEV-EAUS-SAPVNET-HN1"
  assert {
    condition     = output.naming.ppg_names[0] == "DEV-EAUS-SAPVNET-HN1-ppg"
    error_message = "Non-zonal PPG: {sdu_name}-ppg"
  }

  assert {
    condition     = length(output.naming.ppg_names) == 1
    error_message = "Non-zonal: exactly 1 PPG"
  }
}

run "ppg_non_zonal_with_custom_prefix" {
  command = plan

  variables {
    custom_prefix = "CUSTOM"
  }

  # Custom prefix: PPG name is just "-ppg" (prefix applied externally)
  assert {
    condition     = output.naming.ppg_names[0] == "-ppg"
    error_message = "Custom prefix non-zonal PPG: just '-ppg'"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## PPG Names (zonal)
## Formula: [for z in zones: format("-z{zone}-ppg")]
## Zone markers independent of custom_prefix
## ─────────────────────────────────────────────────────────────────────────────

run "ppg_zonal" {
  command = plan

  variables {
    db_zones = ["1", "2"]
  }

  assert {
    condition     = output.naming.ppg_names[0] == "-z1-ppg"
    error_message = "Zonal PPG 0: -z1-ppg"
  }

  assert {
    condition     = output.naming.ppg_names[1] == "-z2-ppg"
    error_message = "Zonal PPG 1: -z2-ppg"
  }

  assert {
    condition     = length(output.naming.ppg_names) == 2
    error_message = "Zonal PPG count = zone count"
  }
}

run "ppg_zonal_with_custom_prefix" {
  command = plan

  variables {
    db_zones      = ["1", "2"]
    custom_prefix = "CUSTOM"
  }

  # Zonal PPG format is the same regardless of custom_prefix
  assert {
    condition     = output.naming.ppg_names[0] == "-z1-ppg"
    error_message = "Zonal PPG with custom_prefix: still -z{zone}-ppg"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## App PPG Names (naming_new output)
## Non-zonal: [format("{sdu_name}-app-ppg")] or [format("-app-ppg")] with custom_prefix
## Zonal: [for z in zones: format("-z{zone}-app-ppg")]
## ─────────────────────────────────────────────────────────────────────────────

run "app_ppg_non_zonal" {
  command = plan

  assert {
    condition     = output.naming_new.app_ppg_names[0] == "DEV-EAUS-SAPVNET-HN1-app-ppg"
    error_message = "Non-zonal app PPG: {sdu_name}-app-ppg"
  }
}

run "app_ppg_non_zonal_custom_prefix" {
  command = plan

  variables {
    custom_prefix = "CUSTOM"
  }

  assert {
    condition     = output.naming_new.app_ppg_names[0] == "-app-ppg"
    error_message = "Custom prefix app PPG: just '-app-ppg'"
  }
}

run "app_ppg_zonal" {
  command = plan

  variables {
    app_zones = ["1", "2"]
  }

  assert {
    condition     = output.naming_new.app_ppg_names[0] == "-z1-app-ppg"
    error_message = "Zonal app PPG 0: -z1-app-ppg"
  }

  assert {
    condition     = output.naming_new.app_ppg_names[1] == "-z2-app-ppg"
    error_message = "Zonal app PPG 1: -z2-app-ppg"
  }
}

run "app_ppg_zonal_custom_prefix" {
  command = plan

  variables {
    app_zones     = ["2", "3"]
    custom_prefix = "X"
  }

  # Zonal format same regardless of custom_prefix
  assert {
    condition     = output.naming_new.app_ppg_names[0] == "-z2-app-ppg"
    error_message = "Zonal app PPG with custom_prefix: -z{zone}-app-ppg"
  }
}

## ─────────────────────────────────────────────────────────────────────────────
## PPG/Avset with Codename in SDU Name
## codename affects sdu_name which affects non-zonal PPG
## ─────────────────────────────────────────────────────────────────────────────

run "ppg_non_zonal_with_codename" {
  command = plan

  variables {
    codename = "S4"
  }

  # sdu_name = "DEV-EAUS-SAPVNET_S4-HN1"
  assert {
    condition     = output.naming.ppg_names[0] == "DEV-EAUS-SAPVNET_S4-HN1-ppg"
    error_message = "PPG with codename includes codename in SDU prefix"
  }
}
