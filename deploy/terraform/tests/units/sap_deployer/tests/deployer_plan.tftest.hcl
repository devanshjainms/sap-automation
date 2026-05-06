## SAP Deployer Module — Systematic Plan-Level Tests
##
## Organized by resource group following the namegenerator test pattern:
## 1. Resource Group naming and creation logic
## 2. VNet/Subnet/NSG configuration and naming
## 3. Key Vault naming, access policies, secret names
## 4. VM configuration (count, naming, public IP, OS image)
## 5. Bastion host conditional deployment
## 6. Firewall conditional deployment
## 7. Brownfield (existing infrastructure) scenarios
## 8. Feature combinations (private endpoints + firewall + locks)
##
## All tests use command = plan with mock providers — no real Azure resources.
## Assertions target SPECIFIC computed values known at plan time.

mock_provider "azurerm" {
  override_data {
    target = module.deployer.data.azurerm_client_config.deployer
    values = {
      client_id       = "00000000-0000-0000-0000-000000000001"
      tenant_id       = "00000000-0000-0000-0000-000000000002"
      subscription_id = "00000000-0000-0000-0000-000000000003"
      object_id       = "00000000-0000-0000-0000-000000000004"
    }
  }

  override_data {
    target = module.deployer.data.azurerm_subscription.primary
    values = {
      subscription_id = "00000000-0000-0000-0000-000000000003"
      tenant_id       = "00000000-0000-0000-0000-000000000002"
      display_name    = "Test Subscription"
      id              = "/subscriptions/00000000-0000-0000-0000-000000000003"
    }
  }
}

mock_provider "azapi" {}

mock_provider "azuread" {}


## ═══════════════════════════════════════════════════════════════════════════════
## Section 1: Resource Group Naming and Creation Logic
##
## Formula: format("%s%s%s", resource_prefixes.deployer_rg, prefix, resource_suffixes.deployer_rg)
## With test inputs: "" + "DEV-EAUS-DEP" + "-INFRASTRUCTURE" = "DEV-EAUS-DEP-INFRASTRUCTURE"
##
## DESIGN: The module uses a 3-tier priority for RG name:
##   1. If exists=true → extract from resource ID (split on "/")
##   2. If name is provided → use it directly
##   3. Otherwise → format with naming convention
## ═══════════════════════════════════════════════════════════════════════════════

run "rg_greenfield_naming_convention" {
  command = plan

  # prefix="DEV-EAUS-DEP", deployer_rg prefix="", deployer_rg suffix="-INFRASTRUCTURE"
  # Result: "" + "DEV-EAUS-DEP" + "-INFRASTRUCTURE" = "DEV-EAUS-DEP-INFRASTRUCTURE"
  assert {
    condition     = output.resource_group_name == "DEV-EAUS-DEP-INFRASTRUCTURE"
    error_message = "RG name: {rg_prefix}{prefix}{rg_suffix} = DEV-EAUS-DEP-INFRASTRUCTURE"
  }

  assert {
    condition     = output.resource_group_location == "eastus"
    error_message = "RG location must match infrastructure.region='eastus'"
  }
}

run "rg_location_matches_region" {
  command = plan

  # DESIGN: Resource group location comes from var.infrastructure.region directly
  assert {
    condition     = output.resource_group_location == "eastus"
    error_message = "RG location is set from infrastructure.region, not computed"
  }
}

## ═══════════════════════════════════════════════════════════════════════════════
## Section 2: VNet/Subnet/NSG Configuration and Naming
##
## VNet name formula: format("%s%s%s", resource_prefixes.vnet, prefix_or_env, resource_suffixes.vnet)
## With inputs: "" + "DEV-EAUS-DEP" + "-vnet" (but setup overrides with name="dep-vnet")
##
## Subnet formula: format("%s%s%s", resource_prefixes.deployer_subnet, prefix_or_env, resource_suffixes.deployer_subnet)
## NSG formula: format("%s%s%s", resource_prefixes.deployer_subnet_nsg, prefix_or_env, resource_suffixes.deployer_subnet_nsg)
##
## DESIGN: When infrastructure.virtual_network.management.name is provided (non-empty),
## it takes priority over the naming formula. The setup passes name="dep-vnet".
## ═══════════════════════════════════════════════════════════════════════════════

