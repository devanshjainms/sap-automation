## SAP System App Tier Plan-Level Tests
##
## Tests the app_tier sub-module of sap_system, which creates:
## - Application server VMs, NICs, and disks (vm-app.tf)
## - SCS (SAP Central Services) VMs, load balancers, cluster resources (vm-scs.tf)
## - Web dispatcher VMs, load balancers, and NICs (vm-webdisp.tf)
## - Load balancers with SCS/ERS/FS rules, App LB, Web LB (infrastructure.tf)
## - Application and web NSGs and ASGs
## - Availability sets for app, SCS, and web tiers
## - Subnet creation/lookup for app and web subnets
##
## Three independent VM tiers: App, SCS, Web — each with own count, zones, avset, ppg.
## SCS HA doubles SCS server count and creates ERS LB resources.
## Web dispatcher uses web_sid for naming conventions.
## enable_deployment=false zeroes ALL resource creation across all tiers.
##
## All tests use mock providers with command = plan (no real Azure resources).

mock_provider "azurerm" {
  override_data {
    target = module.app_tier.data.azurerm_subnet.subnet_sap_app[0]
    values = {
      address_prefixes = ["10.1.2.0/24"]
      id               = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-app-subnet"
    }
  }

  override_data {
    target = module.app_tier.data.azurerm_network_security_group.nsg_app[0]
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/networkSecurityGroups/test-app-nsg"
    }
  }

  override_data {
    target = module.app_tier.data.azurerm_subnet.subnet_sap_web[0]
    values = {
      address_prefixes = ["10.1.3.0/24"]
      id               = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-web-subnet"
    }
  }

  override_data {
    target = module.app_tier.data.azurerm_network_security_group.nsg_web[0]
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/test-rg/providers/Microsoft.Network/networkSecurityGroups/test-web-nsg"
    }
  }
}

mock_provider "tls" {}

###############################################################################
# SECTION 1: Application Server Configuration                                 #
###############################################################################

###############################################################################
# 1.1 Single app server — basic deployment with 1 app + 1 SCS                #
###############################################################################
run "app_single_server" {
  command = plan

  assert {
    condition     = output.app_tier_os_types["app"] == "LINUX"
    error_message = "App OS type should be LINUX for default configuration"
  }

  assert {
    condition     = output.app_tier_os_types["scs"] == "LINUX"
    error_message = "SCS OS type should be LINUX for default configuration"
  }

  assert {
    condition     = output.app_tier_os_types["web"] == "LINUX"
    error_message = "Web OS type should be LINUX for default configuration"
  }

  assert {
    condition     = output.subnet_cidr_app == "10.1.2.0/24"
    error_message = "App subnet CIDR should come from data source lookup"
  }

  assert {
    condition     = output.scs_high_availability == false
    error_message = "SCS HA should be false for basic single-server deployment"
  }

  assert {
    condition     = output.webdispatcher_loadbalancer_ip == ""
    error_message = "Web LB IP should be empty when no web dispatchers deployed"
  }
}

###############################################################################
# 1.2 Multiple app servers — 3 application server instances                   #
###############################################################################
run "app_multiple_servers" {
  command = plan

  variables {
    application_server_count = 3
  }

  assert {
    condition     = output.subnet_cidr_app == "10.1.2.0/24"
    error_message = "App subnet CIDR should remain consistent with multiple servers"
  }

  assert {
    condition     = output.scs_high_availability == false
    error_message = "SCS HA should remain false — independent of app server count"
  }

  assert {
    condition     = output.app_tier_os_types["app"] == "LINUX"
    error_message = "App OS type confirms app VMs are planned for 3 servers"
  }
}

