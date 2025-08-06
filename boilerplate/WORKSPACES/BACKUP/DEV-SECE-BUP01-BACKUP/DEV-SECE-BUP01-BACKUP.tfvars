#==============================================================================
# SAP Backup Infrastructure Configuration - Development Environment
#==============================================================================
# Configuration Name: DEV-SECE-BUP01-BACKUP
# Environment: DEV (Development)
# Region: SECE (Sweden Central)
# Backup Name: BUP01
# Purpose: Development SAP HANA database backup infrastructure
#==============================================================================

#==============================================================================
# NAMING CONVENTION AND REQUIRED CONFIGURATION
#==============================================================================

# backup_configuration_name (REQUIRED)
# Description: Unique identifier for this backup configuration following the SDAF naming convention
# Format: ENV-REGION-LOGICAL_BACKUP_NAME-BACKUP
# Components:
#   - ENV: Environment code (DEV, QA, PRD, TST, etc.)
#   - REGION: Azure region code (SECE, EAUS, WEU2, etc.)
#   - LOGICAL_BACKUP_NAME: Logical name for this backup configuration (BUP01, BUP02, etc.)
#   - BACKUP: Fixed suffix indicating this is a backup configuration
# Examples:
#   - DEV-SECE-BUP01-BACKUP (Development environment in Sweden Central)
#   - PRD-EAUS-BUP01-BACKUP (Production environment in East US)
#   - QA-WEU2-BUP02-BACKUP (QA environment in West Europe 2, second backup config)
backup_configuration_name = "DEV-SECE-BUP01-BACKUP"

#==============================================================================
# SAP NETWORK INTEGRATION CONFIGURATION
#==============================================================================

# sap_vnet_id (REQUIRED)
# Description: Full Azure resource ID of the SAP VNet that contains the HANA systems to be backed up
# Format: /subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Network/virtualNetworks/{vnet-name}
# Purpose: This VNet will be connected to the backup infrastructure for secure communication
# Example: /subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-dev-sece-sap-landscape/providers/Microsoft.Network/virtualNetworks/vnet-dev-sece-sap
sap_vnet_id = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-dev-sece-sap-landscape/providers/Microsoft.Network/virtualNetworks/vnet-dev-sece-sap"

# sap_vnet_name (REQUIRED)
# Description: Name of the SAP VNet (must match the VNet specified in sap_vnet_id)
# Purpose: Used for DNS linking and network configuration
sap_vnet_name = "vnet-dev-sece-sap"

# sap_network_resource_group (REQUIRED)
# Description: Resource group name where the SAP network resources are located
# Purpose: Required for accessing existing network resources and creating network links
sap_network_resource_group = "rg-dev-sece-sap-landscape"

#==============================================================================
# NETWORK DEPLOYMENT OPTIONS
#==============================================================================

# use_existing_sap_network (OPTIONAL)
# Description: Choose whether to use existing SAP network infrastructure or create new dedicated backup network
# Values:
#   - true: Use existing subnet within the SAP VNet for backup traffic
#   - false: Create new dedicated VNet and subnet for backup infrastructure
# Recommendation:
#   - Development: false (for isolation and testing)
#   - Production: true (for integration with existing network security policies)
use_existing_sap_network = false

# existing_backup_subnet_name (CONDITIONAL - Required if use_existing_sap_network = true)
# Description: Name of the existing subnet within the SAP VNet to use for backup traffic
# Purpose: This subnet should have appropriate network security group rules for backup communication
# Note: Only used when use_existing_sap_network = true
existing_backup_subnet_name = ""

# existing_backup_subnet_resource_group (CONDITIONAL - Required if use_existing_sap_network = true)
# Description: Resource group containing the existing backup subnet
# Purpose: Required for accessing the existing subnet configuration
# Note: Only used when use_existing_sap_network = true
existing_backup_subnet_resource_group = ""

#------------------------------------------------------------------------------
# NEW VNET CONFIGURATION (Used when use_existing_sap_network = false)
#------------------------------------------------------------------------------