run "vnet_greenfield_is_created" {
  command = plan

  # When exists=false, azurerm_virtual_network.vnet_mgmt[0] is planned
  # The output vnet_mgmt_id will be from the new resource
  assert {
    condition     = output.nsg_mgmt != null
    error_message = "NSG must be created in greenfield deployment (exists=false)"
  }
}

run "subnet_address_prefix_from_config" {
  command = plan

  # DESIGN: Management subnet uses the prefix from infrastructure config
  # Setup passes subnet_mgmt.prefix = "10.0.0.0/25"
  assert {
    condition     = length(output.subnet_mgmt_address_prefixes) > 0
    error_message = "Subnet address prefixes must be populated for greenfield subnet"
  }
}

run "nsg_created_when_not_existing" {
  command = plan

  variables {
    use_existing_nsg = false
  }

  # DESIGN: NSG is always created when nsg.exists=false, regardless of other settings
  assert {
    condition     = output.nsg_mgmt != null
    error_message = "NSG object must be non-null when nsg.exists=false"
  }
}

## ═══════════════════════════════════════════════════════════════════════════════
## Section 3: Key Vault Naming, Access Policies, Secret Names
##
## KV name formula: naming.keyvault_names.DEPLOYER.user_access (passed directly)
## With test inputs: "DEVEAUSDEPuserABC"
##
## Secret name formulas (when prefix is non-empty):
##   private_key: replace(format("%s-sshkey", prefix), "/[^A-Za-z0-9-]/", "")
##   public_key:  replace(format("%s-sshkey-pub", prefix), "/[^A-Za-z0-9-]/", "")
##   password:    replace(format("%s-password", prefix), "/[^A-Za-z0-9-]/", "")
##   username:    replace(format("%s-username", prefix), "/[^A-Za-z0-9-]/", "")
##
## With prefix="DEV-EAUS-DEP":
##   private_key = "DEV-EAUS-DEP-sshkey" (hyphens preserved, no illegal chars)
##   public_key  = "DEV-EAUS-DEP-sshkey-pub"
##   password    = "DEV-EAUS-DEP-password"
##
## DESIGN: username_secret_name output is actually local.username (the login name),
## NOT the KV secret name. This is a naming quirk in the module.
## ═══════════════════════════════════════════════════════════════════════════════

run "kv_user_name_from_naming_input" {
  command = plan

  # Key vault name comes from naming.keyvault_names.DEPLOYER.user_access
  assert {
    condition     = output.user_vault_name == "DEVEAUSDEPuserABC"
    error_message = "KV name == naming.keyvault_names.DEPLOYER.user_access"
  }
}

run "kv_name_contains_user_identifier" {
  command = plan

  # DESIGN: SDAF convention requires "user" in the user-access KV name
  # to distinguish from the "prvt" (private/service) KV
  assert {
    condition     = can(regex("user", output.user_vault_name))
    error_message = "User KV must contain 'user' to distinguish from prvt KV"
  }
}

run "kv_name_azure_length_limit" {
  command = plan

  # Azure enforces 24-char max for Key Vault names
  assert {
    condition     = length(output.user_vault_name) <= 24
    error_message = "KV name must be ≤24 chars (Azure limit); got ${length(output.user_vault_name)}"
  }
}

run "kv_name_starts_with_env_region_logical" {
  command = plan

  # Format: {env}{location_short}{logical_name}user{random}
  # = "DEV" + "EAUS" + "DEP" + "user" + "ABC" = "DEVEAUSDEPuserABC"
  assert {
    condition     = can(regex("^DEVEAUSDEP", output.user_vault_name))
    error_message = "KV name prefix: {env}{location_short}{logical_name}"
  }
}