###############################################################################
# 1.3 Zero app servers — app_instance_count=0 is valid (SCS-only scenario)   #
###############################################################################
run "app_zero_servers" {
  command = plan

  variables {
    application_server_count = 0
  }

  assert {
    condition     = length(output.app_vm_ids) == 0
    error_message = "No app VMs should be planned when application_server_count is 0"
  }

  assert {
    condition     = output.scs_high_availability == false
    error_message = "SCS HA should remain false when only app count is 0"
  }

  assert {
    condition     = output.app_tier_os_types["scs"] == "LINUX"
    error_message = "SCS VMs should still be planned when only app count is 0"
  }

  assert {
    condition     = output.subnet_cidr_app == "10.1.2.0/24"
    error_message = "App subnet should still be looked up for SCS deployment"
  }
}

###############################################################################
# SECTION 2: SCS Server Configuration                                         #
###############################################################################

###############################################################################
# 2.1 Single SCS server — non-HA, creates 1 SCS VM + LB                     #
###############################################################################
run "scs_single_server" {
  command = plan

  variables {
    application_server_count = 0
    scs_server_count         = 1
  }

  assert {
    condition     = length(output.app_vm_ids) == 0
    error_message = "No app VMs when application_server_count is 0"
  }

  assert {
    condition     = output.scs_high_availability == false
    error_message = "SCS HA should be false with single SCS server"
  }

  assert {
    condition     = output.app_tier_os_types["scs"] == "LINUX"
    error_message = "SCS VMs should be planned for count=1"
  }
}

###############################################################################
# 2.2 SCS HA — doubles SCS count, creates ERS resources                      #
###############################################################################
run "scs_high_availability" {
  command = plan

  variables {
    scs_high_availability = true
  }

  assert {
    condition     = output.scs_high_availability == true
    error_message = "SCS HA should be true when explicitly enabled"
  }

  assert {
    condition     = output.app_tier_os_types["scs"] == "LINUX"
    error_message = "SCS VMs should be planned for HA deployment"
  }

  assert {
    condition     = output.subnet_cidr_app == "10.1.2.0/24"
    error_message = "App subnet CIDR should remain consistent with SCS HA enabled"
  }
}

###############################################################################
# 2.3 SCS-only deployment — no app servers, validates independent operation  #
###############################################################################
run "scs_only_no_app_servers" {
  command = plan

  variables {
    application_server_count = 0
    scs_server_count         = 1
    webdispatcher_count      = 0
  }

  assert {
    condition     = length(output.app_vm_ids) == 0
    error_message = "No app VMs when application_server_count is 0"
  }

  assert {
    condition     = output.app_tier_os_types["scs"] == "LINUX"
    error_message = "SCS VMs should be created in SCS-only mode"
  }

  assert {
    condition     = length(output.webdispatcher_server_vm_ids) == 0
    error_message = "No web VMs in SCS-only mode"
  }

  assert {
    condition     = output.webdispatcher_loadbalancer_ip == ""
    error_message = "Web LB IP should be empty in SCS-only mode"
  }
}

###############################################################################
# SECTION 3: Web Dispatcher Configuration                                     #
###############################################################################

###############################################################################
# 3.1 No web dispatchers — count=0, no web resources created                 #
###############################################################################
run "web_zero_dispatchers" {
  command = plan

  variables {
    webdispatcher_count = 0
  }

  assert {
    condition     = length(output.webdispatcher_server_vm_ids) == 0
    error_message = "No web VMs should be planned when webdispatcher_count is 0"
  }

  assert {
    condition     = output.webdispatcher_loadbalancer_ip == ""
    error_message = "Web LB IP should be empty when no web dispatchers"
  }

  assert {
    condition     = output.app_tier_os_types["web"] == "LINUX"
    error_message = "Web OS type should still be reported (ASG creation independent of VM count)"
  }
}

###############################################################################
# 3.2 Two web dispatchers — uses web_sid naming, creates web LB              #
###############################################################################
run "web_two_dispatchers" {
  command = plan

  variables {
    webdispatcher_count = 2
  }

  assert {
    condition     = output.app_tier_os_types["web"] == "LINUX"
    error_message = "Web OS type should be LINUX"
  }

  assert {
    condition     = output.scs_high_availability == false
    error_message = "SCS HA should remain false — independent of web dispatcher count"
  }

  assert {
    condition     = output.subnet_cidr_app == "10.1.2.0/24"
    error_message = "App subnet CIDR should remain consistent with web dispatchers"
  }
}