# backup_vnet_address_space (CONDITIONAL - Required if use_existing_sap_network = false)
# Description: IP address space for the new backup VNet
# Format: List of CIDR blocks
# Purpose: Defines the overall address space for backup infrastructure
# Recommendations:
#   - Use non-overlapping address space with existing SAP networks
#   - Ensure sufficient IP addresses for future expansion
#   - Development: Smaller address space is acceptable
#   - Production: Plan for growth and multiple environments
backup_vnet_address_space = ["10.100.0.0/16"]

# backup_subnet_address_prefixes (CONDITIONAL - Required if use_existing_sap_network = false)
# Description: IP address prefixes for the backup subnet within the backup VNet
# Format: List of CIDR blocks (must be subset of backup_vnet_address_space)
# Purpose: Defines the specific subnet for backup resources and private endpoints
# Recommendations:
#   - /24 subnet provides 254 usable IP addresses (sufficient for most scenarios)
#   - Consider future expansion when sizing
backup_subnet_address_prefixes = ["10.100.1.0/24"]

#==============================================================================
# INFRASTRUCTURE RESOURCE GROUP CONFIGURATION
#==============================================================================

# infrastructure (OPTIONAL)
# Description: Override default infrastructure settings
# Purpose: Allows customization of resource group naming and management
infrastructure = {
  # resource_group.name (OPTIONAL)
  # Description: Custom name for the backup resource group
  # Default: Auto-generated based on naming convention (rg-{env}-{region}-{backup-name}-backup)
  # Example: "rg-dev-sece-bup01-backup"
  # When to customize: When organization has specific naming requirements

  # resource_group.use_existing (OPTIONAL)
  # Description: Whether to use an existing resource group or create a new one
  # Values:
  #   - false: Create new resource group (recommended for most scenarios)
  #   - true: Use existing resource group (name must be specified)
  # Default: false
  resource_group = {
    name         = "rg-dev-sece-bup01-backup"
    use_existing = false
  }
}

#==============================================================================
# RECOVERY SERVICES VAULT CONFIGURATION
#==============================================================================

# backup_configuration (OPTIONAL)
# Description: Configuration for the Azure Recovery Services Vault and backup infrastructure
# Purpose: Defines the backup vault characteristics, security, and operational settings
backup_configuration = {

  # vault_sku (OPTIONAL)
  # Description: SKU/tier of the Recovery Services Vault
  # Values:
  #   - "Standard": Standard tier with basic features (suitable for dev/test)
  #   - "Enhanced": Enhanced tier with advanced features (recommended for production)
  # Default: "Standard"
  # Cost Impact: Enhanced SKU has higher cost but provides better features
  # Recommendation: Standard for development, Enhanced for production
  vault_sku = "Standard"

  # storage_mode_type (OPTIONAL)
  # Description: Backup data storage redundancy mode
  # Values:
  #   - "LocallyRedundant": Data stored locally within the region (lowest cost)
  #   - "GeoRedundant": Data replicated to paired region (higher cost, better protection)
  #   - "ReadAccessGeoRedundant": Geo-redundant with read access to secondary region
  # Default: "LocallyRedundant"
  # Cost Impact: GRS costs more but provides better disaster recovery
  # Recommendation: LRS for development, GRS for production
  storage_mode_type = "LocallyRedundant"

  # cross_region_restore_enabled (OPTIONAL)
  # Description: Enable restore from backup data in the paired Azure region
  # Values: true/false
  # Default: false
  # Requirements: Only available with GeoRedundant storage mode
  # Use Case: Disaster recovery scenarios where primary region is unavailable
  # Recommendation: false for development, true for production with GRS
  cross_region_restore_enabled = false

  # soft_delete_enabled (OPTIONAL)
  # Description: Enable soft delete protection for backup data
  # Values: true/false
  # Default: true
  # Purpose: Protects against accidental deletion of backup data
  # Behavior: Deleted backup data is retained for 14 days before permanent deletion
  # Recommendation: true for all environments (security best practice)
  soft_delete_enabled = true

  # public_network_access_enabled (OPTIONAL)
  # Description: Allow public internet access to the Recovery Services Vault
  # Values: true/false
  # Default: false
  # Security Impact: false provides better security by requiring private connectivity
  # Recommendation: false for all environments (security best practice)
  public_network_access_enabled = false

  # enable_private_endpoint (OPTIONAL)
  # Description: Create private endpoint for secure connectivity to Recovery Services Vault
  # Values: true/false
  # Default: true
  # Purpose: Enables secure communication over private network
  # Requirements: Requires subnet for private endpoint deployment
  # Recommendation: true for all environments (security best practice)
  enable_private_endpoint = true

  # create_key_vault (OPTIONAL)
  # Description: Create dedicated Azure Key Vault for backup-related secrets
  # Values: true/false
  # Default: false
  # Use Case: Store backup-related credentials, certificates, or keys
  # Recommendation: false unless specific secrets management is required
  create_key_vault = false

  # encryption_key_id (OPTIONAL)
  # Description: Azure Key Vault key ID for customer-managed encryption
  # Format: Full Key Vault key URL
  # Default: null (uses Microsoft-managed keys)
  # Example: "https://myvault.vault.azure.net/keys/mykey/version"
  # Use Case: Organizations requiring customer-managed encryption keys
  # Requirements: Requires Key Vault and appropriate permissions
  encryption_key_id = null

  # infrastructure_encryption_enabled (OPTIONAL)
  # Description: Enable additional layer of encryption at the infrastructure level
  # Values: true/false
  # Default: false
  # Purpose: Provides double encryption (service + infrastructure level)
  # Use Case: High-security environments requiring multiple encryption layers
  # Cost Impact: May have slight performance impact
  # Recommendation: false unless required by compliance
  infrastructure_encryption_enabled = false
}