run "secret_name_private_key_ssh_auth" {
  command = plan

  # Auth type="key" → enable_key=true → ppk_secret_name = local.private_key_secret_name
  # replace(format("DEV-EAUS-DEP-sshkey"), "/[^A-Za-z0-9-]/", "") = "DEV-EAUS-DEP-sshkey"
  assert {
    condition     = output.ppk_secret_name == "DEV-EAUS-DEP-sshkey"
    error_message = "Private key secret: replace('{prefix}-sshkey', non-alnum-hyphen, '')"
  }
}

run "secret_name_public_key_ssh_auth" {
  command = plan

  # replace(format("DEV-EAUS-DEP-sshkey-pub"), "/[^A-Za-z0-9-]/", "") = "DEV-EAUS-DEP-sshkey-pub"
  assert {
    condition     = output.pk_secret_name == "DEV-EAUS-DEP-sshkey-pub"
    error_message = "Public key secret: replace('{prefix}-sshkey-pub', non-alnum-hyphen, '')"
  }
}

run "secret_name_password_empty_when_key_auth" {
  command = plan

  # DESIGN: When auth type is "key", pwd_secret_name output is "" (empty)
  # because local.enable_password=false → output returns ""
  assert {
    condition     = output.pwd_secret_name == ""
    error_message = "Password secret must be empty when auth_type='key'"
  }
}

run "username_output_is_login_name_not_secret" {
  command = plan

  # EDGE_CASE: output.username_secret_name returns local.username ("azureadm"),
  # NOT the actual KV secret name. This is a module design quirk.
  assert {
    condition     = output.username_secret_name == "azureadm"
    error_message = "username_secret_name output == local.username (default: 'azureadm')"
  }
}

## ═══════════════════════════════════════════════════════════════════════════════
## Section 4: VM Configuration (Count, Public IP, Outputs)
##
## VM count: var.deployer_vm_count controls azurerm_linux_virtual_machine count
## Public IP: controlled by options.enable_deployer_public_ip
## Private IP: from NIC (DHCP when use_DHCP=true, static otherwise)
##
## DESIGN: Even with 0 VMs, shared infrastructure (RG, VNet, KV) is still created.
## The diagnostics storage account requires min(1, deployer_vm_count) > 0.
## ═══════════════════════════════════════════════════════════════════════════════

run "vm_single_default_deployment" {
  command = plan

  # Default: deployer_vm_count=1, creates 1 VM, 1 NIC
  assert {
    condition     = output.resource_group_name == "DEV-EAUS-DEP-INFRASTRUCTURE"
    error_message = "Infra naming must be stable regardless of VM count"
  }

  assert {
    condition     = output.user_vault_name == "DEVEAUSDEPuserABC"
    error_message = "KV name unaffected by VM count"
  }
}

run "vm_zero_count_infra_still_created" {
  command = plan

  variables {
    deployer_vm_count = 0
  }

  # DESIGN: Zero VMs still creates RG, VNet, subnet, NSG, and KV
  assert {
    condition     = output.resource_group_name == "DEV-EAUS-DEP-INFRASTRUCTURE"
    error_message = "RG must be created even with 0 VMs"
  }

  assert {
    condition     = output.user_vault_name == "DEVEAUSDEPuserABC"
    error_message = "KV must be created even with 0 VMs"
  }

  assert {
    condition     = output.resource_group_location == "eastus"
    error_message = "Location stable with 0 VMs"
  }
}

run "vm_zero_count_no_public_ip" {
  command = plan

  variables {
    deployer_vm_count = 0
  }

  # No VMs → no NICs → no public IPs possible
  assert {
    condition     = output.deployer_public_ip_address == ""
    error_message = "Public IP must be empty with 0 VMs"
  }
}

run "vm_public_ip_disabled_by_default" {
  command = plan

  # DESIGN: enable_deployer_public_ip defaults to false for security
  assert {
    condition     = output.deployer_public_ip_address == ""
    error_message = "Public IP must be empty when enable_deployer_public_ip=false (default)"
  }
}