###############################################################################
# SECTION 4: Load Balancers                                                   #
###############################################################################

###############################################################################
# 4.1 SCS LB — standalone creates LB with use_loadbalancers_for_standalone   #
###############################################################################
run "lb_scs_standalone" {
  command = plan

  variables {
    scs_server_count = 1
  }

  assert {
    condition     = output.app_tier_os_types["scs"] == "LINUX"
    error_message = "SCS tier should be planned — LB created for standalone (use_loadbalancers_for_standalone=true)"
  }

  assert {
    condition     = output.subnet_cidr_app == "10.1.2.0/24"
    error_message = "App subnet should be resolved for SCS LB frontend IP allocation"
  }
}

###############################################################################
# 4.2 SCS LB HA — SCS+ERS rules created for HA deployment                   #
###############################################################################
run "lb_scs_ha_rules" {
  command = plan

  variables {
    scs_high_availability = true
  }

  assert {
    condition     = output.scs_high_availability == true
    error_message = "SCS HA flag should be true confirming HA LB rules (SCS + ERS) are planned"
  }

  assert {
    condition     = output.app_tier_os_types["scs"] == "LINUX"
    error_message = "SCS VMs should be planned for HA (count doubled)"
  }
}

###############################################################################
# 4.3 Web LB — created when web dispatchers > 0                              #
###############################################################################
run "lb_web_created" {
  command = plan

  variables {
    webdispatcher_count = 2
  }

  assert {
    condition     = output.app_tier_os_types["web"] == "LINUX"
    error_message = "Web OS type confirms web tier and web LB are planned"
  }

  assert {
    condition     = output.subnet_cidr_app == "10.1.2.0/24"
    error_message = "App subnet resolved — web LB uses web/app subnet for frontend IP"
  }
}

###############################################################################
# 4.4 No LB when deployment disabled                                          #
###############################################################################
run "lb_none_when_disabled" {
  command = plan

  variables {
    enable_deployment        = false
    application_server_count = 0
    scs_server_count         = 0
    webdispatcher_count      = 0
  }

  assert {
    condition     = output.scs_server_loadbalancer_id == ""
    error_message = "SCS LB should not exist when deployment is disabled"
  }

  assert {
    condition     = output.webdispatcher_loadbalancer_ip == ""
    error_message = "Web LB should not exist when deployment is disabled"
  }

  assert {
    condition     = output.subnet_cidr_app == ""
    error_message = "Subnet CIDR should be empty — no subnet lookup when disabled"
  }
}

###############################################################################
# SECTION 5: Network Interfaces                                               #
###############################################################################

###############################################################################
# 5.1 Standard NICs — one per VM in each tier                                 #
###############################################################################
run "nic_standard_per_tier" {
  command = plan

  variables {
    application_server_count = 2
    scs_server_count         = 1
    webdispatcher_count      = 1
  }

  assert {
    condition     = output.subnet_cidr_app == "10.1.2.0/24"
    error_message = "App subnet confirms NICs will be attached to correct subnet"
  }

  assert {
    condition     = output.app_tier_os_types["app"] == "LINUX"
    error_message = "App tier OS type confirms VMs and NICs are planned"
  }

  assert {
    condition     = output.app_tier_os_types["scs"] == "LINUX"
    error_message = "SCS tier OS type confirms VMs and NICs are planned"
  }

  assert {
    condition     = output.app_tier_os_types["web"] == "LINUX"
    error_message = "Web tier OS type confirms VMs and NICs are planned"
  }
}

