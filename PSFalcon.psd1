#
# Module manifest for module 'PSFalcon'
#
# Generated by: brendan.kremian@crowdstrike.com
#
# Generated on: 1/15/2021
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'PSFalcon.psm1'

# Version number of this module.
ModuleVersion = '2.0.2'

# Supported PSEditions
CompatiblePSEditions = @('Desktop','Core')

# ID used to uniquely identify this module
GUID = 'd893eb9f-f6bb-4a40-9caf-aaff0e42acd1'

# Author of this module
Author = 'Brendan Kremian'

# Company or vendor of this module
CompanyName = 'CrowdStrike'

# Copyright statement for this module
Copyright = '(c) CrowdStrike. All rights reserved.'

# Description of the functionality provided by this module
Description = "PowerShell for CrowdStrike's OAuth2 APIs"

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.1'

# Name of the PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the
# PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for
# the PowerShell Desktop edition only.
# CLRVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module
ScriptsToProcess = @('Class/Class.ps1')

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry,
# use an empty array if there are no functions to export.
FunctionsToExport = @(
    # cloud-connect-aws
    'Confirm-DiscoverAwsAccess',
    'Edit-DiscoverAwsAccount',
    'Get-DiscoverAwsAccount',
    'Get-DiscoverAwsSettings',
    'New-DiscoverAwsAccount',
    'Remove-DiscoverAwsAccount',
    'Update-DiscoverAwsSettings',

    # cloud-connect-azure
    'Get-DiscoverAzureAccount',
    'Get-DiscoverAzureScript',
    'New-DiscoverAzureAccount',
    'Update-DiscoverAzureAccount',

    # cloud-connect-cspm-aws
    'Get-HorizonAwsAccount',
    'Get-HorizonAwsLink',
    'New-HorizonAwsAccount',
    'Receive-HorizonAwsScript',
    'Remove-HorizonAwsAccount',

    # cloud-connect-cspm-azure
    'Edit-HorizonAzureAccount',
    'Get-HorizonAzureAccount',
    'New-HorizonAzureAccount',
    'Receive-HorizonAzureScript',
    'Remove-HorizonAzureAccount',

    # cloud-connect-gcp
    'Get-DiscoverGcpAccount',
    'New-DiscoverGcpAccount',
    'Receive-DiscoverGcpScript',

    # detects
    'Edit-Detection',
    'Get-Detection',

    # devices
    'Add-HostTag',
    'Edit-HostGroup',
    'Get-Host',
    'Get-HostGroup',
    'Get-HostGroupMember',
    'Invoke-HostAction',
    'Invoke-HostGroupAction',
    'New-HostGroup',
    'Remove-HostGroup',
    'Remove-HostTag',

    # falconx
    'Get-Report',
    'Get-Submission',
    'Get-SubmissionQuota',
    'New-Submission',
    'Receive-Artifact',
    'Remove-Report',

    # fwmgr
    'Edit-FirewallGroup',
    'Edit-FirewallSetting',
    'Get-FirewallEvent',
    'Get-FirewallField',
    'Get-FirewallGroup',
    'Get-FirewallPlatform',
    'Get-FirewallRule',
    'Get-FirewallSetting',
    'New-FirewallGroup',
    'Remove-FirewallGroup',

    # incidents
    'Get-Behavior',
    'Get-Incident',
    'Get-Score',
    'Invoke-IncidentAction',

    # indicators
    'Edit-IOC',
    'Get-IOC',
    'Get-IOCHost',
    'Get-IOCProcess',
    'Get-IOCTotal',
    'New-IOC',
    'Remove-IOC',

    # installation-tokens
    'Edit-InstallToken',
    'Get-InstallToken',
    'Get-InstallTokenEvent',
    'Get-InstallTokenSettings',
    'New-InstallToken',
    'Remove-InstallToken',

    # intel
    'Get-Actor',
    'Get-Indicator',
    'Get-Intel',
    'Get-Rule',
    'Receive-Intel',
    'Receive-Rule',

    # ioarules
    'Edit-IOAGroup',
    'Edit-IOARule',
    'Get-IOAGroup',
    'Get-IOAPlatform',
    'Get-IOARule',
    'Get-IOASeverity',
    'Get-IOAType',
    'New-IOAGroup',
    'New-IOARule',
    'Remove-IOAGroup',
    'Remove-IOARule',
    'Test-IOARule',

    # malquery
    'Get-MalQuery',
    'Get-MalQueryQuota',
    'Get-MalQuerySample',
    'Group-MalQuerySample',
    'Invoke-MalQuery',
    'Receive-MalQuerySample',

    # oauth2
    'Request-Token',
    'Revoke-Token',

    # policy
    'Edit-DeviceControlPolicy',
    'Edit-FirewallPolicy',
    'Edit-IOAExclusion',
    'Edit-MLExclusion',
    'Edit-PreventionPolicy',
    'Edit-ResponsePolicy',
    'Edit-SensorUpdatePolicy',
    'Edit-SVExclusion',
    'Get-Build',
    'Get-DeviceControlPolicy',
    'Get-DeviceControlPolicyMember',
    'Get-FirewallPolicy',
    'Get-FirewallPolicyMember',
    'Get-IOAExclusion',
    'Get-MLExclusion',
    'Get-PreventionPolicy',
    'Get-PreventionPolicyMember',
    'Get-ResponsePolicy',
    'Get-ResponsePolicyMember'
    'Get-SensorUpdatePolicy',
    'Get-SensorUpdatePolicyMember',
    'Get-SVExclusion',
    'Get-UninstallToken',
    'Invoke-DeviceControlPolicyAction',
    'Invoke-FirewallPolicyAction',
    'Invoke-PreventionPolicyAction',
    'Invoke-ResponsePolicyAction',
    'Invoke-SensorUpdatePolicyAction',
    'New-DeviceControlPolicy',
    'New-FirewallPolicy',
    'New-MLExclusion',
    'New-PreventionPolicy',
    'New-ResponsePolicy',
    'New-SensorUpdatePolicy',
    'New-SVExclusion',
    'Remove-DeviceControlPolicy',
    'Remove-FirewallPolicy',
    'Remove-IOAExclusion',
    'Remove-MLExclusion',
    'Remove-PreventionPolicy',
    'Remove-ResponsePolicy',
    'Remove-SensorUpdatePolicy',
    'Remove-SVExclusion',
    'Set-DeviceControlPrecedence',
    'Set-FirewallPrecedence',
    'Set-PreventionPrecedence',
    'Set-ResponsePrecedence',
    'Set-SensorUpdatePrecedence',

    # processes
    'Get-Process',

    # real-time-response
    'Confirm-AdminCommand',
    'Confirm-Command',
    'Confirm-GetFile',
    'Confirm-ResponderCommand',
    'Edit-Script',
    'Get-PutFile',
    'Get-Script',
    'Get-Session',
    'Invoke-AdminCommand',
    'Invoke-BatchGet',
    'Invoke-Command',
    'Invoke-ResponderCommand',
    'Receive-GetFile',
    'Remove-Command',
    'Remove-GetFile',
    'Remove-PutFile',
    'Remove-Script',
    'Remove-Session',
    'Send-PutFile',
    'Send-Script',
    'Start-Session',
    'Update-Session',

    # samples
    'Get-Sample',
    'Receive-Sample',
    'Remove-Sample',
    'Send-Sample',

    # scanner
    'Get-QuickScan',
    'New-QuickScan',

    # scripts
    'Export-Report',
    'Find-Duplicate',
    'Get-Queue',
    'Invoke-Deploy',
    'Invoke-RTR',
    'Open-Stream',
    'Search-MalQueryHash',
    'Show-Map',
    'Show-Module',

    # sensors
    'Get-CCID',
    'Get-Installer',
    'Get-Stream',
    'Receive-Installer',
    'Update-Stream',

    # settings
    'Edit-HorizonPolicy',
    'Edit-HorizonSchedule',
    'Get-HorizonPolicy',
    'Get-HorizonSchedule',

    # spotlight
    'Get-Remediation',
    'Get-Vulnerability',

    # user-roles
    'Add-Role',
    'Get-Role',
    'Remove-Role',

    # users
    'Edit-User',
    'Get-User',
    'New-User',
    'Remove-User'
)

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry,
# use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry,
# use an empty array if there are no aliases to export.
AliasesToExport = @()

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData
# hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('CrowdStrike', 'Falcon', 'OAuth2', 'REST', 'API')

        # A URL to the license for this module.
        # LicenseUri = ''

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/crowdstrike/psfalcon'

        # A URL to an icon representing this module.
        IconUri = 'https://avatars.githubusercontent.com/u/54042976?s=400&u=789014ae9e1ec2204090e90711fa34dd93e5c4d1'

        # ReleaseNotes of this module.
        ReleaseNotes = "v2.0.2:
        * Added 'Show-FalconModule' to output diagnostic information and removed 'Import' message (Issue #21)
        "
    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
HelpInfoURI = 'https://github.com/crowdstrike/psfalcon/blob/master/README.md'

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix
DefaultCommandPrefix = 'Falcon'

}