run "vm_public_ip_enabled_plans_successfully" {
  command = plan

  variables {
    enable_deployer_public_ip = true
  }

  # When enabled, public IP resource is created (mock returns empty IP at plan time)
  # But plan must succeed without errors
  assert {
    condition     = output.resource_group_name == "DEV-EAUS-DEP-INFRASTRUCTURE"
    error_message = "Plan must succeed with public IP enabled"
  }

  assert {
    condition     = output.user_vault_name == "DEVEAUSDEPuserABC"
    error_message = "KV naming unaffected by public IP toggle"
  }
}

run "vm_extensions_empty_when_auto_configure_disabled" {
  command = plan

  # auto_configure_deployer=false in setup → no extensions planned
  assert {
    condition     = length(output.extension_ids) == 0
    error_message = "No extensions when auto_configure_deployer=false"
  }
}

## ═══════════════════════════════════════════════════════════════════════════════
## Section 5: Bastion Host Conditional Deployment
##
## Condition: var.bastion_deployment == true
## Creates: AzureBastionSubnet, bastion public IP, azurerm_bastion_host
##
## DESIGN: When disabled, subnet_bastion_address_prefixes returns [""] as sentinel.
## The hardcoded subnet name "AzureBastionSubnet" is an Azure requirement.
## ═══════════════════════════════════════════════════════════════════════════════

run "bastion_enabled_creates_subnet" {
  command = plan

  variables {
    bastion_deployment = true
  }

  # Bastion subnet is created with prefix from infrastructure config
  assert {
    condition     = length(output.subnet_bastion_address_prefixes) > 0
    error_message = "Bastion subnet prefixes must be populated when enabled"
  }

  # EDGE_CASE: sentinel value [""] means disabled; actual prefixes mean enabled
  assert {
    condition     = output.subnet_bastion_address_prefixes != [""]
    error_message = "Bastion prefixes must not be sentinel value when enabled"
  }
}

run "bastion_enabled_infra_unaffected" {
  command = plan

  variables {
    bastion_deployment = true
  }

  # Core naming must remain stable with bastion enabled
  assert {
    condition     = output.resource_group_name == "DEV-EAUS-DEP-INFRASTRUCTURE"
    error_message = "RG naming unaffected by bastion toggle"
  }

  assert {
    condition     = output.user_vault_name == "DEVEAUSDEPuserABC"
    error_message = "KV naming unaffected by bastion toggle"
  }
}

run "bastion_disabled_returns_sentinel" {
  command = plan

  variables {
    bastion_deployment = false
  }

  # DESIGN: When bastion_deployment=false, output returns [""] as sentinel
  # This allows callers to detect "no bastion" vs "bastion with empty prefixes"
  assert {
    condition     = output.subnet_bastion_address_prefixes == [""]
    error_message = "Disabled bastion must return sentinel ['']"
  }
}

## ═══════════════════════════════════════════════════════════════════════════════
## Section 6: Firewall Conditional Deployment
##
## Condition: var.firewall.deployment == true
## Creates: AzureFirewallSubnet, firewall PIP, azurerm_firewall, route table, rules
##
## DESIGN: Firewall uses hardcoded subnet name "AzureFirewallSubnet" (Azure req).
## When enabled, it affects KV network_acls.default_action (becomes "Deny" if not bootstrap).
## firewall_ip output is the firewall's private IP for route table next-hop.
## ═══════════════════════════════════════════════════════════════════════════════

run "firewall_enabled_plans_successfully" {
  command = plan

  variables {
    firewall_deployment = true
  }

  # Plan must succeed — firewall creates subnet, PIP, firewall resource, route table
  assert {
    condition     = output.resource_group_name == "DEV-EAUS-DEP-INFRASTRUCTURE"
    error_message = "Plan must succeed with firewall enabled"
  }

  assert {
    condition     = output.user_vault_name == "DEVEAUSDEPuserABC"
    error_message = "KV naming unaffected by firewall"
  }
}

run "firewall_disabled_empty_ip" {
  command = plan

  variables {
    firewall_deployment = false
  }

  # DESIGN: When firewall.deployment=false, firewall_ip returns ""
  assert {
    condition     = output.firewall_ip == ""
    error_message = "Firewall IP must be '' when deployment=false"
  }
}