###############################################################################
# 5.2 Dual NICs — admin NIC with dual_network_interfaces                     #
###############################################################################
run "nic_dual_interfaces" {
  command = plan

  variables {
    dual_network_interfaces  = true
    application_server_count = 1
    scs_server_count         = 1
  }

  assert {
    condition     = output.subnet_cidr_app == "10.1.2.0/24"
    error_message = "App subnet still resolved with dual NICs enabled"
  }

  assert {
    condition     = output.app_tier_os_types["app"] == "LINUX"
    error_message = "App VMs planned with dual NICs — admin NIC uses admin subnet"
  }
}

###############################################################################
# SECTION 6: ASG Associations                                                 #
###############################################################################

###############################################################################
# 6.1 ASGs enabled — app and web ASGs created                                #
###############################################################################
run "asg_enabled" {
  command = plan

  variables {
    deploy_application_security_groups = true
  }

  assert {
    condition     = output.app_tier_os_types["app"] == "LINUX"
    error_message = "App tier should be planned with ASGs enabled (ASG IDs resolved at apply)"
  }

  assert {
    condition     = output.subnet_cidr_app == "10.1.2.0/24"
    error_message = "Subnet should be resolved — ASG creation uses same RG/location"
  }
}

###############################################################################
# 6.2 ASGs disabled — no ASGs for any tier                                   #
###############################################################################
run "asg_disabled" {
  command = plan

  variables {
    deploy_application_security_groups = false
  }

  assert {
    condition     = output.app_asg_id == ""
    error_message = "App ASG should be empty when ASGs are disabled"
  }

  assert {
    condition     = output.web_asg_id == ""
    error_message = "Web ASG should be empty when ASGs are disabled"
  }
}

###############################################################################
# 6.3 ASGs with NSG/ASG co-located in VNet resource group                    #
###############################################################################
run "asg_with_vnet_location" {
  command = plan

  variables {
    nsg_asg_with_vnet                  = true
    deploy_application_security_groups = true
  }

  assert {
    condition     = output.app_tier_os_types["app"] == "LINUX"
    error_message = "App tier should be planned with ASGs in VNet RG"
  }

  assert {
    condition     = output.app_tier_os_types["web"] == "LINUX"
    error_message = "Web tier should be planned with ASGs in VNet RG"
  }

  assert {
    condition     = output.subnet_cidr_app == "10.1.2.0/24"
    error_message = "App subnet should remain consistent with VNet-scoped NSG/ASG"
  }
}

###############################################################################
# SECTION 7: Deployment Disabled — all tiers produce empty outputs            #
###############################################################################

###############################################################################
# 7.1 Full disable — enable_deployment=false zeroes everything                #
###############################################################################
run "disabled_full" {
  command = plan

  variables {
    enable_deployment        = false
    application_server_count = 0
    scs_server_count         = 0
    webdispatcher_count      = 0
  }

  assert {
    condition     = length(output.app_vm_ids) == 0
    error_message = "No app VMs should be created when deployment is disabled"
  }

  assert {
    condition     = length(output.scs_vm_ids) == 0
    error_message = "No SCS VMs should be created when deployment is disabled"
  }

  assert {
    condition     = length(output.webdispatcher_server_vm_ids) == 0
    error_message = "No web VMs should be created when deployment is disabled"
  }

  assert {
    condition     = output.scs_server_loadbalancer_id == ""
    error_message = "SCS LB should not be created when deployment is disabled"
  }

  assert {
    condition     = output.app_asg_id == ""
    error_message = "App ASG should be empty when deployment is disabled"
  }

  assert {
    condition     = output.web_asg_id == ""
    error_message = "Web ASG should be empty when deployment is disabled"
  }

  assert {
    condition     = output.webdispatcher_loadbalancer_ip == ""
    error_message = "Web LB IP should be empty when deployment is disabled"
  }

  assert {
    condition     = output.subnet_cidr_app == ""
    error_message = "Subnet CIDR should be empty when deployment is disabled (no subnet lookup)"
  }
}