#==============================================================================
# SAP HANA BACKUP POLICY CONFIGURATION
#==============================================================================

# backup_policy (OPTIONAL)
# Description: Comprehensive backup policy configuration for SAP HANA databases
# Purpose: Defines backup frequency, timing, and retention requirements
# Note: All parameters are optional and will use sensible defaults if not specified
backup_policy = {

  # time_zone (OPTIONAL)
  # Description: Timezone for backup scheduling
  # Format: Standard timezone names (Windows timezone format)
  # Default: "UTC"
  # Examples: "UTC", "W. Europe Standard Time", "Eastern Standard Time", "Pacific Standard Time"
  # Purpose: Ensures backups run at the correct local time
  # Recommendation: Use local datacenter timezone for operational alignment
  time_zone = "W. Europe Standard Time"

  # compression_enabled (OPTIONAL)
  # Description: Enable backup data compression
  # Values: true/false
  # Default: false
  # Benefits: Reduces backup storage requirements and transfer time
  # Drawbacks: Increases CPU usage during backup operations
  # Recommendation: false for development (faster backups), true for production (storage efficiency)
  compression_enabled = false

  #----------------------------------------------------------------------------
  # FULL BACKUP CONFIGURATION
  #----------------------------------------------------------------------------
  # Description: Complete database backup containing all data and transaction logs
  # Purpose: Provides full recovery point for database restoration
  # Frequency: Should be balanced between recovery requirements and performance impact
  full_backup = {

    # frequency (OPTIONAL)
    # Description: How often full backups are performed
    # Values: "Daily" or "Weekly"
    # Default: "Weekly"
    # Considerations:
    #   - Daily: Better recovery point objective (RPO), higher storage cost
    #   - Weekly: Lower storage cost, longer recovery time from incremental backups
    # Recommendation: Weekly for development, Daily for production
    frequency = "Weekly"

    # time (OPTIONAL)
    # Description: Time of day when full backup starts
    # Format: "HH:MM" in 24-hour format
    # Default: "23:00"
    # Considerations: Schedule during low-activity periods to minimize performance impact
    # Recommendation: Late night hours when SAP system usage is minimal
    time = "23:00"

    # weekdays (CONDITIONAL)
    # Description: Days of the week when full backup runs (only used when frequency = "Weekly")
    # Values: List of day names ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    # Default: ["Sunday"]
    # Recommendation: Weekend day to minimize business impact
    weekdays = ["Sunday"]

    #--------------------------------------------------------------------------
    # FULL BACKUP RETENTION POLICIES
    #--------------------------------------------------------------------------

    # retention_weekly (OPTIONAL)
    # Description: Weekly retention policy for full backups
    retention_weekly = {
      # count: Number of weekly backups to retain
      # Default: 12 (3 months of weekly backups)
      # Recommendation: 4-12 weeks depending on recovery requirements
      count = 12

      # weekdays: Which weekdays to retain for weekly backups
      # Default: ["Sunday"]
      # Note: Should align with full backup schedule
      weekdays = ["Sunday"]
    }

    # retention_monthly (OPTIONAL)
    # Description: Monthly retention policy for full backups
    retention_monthly = {
      # count: Number of monthly backups to retain
      # Default: 12 (1 year of monthly backups)
      # Recommendation: 12-24 months for compliance requirements
      count = 12

      # weekdays: Which weekdays to retain for monthly backups
      # Default: ["Sunday"]
      weekdays = ["Sunday"]

      # weeks: Which week of the month to retain
      # Values: ["First", "Second", "Third", "Fourth", "Last"]
      # Default: ["First"]
      # Recommendation: "First" for consistent monthly backup timing
      weeks = ["First"]
    }

    # retention_yearly (OPTIONAL)
    # Description: Yearly retention policy for full backups
    retention_yearly = {
      # count: Number of yearly backups to retain
      # Default: 7 years
      # Consideration: Adjust based on compliance and legal requirements
      count = 7

      # weekdays: Which weekdays to retain for yearly backups
      # Default: ["Sunday"]
      weekdays = ["Sunday"]

      # weeks: Which week of the month to retain for yearly backups
      # Default: ["First"]
      weeks = ["First"]

      # months: Which months to retain yearly backups
      # Default: ["January"]
      # Recommendation: Beginning of fiscal year for consistency
      months = ["January"]
    }
  }

  #----------------------------------------------------------------------------
  # INCREMENTAL BACKUP CONFIGURATION
  #----------------------------------------------------------------------------
  # Description: Backup of changes since the last full or incremental backup
  # Purpose: Provides frequent recovery points with minimal storage overhead
  # Benefits: Faster backup operations, lower storage requirements
  incremental_backup = {

    # frequency (OPTIONAL)
    # Description: How often incremental backups are performed
    # Values: "Daily" (multiple times per day not currently supported)
    # Default: "Daily"
    # Note: Incremental backups complement full backups
    frequency = "Daily"

    # time (OPTIONAL)
    # Description: Time of day when incremental backup starts
    # Format: "HH:MM" in 24-hour format
    # Default: "01:00"
    # Recommendation: Schedule between full backup days, during low-activity periods
    time = "01:00"

    # weekdays (OPTIONAL)
    # Description: Days of the week when incremental backup runs
    # Default: All weekdays except full backup day
    # Purpose: Ensures daily backup coverage without overlap
    weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    # retention_days (OPTIONAL)
    # Description: Number of days to retain incremental backups
    # Default: 30 days
    # Consideration: Balance between recovery granularity and storage cost
    # Recommendation: 7-30 days depending on business requirements
    retention_days = 30
  }

  #----------------------------------------------------------------------------
  # TRANSACTION LOG BACKUP CONFIGURATION
  #----------------------------------------------------------------------------
  # Description: Continuous backup of transaction log records
  # Purpose: Enables point-in-time recovery with minimal data loss
  # Importance: Critical for achieving low Recovery Point Objective (RPO)
  log_backup = {

    # frequency_in_minutes (OPTIONAL)
    # Description: Interval between transaction log backups in minutes
    # Values: 15, 30, 60, 120 (common intervals)
    # Default: 15 minutes
    # RPO Impact: Lower values = better RPO but more backup operations
    # Recommendation: 15 minutes for production, 30-60 minutes for development
    frequency_in_minutes = 15

    # retention_days (OPTIONAL)
    # Description: Number of days to retain transaction log backups
    # Default: 7 days
    # Consideration: Must be sufficient to cover recovery scenarios
    # Recommendation: 7-35 days depending on recovery requirements
    # Note: Log backups enable point-in-time recovery within this window
    retention_days = 7
  }
}