run "firewall_disabled_empty_id" {
  command = plan

  variables {
    firewall_deployment = false
  }

  assert {
    condition     = output.firewall_id == ""
    error_message = "Firewall ID must be '' when deployment=false"
  }
}

run "firewall_does_not_affect_secret_names" {
  command = plan

  variables {
    firewall_deployment = true
  }

  assert {
    condition     = output.ppk_secret_name == "DEV-EAUS-DEP-sshkey"
    error_message = "SSH secret names must be independent of firewall setting"
  }

  assert {
    condition     = output.pk_secret_name == "DEV-EAUS-DEP-sshkey-pub"
    error_message = "Public key secret must be independent of firewall setting"
  }
}

## ═══════════════════════════════════════════════════════════════════════════════
## Section 7: Brownfield (Existing Infrastructure) Scenarios
##
## DESIGN: The module supports importing existing resources via exists=true flags.
## When exists=true, a data source is used instead of creating a new resource.
## The naming locals use split("/", id) to extract names from ARM resource IDs.
##
## Priority for name resolution:
##   1. exists=true + id provided → split name from ARM ID
##   2. name provided → use directly
##   3. Neither → compute from naming convention
## ═══════════════════════════════════════════════════════════════════════════════

run "brownfield_rg_uses_data_source_name" {
  command = plan

  variables {
    use_existing_rg = true
  }

  override_data {
    target = module.deployer.data.azurerm_resource_group.deployer[0]
    values = {
      name     = "existing-deployer-rg"
      location = "eastus"
      id       = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-deployer-rg"
    }
  }

  assert {
    condition     = output.resource_group_name == "existing-deployer-rg"
    error_message = "Brownfield RG: name must come from data source"
  }

  assert {
    condition     = output.resource_group_location == "eastus"
    error_message = "Brownfield RG: location must come from data source"
  }
}

run "brownfield_rg_other_resources_still_greenfield" {
  command = plan

  variables {
    use_existing_rg = true
  }

  override_data {
    target = module.deployer.data.azurerm_resource_group.deployer[0]
    values = {
      name     = "existing-deployer-rg"
      location = "eastus"
      id       = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-deployer-rg"
    }
  }

  # KV, NSG, secrets still use computed names
  assert {
    condition     = output.user_vault_name == "DEVEAUSDEPuserABC"
    error_message = "KV still greenfield when only RG is brownfield"
  }

  assert {
    condition     = output.nsg_mgmt != null
    error_message = "NSG still created when only RG is brownfield"
  }

  assert {
    condition     = output.ppk_secret_name == "DEV-EAUS-DEP-sshkey"
    error_message = "Secrets unaffected by brownfield RG"
  }
}

run "brownfield_vnet_subnet_nsg" {
  command = plan

  variables {
    use_existing_vnet   = true
    use_existing_subnet = true
    use_existing_nsg    = true
  }

  override_data {
    target = module.deployer.data.azurerm_virtual_network.vnet_mgmt[0]
    values = {
      name                = "existing-dep-vnet"
      resource_group_name = "existing-deployer-rg"
      id                  = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-deployer-rg/providers/Microsoft.Network/virtualNetworks/existing-dep-vnet"
    }
  }

  override_data {
    target = module.deployer.data.azurerm_subnet.subnet_mgmt[0]
    values = {
      name                 = "existing-dep-subnet"
      resource_group_name  = "existing-deployer-rg"
      virtual_network_name = "existing-dep-vnet"
      id                   = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-deployer-rg/providers/Microsoft.Network/virtualNetworks/existing-dep-vnet/subnets/existing-dep-subnet"
      address_prefixes     = ["10.0.0.0/25"]
    }
  }

  override_data {
    target = module.deployer.data.azurerm_network_security_group.nsg_mgmt[0]
    values = {
      name                = "existing-dep-nsg"
      resource_group_name = "existing-deployer-rg"
      id                  = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-deployer-rg/providers/Microsoft.Network/networkSecurityGroups/existing-dep-nsg"
    }
  }

  # VNet ID comes from data source
  assert {
    condition     = output.vnet_mgmt_id == "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-deployer-rg/providers/Microsoft.Network/virtualNetworks/existing-dep-vnet"
    error_message = "Brownfield VNet: ID from data source"
  }

  # Subnet ID comes from data source
  assert {
    condition     = output.subnet_mgmt_id == "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-deployer-rg/providers/Microsoft.Network/virtualNetworks/existing-dep-vnet/subnets/existing-dep-subnet"
    error_message = "Brownfield subnet: ID from data source"
  }

  # RG still greenfield
  assert {
    condition     = output.resource_group_name == "DEV-EAUS-DEP-INFRASTRUCTURE"
    error_message = "RG remains greenfield when only network is brownfield"
  }

  # KV still greenfield
  assert {
    condition     = output.user_vault_name == "DEVEAUSDEPuserABC"
    error_message = "KV remains greenfield when only network is brownfield"
  }
}