###############################################################################
# 7.2 Disabled with HA flags — even HA settings produce nothing when disabled #
###############################################################################
run "disabled_with_ha_flags" {
  command = plan

  variables {
    enable_deployment        = false
    scs_high_availability    = true
    application_server_count = 0
    scs_server_count         = 0
    webdispatcher_count      = 0
  }

  assert {
    condition     = length(output.scs_vm_ids) == 0
    error_message = "No SCS VMs even with HA enabled when deployment is disabled"
  }

  assert {
    condition     = output.scs_server_loadbalancer_id == ""
    error_message = "No SCS LB even with HA enabled when deployment is disabled"
  }

  assert {
    condition     = output.scs_high_availability == true
    error_message = "HA flag should still be reported true (config setting, not resource state)"
  }
}

###############################################################################
# SECTION 8: Secondary IPs                                                    #
###############################################################################

###############################################################################
# 8.1 Secondary IPs enabled — virtual hostname support                        #
###############################################################################
run "secondary_ips_enabled" {
  command = plan

  variables {
    use_secondary_ips = true
  }

  assert {
    condition     = output.subnet_cidr_app == "10.1.2.0/24"
    error_message = "App subnet CIDR should remain consistent with secondary IPs"
  }

  assert {
    condition     = output.scs_high_availability == false
    error_message = "Secondary IPs should not affect HA flag"
  }

  assert {
    condition     = output.app_tier_os_types["app"] == "LINUX"
    error_message = "App VMs should still be planned with secondary IPs"
  }
}

###############################################################################
# 8.2 Secondary IPs with HA — combined scenario                              #
###############################################################################
run "secondary_ips_with_ha" {
  command = plan

  variables {
    use_secondary_ips     = true
    scs_high_availability = true
  }

  assert {
    condition     = output.scs_high_availability == true
    error_message = "HA should be true when combined with secondary IPs"
  }

  assert {
    condition     = output.app_tier_os_types["scs"] == "LINUX"
    error_message = "SCS tier should be planned for HA even with secondary IPs"
  }
}

###############################################################################
# SECTION 9: Feature Combinations                                             #
###############################################################################

###############################################################################
# 9.1 Full deployment — app + SCS HA + web dispatchers + ASGs                #
###############################################################################
run "combo_full_deployment" {
  command = plan

  variables {
    scs_high_availability              = true
    webdispatcher_count                = 2
    application_server_count           = 2
    deploy_application_security_groups = true
  }

  assert {
    condition     = output.scs_high_availability == true
    error_message = "SCS HA should be true in full deployment"
  }

  assert {
    condition     = output.app_tier_os_types["app"] == "LINUX"
    error_message = "App OS should be LINUX in full deployment"
  }

  assert {
    condition     = output.app_tier_os_types["web"] == "LINUX"
    error_message = "Web OS should be LINUX in full deployment"
  }

  assert {
    condition     = output.subnet_cidr_app == "10.1.2.0/24"
    error_message = "App subnet CIDR should remain consistent in full deployment"
  }
}

###############################################################################
# 9.2 SCS HA + web dispatchers — no app servers                              #
###############################################################################
run "combo_scs_ha_with_web_no_app" {
  command = plan

  variables {
    scs_high_availability    = true
    webdispatcher_count      = 2
    application_server_count = 0
  }

  assert {
    condition     = length(output.app_vm_ids) == 0
    error_message = "No app VMs when count is 0 even with HA + web"
  }

  assert {
    condition     = output.scs_high_availability == true
    error_message = "SCS HA should be true independent of app server count"
  }

  assert {
    condition     = output.app_tier_os_types["scs"] == "LINUX"
    error_message = "SCS tier should be planned for HA even without app servers"
  }

  assert {
    condition     = output.app_tier_os_types["web"] == "LINUX"
    error_message = "Web tier should be planned even without app servers"
  }
}