#==============================================================================
# SAP SYSTEMS TARGET CONFIGURATION
#==============================================================================
# Description: Define which SAP HANA systems should be included in this backup configuration
# Two methods available: Explicit system specification OR Workload zone discovery
# Recommendation: Use explicit specification for precise control, workload zones for automation

#------------------------------------------------------------------------------
# METHOD 1: EXPLICIT SAP SYSTEM SPECIFICATION (OPTIONAL)
#------------------------------------------------------------------------------
# Description: Explicitly list each SAP system to be backed up
# Use Case: When you need precise control over which systems are backed up
# Benefits: Clear, explicit configuration; easy to audit
# Drawbacks: Requires manual maintenance when systems are added/removed

sap_systems = [
  {
    # sid (REQUIRED)
    # Description: SAP System Identifier (SID)
    # Format: 3-character alphanumeric identifier
    # Examples: "DEV", "QAS", "PRD", "S4H", "ECC"
    # Purpose: Identifies the specific SAP system instance
    sid = "DEV"

    # environment (REQUIRED)
    # Description: Environment designation for this SAP system
    # Values: "DEV", "QAS", "PRD", "TST", "SBX", etc.
    # Purpose: Used for environment-based filtering and organization
    # Note: Should match the environment in backup_configuration_name
    environment = "DEV"

    # resource_group_name (REQUIRED)
    # Description: Azure resource group containing the SAP HANA virtual machines
    # Format: Standard Azure resource group name
    # Purpose: Locates the VMs that need backup agent configuration
    # Example: "rg-dev-sece-sap-system-dev"
    resource_group_name = "rg-dev-sece-sap-system-dev"

    # hana_instance_number (REQUIRED)
    # Description: SAP HANA instance number
    # Format: 2-digit number (00-99)
    # Common Values: "00", "10", "20", etc.
    # Purpose: Identifies the specific HANA instance on multi-instance systems
    # Default: "00" for single-instance systems
    hana_instance_number = "00"

    # database_names (OPTIONAL)
    # Description: List of specific databases to backup within the HANA instance
    # Format: List of database names
    # Default: [] (empty list means backup all databases)
    # Common Values: ["SYSTEMDB", "DEV"], ["SYSTEMDB", "PRD"], etc.
    # Purpose: Allows selective backup of specific databases
    # Recommendation: Include SYSTEMDB and tenant databases as needed
    database_names = ["SYSTEMDB", "DEV"]

    # exclude_from_backup (OPTIONAL)
    # Description: Whether to exclude this system from backup operations
    # Values: true/false
    # Default: false
    # Use Case: Temporarily disable backup for a system without removing configuration
    # Purpose: Provides flexibility for maintenance or decommissioning scenarios
    exclude_from_backup = false
  }

  # Additional SAP systems can be added here following the same structure
  # Example for a second system:
  # {
  #   sid                    = "QAS"
  #   environment           = "DEV"  # Same environment, different SID
  #   resource_group_name   = "rg-dev-sece-sap-system-qas"
  #   hana_instance_number  = "00"
  #   database_names        = ["SYSTEMDB", "QAS"]
  #   exclude_from_backup   = false
  # }
]