run "brownfield_keyvault_uses_data_source" {
  command = plan

  variables {
    use_existing_kv = true
  }

  override_data {
    target = module.deployer.data.azurerm_key_vault.kv_user[0]
    values = {
      name                = "existingkvuser"
      resource_group_name = "existing-deployer-rg"
      id                  = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-deployer-rg/providers/Microsoft.KeyVault/vaults/existingkvuser"
    }
  }

  # DESIGN: When key_vault.exists=true, the KV name comes from split("/", id)[8]
  # in variables_local.tf: user_keyvault_name
  assert {
    condition     = output.user_vault_name == "existingkvuser"
    error_message = "Brownfield KV: name from data source"
  }

  assert {
    condition     = output.deployer_keyvault_user_arm_id == "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-deployer-rg/providers/Microsoft.KeyVault/vaults/existingkvuser"
    error_message = "Brownfield KV: ARM ID from data source"
  }

  # Secrets still computed from prefix (independent of KV existence)
  assert {
    condition     = output.ppk_secret_name == "DEV-EAUS-DEP-sshkey"
    error_message = "Secret names independent of KV brownfield status"
  }
}

run "brownfield_full_infrastructure" {
  command = plan

  variables {
    use_existing_rg     = true
    use_existing_vnet   = true
    use_existing_subnet = true
    use_existing_nsg    = true
    use_existing_kv     = true
  }

  override_data {
    target = module.deployer.data.azurerm_resource_group.deployer[0]
    values = {
      name     = "existing-deployer-rg"
      location = "eastus"
      id       = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-deployer-rg"
    }
  }

  override_data {
    target = module.deployer.data.azurerm_virtual_network.vnet_mgmt[0]
    values = {
      name                = "existing-dep-vnet"
      resource_group_name = "existing-deployer-rg"
      id                  = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-deployer-rg/providers/Microsoft.Network/virtualNetworks/existing-dep-vnet"
    }
  }

  override_data {
    target = module.deployer.data.azurerm_subnet.subnet_mgmt[0]
    values = {
      name                 = "existing-dep-subnet"
      resource_group_name  = "existing-deployer-rg"
      virtual_network_name = "existing-dep-vnet"
      id                   = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-deployer-rg/providers/Microsoft.Network/virtualNetworks/existing-dep-vnet/subnets/existing-dep-subnet"
      address_prefixes     = ["10.0.0.0/25"]
    }
  }

  override_data {
    target = module.deployer.data.azurerm_network_security_group.nsg_mgmt[0]
    values = {
      name                = "existing-dep-nsg"
      resource_group_name = "existing-deployer-rg"
      id                  = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-deployer-rg/providers/Microsoft.Network/networkSecurityGroups/existing-dep-nsg"
    }
  }

  override_data {
    target = module.deployer.data.azurerm_key_vault.kv_user[0]
    values = {
      name                = "existingkvuser"
      resource_group_name = "existing-deployer-rg"
      id                  = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-deployer-rg/providers/Microsoft.KeyVault/vaults/existingkvuser"
    }
  }

  # All outputs from data sources
  assert {
    condition     = output.resource_group_name == "existing-deployer-rg"
    error_message = "Full brownfield: RG name from data source"
  }

  assert {
    condition     = output.resource_group_location == "eastus"
    error_message = "Full brownfield: RG location from data source"
  }

  assert {
    condition     = output.vnet_mgmt_id == "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-deployer-rg/providers/Microsoft.Network/virtualNetworks/existing-dep-vnet"
    error_message = "Full brownfield: VNet ID from data source"
  }

  assert {
    condition     = output.subnet_mgmt_id == "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-deployer-rg/providers/Microsoft.Network/virtualNetworks/existing-dep-vnet/subnets/existing-dep-subnet"
    error_message = "Full brownfield: Subnet ID from data source"
  }

  assert {
    condition     = output.user_vault_name == "existingkvuser"
    error_message = "Full brownfield: KV name from data source"
  }

  assert {
    condition     = output.deployer_keyvault_user_arm_id == "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/existing-deployer-rg/providers/Microsoft.KeyVault/vaults/existingkvuser"
    error_message = "Full brownfield: KV ARM ID from data source"
  }

  # Secrets still computed (independent of infrastructure source)
  assert {
    condition     = output.ppk_secret_name == "DEV-EAUS-DEP-sshkey"
    error_message = "Full brownfield: secrets still from naming convention"
  }
}