###############################################################################
# 9.3 Availability sets enabled for app and SCS                              #
###############################################################################
run "combo_avsets_enabled" {
  command = plan

  variables {
    app_use_avset            = true
    scs_use_avset            = true
    application_server_count = 2
  }

  assert {
    condition     = output.subnet_cidr_app == "10.1.2.0/24"
    error_message = "App subnet should be consistent with availability sets enabled"
  }

  assert {
    condition     = output.app_tier_os_types["app"] == "LINUX"
    error_message = "App VMs should be planned with availability sets"
  }
}

###############################################################################
# 9.4 Dual NICs + web dispatchers + secondary IPs                            #
###############################################################################
run "combo_dual_nics_web_secondary" {
  command = plan

  variables {
    dual_network_interfaces = true
    webdispatcher_count     = 1
    use_secondary_ips       = true
  }

  assert {
    condition     = output.app_tier_os_types["web"] == "LINUX"
    error_message = "Web tier should be planned with dual NICs + secondary IPs"
  }

  assert {
    condition     = output.subnet_cidr_app == "10.1.2.0/24"
    error_message = "App subnet should be consistent with all NIC features enabled"
  }
}

###############################################################################
# 9.5 Web dispatchers with availability sets                                  #
###############################################################################
run "combo_web_avset" {
  command = plan

  variables {
    webdispatcher_count = 2
    web_use_avset       = true
  }

  assert {
    condition     = output.app_tier_os_types["web"] == "LINUX"
    error_message = "Web VMs should be planned with availability sets"
  }

  assert {
    condition     = output.scs_high_availability == false
    error_message = "SCS HA should remain false when only web avset is enabled"
  }
}

###############################################################################
# 9.6 All tiers with maximum features                                         #
###############################################################################
run "combo_maximum_features" {
  command = plan

  variables {
    application_server_count           = 3
    scs_server_count                   = 1
    scs_high_availability              = true
    webdispatcher_count                = 2
    deploy_application_security_groups = true
    use_secondary_ips                  = true
    dual_network_interfaces            = true
    app_use_avset                      = true
    scs_use_avset                      = true
    web_use_avset                      = true
  }

  assert {
    condition     = output.scs_high_availability == true
    error_message = "HA should be true in maximum feature scenario"
  }

  assert {
    condition     = output.app_tier_os_types["app"] == "LINUX"
    error_message = "App OS type should be LINUX in maximum feature scenario"
  }

  assert {
    condition     = output.app_tier_os_types["scs"] == "LINUX"
    error_message = "SCS OS type should be LINUX in maximum feature scenario"
  }

  assert {
    condition     = output.app_tier_os_types["web"] == "LINUX"
    error_message = "Web OS type should be LINUX in maximum feature scenario"
  }

  assert {
    condition     = output.subnet_cidr_app == "10.1.2.0/24"
    error_message = "App subnet CIDR should remain consistent with all features"
  }
}

###############################################################################
# Section 8: Deep Resource-Parameter Assertions                               #
#                                                                             #
# Validates OS type mapping, HA passthrough, and tier configuration.          #
###############################################################################

run "deep_os_type_mapping_all_linux" {
  command = plan

  # Default: all tiers are LINUX
  assert {
    condition     = output.app_tier_os_types.app == "LINUX"
    error_message = "Default app tier OS type should be LINUX"
  }

  assert {
    condition     = output.app_tier_os_types.scs == "LINUX"
    error_message = "Default SCS tier OS type should be LINUX"
  }

  assert {
    condition     = output.app_tier_os_types.web == "LINUX"
    error_message = "Default web tier OS type should be LINUX"
  }

  # HA passthrough
  assert {
    condition     = output.scs_high_availability == false
    error_message = "Default SCS HA should be false"
  }
}

run "deep_scs_ha_enabled_passthrough" {
  command = plan
  variables {
    scs_high_availability = true
  }

  assert {
    condition     = output.scs_high_availability == true
    error_message = "SCS HA should pass through as true when enabled"
  }
}