#------------------------------------------------------------------------------
# METHOD 2: WORKLOAD ZONE DISCOVERY (OPTIONAL)
#------------------------------------------------------------------------------
# Description: Automatically discover SAP systems from existing SDAF workload zones
# Use Case: When SAP systems are deployed using SDAF and you want automatic discovery
# Benefits: Automatic discovery, reduces manual configuration maintenance
# Requirements: SAP systems must be deployed using SDAF with proper state management

target_workload_zones = [
  {
    # code (REQUIRED)
    # Description: Workload zone code/identifier
    # Format: Follows SDAF naming convention (ENV-REGION-ZONE_NAME)
    # Example: "DEV-SECE-SAP01"
    # Purpose: Identifies the specific workload zone to scan for SAP systems
    code = "DEV-SECE-SAP01"

    # environment (REQUIRED)
    # Description: Environment of the workload zone
    # Values: "DEV", "QAS", "PRD", "TST", etc.
    # Purpose: Used for filtering and validation
    # Note: Should match the environment in backup_configuration_name
    environment = "DEV"

    # region (REQUIRED)
    # Description: Azure region of the workload zone
    # Format: Full Azure region name
    # Examples: "swedencentral", "eastus", "westeurope"
    # Purpose: Locates the workload zone resources for system discovery
    region = "swedencentral"
  }

  # Additional workload zones can be added here
  # Example for multiple zones in the same environment:
  # {
  #   code        = "DEV-SECE-SAP02"
  #   environment = "DEV"
  #   region      = "swedencentral"
  # }
]