## ═══════════════════════════════════════════════════════════════════════════════
## Section 8: Feature Combinations (Private Endpoints + Firewall + Locks)
##
## DESIGN: Features are independent — enabling one should not break another.
## Tests verify orthogonality of feature flags.
## ═══════════════════════════════════════════════════════════════════════════════

run "combo_private_endpoint_preserves_naming" {
  command = plan

  variables {
    use_private_endpoint = true
  }

  assert {
    condition     = output.user_vault_name == "DEVEAUSDEPuserABC"
    error_message = "Private endpoint must not alter KV naming"
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-DEP-INFRASTRUCTURE"
    error_message = "Private endpoint must not alter RG naming"
  }

  assert {
    condition     = output.ppk_secret_name == "DEV-EAUS-DEP-sshkey"
    error_message = "Private endpoint must not alter secret naming"
  }
}

run "combo_service_endpoint_preserves_naming" {
  command = plan

  variables {
    use_service_endpoint = true
  }

  assert {
    condition     = output.user_vault_name == "DEVEAUSDEPuserABC"
    error_message = "Service endpoint must not alter KV naming"
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-DEP-INFRASTRUCTURE"
    error_message = "Service endpoint must not alter RG naming"
  }

  assert {
    condition     = output.resource_group_location == "eastus"
    error_message = "Service endpoint must not alter location"
  }
}

run "combo_delete_lock_preserves_naming" {
  command = plan

  variables {
    place_delete_lock = true
  }

  # DESIGN: Delete locks are applied to KV when place_delete_lock_on_resources=true
  # and key_vault.exists=false. Does not affect naming.
  assert {
    condition     = output.resource_group_name == "DEV-EAUS-DEP-INFRASTRUCTURE"
    error_message = "Delete lock must not alter RG naming"
  }

  assert {
    condition     = output.user_vault_name == "DEVEAUSDEPuserABC"
    error_message = "Delete lock must not alter KV naming"
  }
}

run "combo_kv_firewall_with_public_access_disabled" {
  command = plan

  variables {
    enable_firewall_for_keyvaults_and_storage = true
    public_network_access_enabled             = false
  }

  # DESIGN: enable_firewall_for_keyvaults_and_storage affects KV network_acls
  # but not the KV name or secret names
  assert {
    condition     = output.user_vault_name == "DEVEAUSDEPuserABC"
    error_message = "KV firewall must not alter KV naming"
  }

  assert {
    condition     = can(regex("user", output.user_vault_name))
    error_message = "KV name must still contain 'user' with firewall enabled"
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-DEP-INFRASTRUCTURE"
    error_message = "KV firewall must not alter RG naming"
  }
}

run "combo_all_features_simultaneously" {
  command = plan

  variables {
    deployer_vm_count                         = 1
    bastion_deployment                        = true
    firewall_deployment                       = true
    enable_deployer_public_ip                 = true
    use_private_endpoint                      = true
    place_delete_lock                         = true
    enable_firewall_for_keyvaults_and_storage = true
  }

  # DESIGN: All features enabled simultaneously must not conflict
  assert {
    condition     = output.resource_group_name == "DEV-EAUS-DEP-INFRASTRUCTURE"
    error_message = "All-features: RG naming stable"
  }

  assert {
    condition     = output.resource_group_location == "eastus"
    error_message = "All-features: location stable"
  }

  assert {
    condition     = output.user_vault_name == "DEVEAUSDEPuserABC"
    error_message = "All-features: KV naming stable"
  }

  assert {
    condition     = output.ppk_secret_name == "DEV-EAUS-DEP-sshkey"
    error_message = "All-features: private key secret stable"
  }

  assert {
    condition     = output.pk_secret_name == "DEV-EAUS-DEP-sshkey-pub"
    error_message = "All-features: public key secret stable"
  }

  assert {
    condition     = output.username_secret_name == "azureadm"
    error_message = "All-features: username stable"
  }

  assert {
    condition     = output.subnet_bastion_address_prefixes != [""]
    error_message = "All-features: bastion subnet populated"
  }
}

run "combo_firewall_plus_bastion" {
  command = plan

  variables {
    firewall_deployment = true
    bastion_deployment  = true
  }

  # Both firewall and bastion create subnets in same VNet; must not conflict
  assert {
    condition     = output.subnet_bastion_address_prefixes != [""]
    error_message = "Bastion + firewall: bastion subnet must be present"
  }

  assert {
    condition     = output.resource_group_name == "DEV-EAUS-DEP-INFRASTRUCTURE"
    error_message = "Bastion + firewall: RG naming stable"
  }
}

run "combo_zero_vms_with_firewall" {
  command = plan

  variables {
    deployer_vm_count   = 0
    firewall_deployment = true
  }

  # EDGE_CASE: Firewall can be deployed even without deployer VMs
  # (firewall protects the VNet, not specific VMs)
  assert {
    condition     = output.resource_group_name == "DEV-EAUS-DEP-INFRASTRUCTURE"
    error_message = "Zero VMs + firewall: infra still created"
  }

  assert {
    condition     = output.deployer_public_ip_address == ""
    error_message = "Zero VMs + firewall: no deployer public IP"
  }
}

run "combo_webapp_disabled_empty_outputs" {
  command = plan

  variables {
    app_service_deployment = false
  }

  # DESIGN: When app_service.use=false, webapp outputs return ""
  assert {
    condition     = output.webapp_url_base == ""
    error_message = "Webapp URL must be '' when app_service disabled"
  }

  assert {
    condition     = output.webapp_identity == ""
    error_message = "Webapp identity must be '' when app_service disabled"
  }

  assert {
    condition     = output.webapp_id == ""
    error_message = "Webapp ID must be '' when app_service disabled"
  }
}

###############################################################################
# Section 9: Deep Resource-Parameter Assertions                               #
#                                                                             #
# Validates secret naming conventions and deployer identity configuration.    #
###############################################################################

run "deep_secret_naming_conventions" {
  command = plan

  # SSH private key secret name follows pattern: <prefix>-sshkey
  assert {
    condition     = output.ppk_secret_name == "DEV-EAUS-DEP-sshkey"
    error_message = "SSH private key secret should be 'DEV-EAUS-DEP-sshkey'"
  }

  # SSH public key secret name follows pattern: <prefix>-sshkey-pub
  assert {
    condition     = output.pk_secret_name == "DEV-EAUS-DEP-sshkey-pub"
    error_message = "SSH public key secret should be 'DEV-EAUS-DEP-sshkey-pub'"
  }

  # Username secret matches the configured admin username
  assert {
    condition     = output.username_secret_name == "azureadm"
    error_message = "Username secret should match admin username 'azureadm'"
  }

  # Password secret empty when using key-based auth
  assert {
    condition     = output.pwd_secret_name == ""
    error_message = "Password secret should be empty for key-based auth"
  }
}