#==============================================================================
# CUSTOM TAGS AND METADATA
#==============================================================================
# Description: Apply custom tags to all backup infrastructure resources
# Purpose: Enables cost tracking, compliance, governance, and resource organization
# Behavior: These tags are applied to ALL resources created by this backup configuration

#------------------------------------------------------------------------------
# RESOURCE TAGGING CONFIGURATION
#------------------------------------------------------------------------------
# Description: Define custom tags for resource organization and management
# Common Use Cases:
#   - Cost center allocation and chargebacks
#   - Compliance and governance requirements
#   - Environment classification and lifecycle management
#   - Project tracking and ownership identification
#   - Backup policy and SLA tracking

custom_tags = {
  # Cost Management and Billing
  # Description: Tags for financial tracking and cost allocation
  "CostCenter"     = "CC-SAP-BACKUP-001"      # Cost center for chargeback/allocation
  "Project"        = "SAP-HANA-DR"            # Project or initiative name
  "BudgetCode"     = "PROJ-2024-SAP-BU"       # Budget allocation code

  # Governance and Compliance
  # Description: Tags for regulatory and organizational compliance
  "DataClass"      = "Confidential"           # Data classification level
  "Compliance"     = "SOX,GDPR"               # Applicable compliance frameworks
  "RetentionClass" = "7Years"                 # Data retention requirements

  # Operational Management
  # Description: Tags for day-to-day operations and management
  "Owner"          = "SAP-Platform-Team"      # Team or individual responsible
  "Contact"        = "sap-team@company.com"   # Contact for questions/issues
  "Schedule"       = "24x7"                   # Operational schedule/availability

  # Backup and Recovery Specific
  # Description: Tags specific to backup operations and requirements
  "BackupType"     = "HANA-Database"          # Type of backup (Database, Files, etc.)
  "RPO"            = "15-minutes"             # Recovery Point Objective
  "RTO"            = "4-hours"                # Recovery Time Objective
  "BackupTier"     = "Premium"                # Backup service tier/SLA level

  # Technical Classification
  # Description: Tags for technical categorization and automation
  "Service"        = "SAP-HANA"               # Service or application type
  "Platform"       = "Azure-IaaS"            # Platform type
  "Automation"     = "SDAF-Managed"          # Automation framework used

  # Environment and Lifecycle
  # Description: Tags for environment management and lifecycle tracking
  "Environment"    = "Development"            # Environment designation
  "LifecycleStage" = "Active"                # Current lifecycle stage
  "Provisioning"   = "Terraform"             # Provisioning method

  # Security and Access
  # Description: Tags for security classification and access control
  "SecurityZone"   = "Restricted"            # Security zone classification
  "AccessTier"     = "PrivateOnly"           # Access restriction level
  "EncryptionReq"  = "Required"              # Encryption requirements

  # Monitoring and Alerting
  # Description: Tags for monitoring and notification configuration
  "MonitoringTier" = "Enhanced"              # Level of monitoring required
  "AlertingGroup"  = "SAP-Operations"        # Team for alerts and notifications
  "SLAClass"       = "Business-Critical"     # Service level classification
}

#------------------------------------------------------------------------------
# TAG VALIDATION NOTES
#------------------------------------------------------------------------------
# Important Considerations:
# 1. Tag Values: Azure tag values have a 256-character limit
# 2. Tag Names: Tag names have a 512-character limit and are case-insensitive
# 3. Tag Count: Maximum of 50 tags per resource
# 4. Reserved Tags: Avoid using Azure-reserved tag prefixes (microsoft, azure, windows)
# 5. Consistency: Maintain consistent tag naming conventions across your organization
# 6. Automation: These tags can be used for automated cost allocation and resource management

# Azure Policy Considerations:
# - Many organizations have Azure Policies that require specific tags
# - Ensure custom_tags comply with your organization's tagging policies
# - Common required tags include: Environment, Owner, CostCenter, Project
