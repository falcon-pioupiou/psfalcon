function Export-FalconReport {
<#
.Synopsis
Format a response object and output to CSV
.Parameter Path
Destination path
.Parameter Object
A result object to format (can be passed via pipeline)
#>
param()
begin {}
process {}
end {}
}
function Export-FalconConfig {
<#
.Synopsis
Create an archive containing exported Falcon configuration files
.Description
Uses various PSFalcon commands to gather and export Groups, Policies and Exclusions as a collection of Json files
within a zip archive. The exported files can be used with 'Import-FalconConfig' to restore configurations to your
existing CID, or create them in another CID.
.Parameter Items
Items to export from your current CID; leave blank to export all available items
.Example
PS>Export-FalconConfig

Creates '.\FalconConfig_<FileDate>.zip' with all available configuration files.
.Example
PS>Export-FalconConfig -Items HostGroup, FirewallGroup, FirewallPolicy

Creates '.\FalconConfig_<FileDate>.zip' with HostGroup, FirewallGroup (including Firewall Rules),
and FirewallPolicy configuration files.
#>
    [CmdletBinding(DefaultParameterSetName = 'ExportItems')]
    param(
        [Parameter(ParameterSetName = 'ExportItems', Position = 1)]
        [ValidateSet('HostGroup', 'IoaGroup', 'FirewallGroup', 'DeviceControlPolicy', 'FirewallPolicy',
            'PreventionPolicy', 'ResponsePolicy', 'SensorUpdatePolicy', 'Ioc', 'IoaExclusion', 'MlExclusion',
            'SvExclusion')]
        [array] $Items
    )
    begin {
        function Get-ItemContent ($Item) {
            # Request content for provided 'Item'
            Write-Host "Exporting '$Item'..."
            $ItemFile = Join-Path -Path $Location -ChildPath "$Item.json"
            $Param = @{
                Detailed = $true
                All = $true
            }
            $FileContent = if ($Item -match '^(DeviceControl|Firewall|Prevention|Response|SensorUpdate)Policy$') {
                # Create policy exports in 'platform_name' order to retain precedence
                @('Windows','Mac','Linux').foreach{
                    & "Get-Falcon$($Item)" @Param -Filter "platform_name:'$_'+name:!'platform_default'" 2>$null
                }
            } else {
                & "Get-Falcon$($Item)" @Param 2>$null
            }
            if ($FileContent -and $Item -eq 'FirewallPolicy') {
                # Export firewall settings
                Write-Host "Exporting 'FirewallSetting'..."
                $Settings = Get-FalconFirewallSetting -Ids $FileContent.id 2>$null
                foreach ($Result in $Settings) {
                    ($FileContent | Where-Object { $_.id -eq $Result.policy_id }).PSObject.Properties.Add(
                        (New-Object PSNoteProperty('settings', $Result)))
                }
            }
            if ($FileContent) {
                # Export results to json file and output created file name
                ConvertTo-Json -InputObject @( $FileContent ) -Depth 16 | Out-File -FilePath $ItemFile -Append
                $ItemFile
            }
        }
        # Get current location
        $Location = (Get-Location).Path
        $Export = if ($PSBoundParameters.Items) {
            # Use specified items
            $PSBoundParameters.Items
        } else {
            # Use items in 'ValidateSet' when not provided
            (Get-Command $MyInvocation.MyCommand.Name).ParameterSets.Where({ $_.Name -eq
            'ExportItems' }).Parameters.Where({ $_.Name -eq 'Items' }).Attributes.ValidValues
        }
        # Set output archive path
        $ArchiveFile = Join-Path $Location -ChildPath "FalconConfig_$(Get-Date -Format FileDate).zip"
    }
    process {
        if (Test-Path $ArchiveFile) {
            throw "An item with the specified name $ArchiveFile already exists."
        }
        [array] $Export += switch ($Export) {
            { $_ -match '^((Ioa|Ml|Sv)Exclusion|Ioc)$' -and $Export -notcontains 'HostGroup' } {
                # Force 'HostGroup' when exporting Exclusions or IOCs
                'HostGroup'
            }
            { $_ -contains 'FirewallGroup' } {
                # Force 'FirewallRule' when exporting 'FirewallGroup'
                'FirewallRule'
            }
        }
        $JsonFiles = foreach ($Item in $Export) {
            # Retrieve results, export to Json and capture file name
            ,(Get-ItemContent -Item $Item)
        }
        if ($JsonFiles) {
            # Archive Json exports with content
            $Param = @{
                Path = (Get-ChildItem | Where-Object { $JsonFiles -contains $_.FullName -and
                    $_.Length -gt 0 }).FullName
                DestinationPath = $ArchiveFile
            }
            Compress-Archive @Param
            if (Test-Path $ArchiveFile) {
                # Display created archive
                Get-ChildItem $ArchiveFile
            }
            if (Test-Path $JsonFiles) {
                # Remove Json files when archived
                Remove-Item -Path $JsonFiles -Force
            }
        }
    }
}
function Find-FalconDuplicate {
<#
.Synopsis
Find duplicate hosts within your Falcon environment
.Description
If the 'Hosts' parameter is not provided, all Host information will be retrieved. An error will be displayed if
required fields 'cid', 'device_id', 'first_seen', 'last_seen', 'hostname' and any defined 'filter' value are
not present.

Hosts are grouped by 'cid', 'hostname' and any defined 'filter' value, then sorted by 'last_seen' time. Any
result other than the one with the most recent 'last_seen' time is considered a duplicate host and is returned
within the output.
.Parameter Hosts
Array of 'Get-FalconHost -Detailed' results
.Parameter Filter
Property to determine duplicate Host(s) in addition to 'hostname'
.Role
devices:write
.Example
PS> Find-FalconDuplicate

Retrieve a list of all hosts and output potential duplicates using the 'hostname' field.
.Example
PS>$Duplicates = Find-FalconDuplicate -Filter 'mac_address'
PS>Invoke-FalconHostAction -Name hide_host -Ids $Duplicates.device_id

Find duplicate Hosts using 'hostname' and 'mac_address', then hide results within the Falcon console.
#>
    [CmdletBinding()]
    param(
        [Parameter(Position = 1)]
        [array] $Hosts,

        [Parameter(Position = 2)]
        [ValidateSet('external_ip', 'local_ip', 'mac_address', 'os_version', 'platform_name', 'serial_number')]
        [string] $Filter
    )
    begin {
        function Group-Selection ($Object, $GroupBy) {
            ($Object | Group-Object $GroupBy).Where({ $_.Count -gt 1 -and $_.Name }).foreach{
                $_.Group | Sort-Object last_seen | Select-Object -First ($_.Count - 1)
            }
        }
        # Comparison criteria and required properties for host results
        $Criteria = @('cid', 'hostname')
        $Required = @('cid', 'device_id', 'first_seen', 'last_seen', 'hostname')
        if ($PSBoundParameters.Filter) {
            $Criteria += $PSBoundParameters.Filter
            $Required += $PSBoundParameters.Filter
        }
        # Create filter for excluding results with empty $Criteria values
        $FilterScript = { (($Criteria).foreach{ "`$_.$($_)" }) -join ' -and ' }
    }
    process {
        $HostArray = if (!$PSBoundParameters.Hosts) {
            # Retreive Host details
            Get-FalconHost -Detailed -All
        } else {
            $PSBoundParameters.Hosts
        }
        ($Required).foreach{
            if (($HostArray | Get-Member -MemberType NoteProperty).Name -notcontains $_) {
                # Verify required properties are present
                throw "Missing required property '$_'."
            }
        }
        # Group, sort and output result
        $Param = @{
            Object  = $HostArray | Select-Object $Required | Where-Object -FilterScript $FilterScript
            GroupBy = $Criteria
        }
        $Output = Group-Selection @Param
    }
    end {
        if ($Output) {
            $Output
        } else {
            Write-Warning "No duplicates found."
        }
    }
}
function Get-FalconQueue {
<#
.Synopsis
Create a report of Real-time Response commands in the offline queue
.Description
Creates a CSV of pending Real-time Response commands and their related session information. Sessions within the
offline queue expire 7 days after creation by default. Sessions can have additional commands appended to them
to extend their expiration time.
.Parameter Days
Days worth of results to retrieve [default: 7]
.Example
PS>Get-FalconQueue -Days 14

Output pending Real-time Response sessions in the offline queue that were created within the last 14 days. Any
sessions that expired at the end of the default 7 day period will not be displayed.
.Role
real-time-response-admin:write
#>
    [CmdletBinding()]
    param(
        [Parameter(Position = 1)]
        [int] $Days
    )
    begin {
        $Days = if ($PSBoundParameters.Days) {
            $PSBoundParameters.Days
        } else {
            7
        }
        $OutputFile = Join-Path -Path (Get-Location).Path -ChildPath "FalconQueue_$(
            Get-Date -Format FileDateTime).csv"
        $Filter = "(deleted_at:null+commands_queued:1),(created_at:>'last $Days days'+commands_queued:1)"
    }
    process {
        try {
            Get-FalconSession -Filter $Filter -All -Verbose | ForEach-Object {
                Get-FalconSession -Ids $_ -Queue -Verbose | ForEach-Object {
                    foreach ($Session in $_) {
                        $Session.Commands | ForEach-Object {
                            $Object = [PSCustomObject] @{
                                aid                = $Session.aid
                                user_id            = $Session.user_id
                                user_uuid          = $Session.user_uuid
                                session_id         = $Session.id
                                session_created_at = $Session.created_at
                                session_deleted_at = $Session.deleted_at
                                session_updated_at = $Session.updated_at
                                session_status     = $Session.status
                                command_complete   = $false
                                command_stdout     = $null
                                command_stderr     = $null
                            }
                            $_.PSObject.Properties | ForEach-Object {
                                $Name = if ($_.Name -match '^(created_at|deleted_at|status|updated_at)$') {
                                    "command_$($_.Name)"
                                } else {
                                    $_.Name
                                }
                                $Object.PSObject.Properties.Add((New-Object PSNoteProperty($Name, $_.Value)))
                            }
                            if ($Object.command_status -eq 'FINISHED') {
                                $ConfirmCmd = Get-RtrCommand $Object.base_command -ConfirmCommand
                                $Param = @{
                                    CloudRequestId = $Object.cloud_request_id
                                    Verbose        = $true
                                    ErrorAction    = 'SilentlyContinue'
                                }
                                $CmdResult = & $ConfirmCmd @Param
                                if ($CmdResult) {
                                    ($CmdResult | Select-Object stdout, stderr, complete).PSObject.Properties |
                                    ForEach-Object {
                                        $Object."command_$($_.Name)" = $_.Value
                                    }
                                }
                            }
                            $Object | Export-Csv $OutputFile -Append -NoTypeInformation -Force
                        }
                    }
                }
            }
        } catch {
            throw $_
        } finally {
            if (Test-Path $OutputFile) {
                Get-ChildItem $OutputFile | Out-Host
            }
        }
    }
}
function Import-FalconConfig {
<#
.Synopsis
Import configurations from a 'FalconConfig' archive into your Falcon environment
.Description
Creates groups, policies, exclusions and rules within a 'FalconConfig' archive within your authenticated
Falcon environment. Anything that already exists will be ignored and no existing items will be modified.
.Parameter Path
'FalconConfig' archive path
.Example
PS>Import-FalconConfig -Path .\FalconConfig_<FileDateTime>.zip

Creates new items present in the archive, but does not assign policies or exclusions to existing groups or
modify existing items (including 'default' policies).
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidatePattern("FalconConfig_\d{8}\.zip$")]
        [ValidateScript({
            if (Test-Path $_) {
                $true
            } else {
                throw "Cannot find path '$_' because it does not exist."
            }
        })]
        [string] $Path
    )
    begin {
        # List of fields to capture/exclude/compare/export during import process
        $ConfigFields = @{
            DeviceControlPolicy = @{
                Import = @('id', 'platform_name', 'name', 'description', 'settings', 'enabled', 'groups')
            }
            FirewallGroup = @{
                Import = @('id', 'name', 'enabled', 'rule_ids', 'description')
            }
            FirewallPolicy = @{
                Import = @('id', 'name', 'platform_name', 'description', 'enabled', 'groups', 'settings')
            }
            FirewallRule = @{
                Import = @('id', 'family', 'name', 'description', 'enabled', 'platform_ids', 'direction',
                    'action', 'address_family', 'local_address', 'remote_address', 'protocol', 'local_port',
                    'remote_port', 'icmp', 'monitor', 'fields', 'rule_group')
            }
            FirewallSetting = @{
                Import = @('policy_id', 'platform_id', 'default_inbound', 'default_outbound', 'enforce',
                    'test_mode', 'rule_group_ids', 'is_default_policy')
            }
            HostGroup = @{
                Import = @('id', 'name', 'description', 'group_type', 'assignment_rule')
            }
            IoaExclusion = @{
                Import = @('id', 'cl_regex', 'ifn_regex', 'name', 'pattern_id', 'pattern_name', 'groups',
                    'comment', 'description')
            }
            IoaGroup = @{
                Import = @('id', 'platform', 'name', 'description', 'rules', 'enabled', 'version')
                Compare = @('platform', 'name')
            }
            IoaRule = @{
                Create = @('name', 'pattern_severity', 'ruletype_id', 'disposition_id', 'field_values',
                    'description', 'comment', 'enabled')
                Export = @('instance_id', 'name')
            }
            Ioc = @{
                Import = @('id', 'type', 'value')
                Create = @('type', 'value', 'action', 'platforms', 'source', 'severity', 'description', 'tags',
                    'applied_globally', 'host_groups', 'expiration')
                Compare = @('type', 'value')
                Export = @('id', 'value')
            }
            MlExclusion = @{
                Import = @('id', 'value', 'excluded_from', 'groups', 'applied_globally')
                Compare = @('value')
                Export = @('id', 'value')
            }
            PreventionPolicy = @{
                Import = @('id', 'platform_name', 'name', 'description', 'prevention_settings',
                    'enabled', 'groups')
            }
            ResponsePolicy = @{
                Import = @('id', 'platform_name', 'name', 'description', 'settings', 'enabled', 'groups')
            }
            SensorUpdatePolicy = @{
                Import = @('id', 'platform_name', 'name', 'settings', 'enabled', 'description',
                    'groups')
            }
            SvExclusion = @{
                Import = @('id', 'value', 'groups', 'applied_globally')
                Compare = @('value')
            }
        }
        function Add-Field ($Object, $Name, $Value) {
            # Add property to [PSCustomObject]
            $Object.PSObject.Properties.Add((New-Object PSNoteProperty($Name, $Value)))
        }
        function Compress-Reference ($Object) {
            # Remove unnecessary fields from sub-objects before import
            foreach ($Item in $Object) {
                if ($Item.group_type -eq 'static' -and $Item.assignment_rule) {
                    # Remove assignment_rule values from static Host Groups
                    $Item.PSObject.Properties.Remove('assignment_rule')
                }
                if ($Item.groups) {
                    # Exclude fields except id and name with group info
                    $Item.groups = $Item.groups | Select-Object id, name
                }
                if ($Item.prevention_settings.settings) {
                    # Exclude fields except id and value with prevention settings
                    $Item.prevention_settings = $Item.prevention_settings.settings | Select-Object id, value
                }
                if ($Item.settings.classes) {
                    foreach ($Class in ($Item.settings.classes | Where-Object { $_.exceptions })) {
                        # Exclude ids for individual Device Control exceptions
                        $Class.exceptions = $Class.exceptions | ForEach-Object {
                            $_.PSObject.Properties.Remove('id')
                            $_
                        }
                    }
                }
                if ($Item.rule_group) {
                    # Exclude rule_group fields except id, policy_ids and name with Firewall rules
                    $Item.rule_group = $Item.rule_group | Select-Object id, policy_ids, name
                }
                if ($Item.settings.settings) {
                    # Exclude fields except id and value with settings
                    $Item.settings = $Item.settings.settings | Select-Object id, value
                }
                if ($Item.field_values) {
                    # Exclude non-required fields from IOA Rules
                    $Item.field_values = $Item.field_values | Select-Object name, label, type, values
                }
            }
            $Object
        }
        function Get-ConfigItem ($Item, $Type, $FilterScript) {
            # Retrieve an item from 'ConfigData' using $FilterScript
            $ConfigData.$Item.$Type | Where-Object -FilterScript $FilterScript
        }
        function Get-ImportData ($Item) {
            if ($ConfigData.$Item.Cid) {
                # Compare imported items against CID
                $Param = @{
                    ReferenceObject  = $ConfigData.$Item.Import
                    DifferenceObject = $ConfigData.$Item.Cid
                    Property         = if ($ConfigFields.$Item.Compare) {
                        # Use defined fields for comparison
                        $ConfigFields.$Item.Compare
                    } elseif ($Item -match '^*.Policy$') {
                        # Use 'platform_name' and 'name' for policies
                        @('platform_name', 'name')
                    } else {
                        # Use 'name'
                        'name'
                    }
                }
                foreach ($Result in (Compare-Object @Param)) {
                    $ScriptBlock = switch ($Item) {
                        { $_ -eq 'IoaGroup' } {
                            # Output IOA groups from import using 'platform' and 'name' match
                            { $_.platform -eq $Result.platform -and $_.name -eq $Result.name }
                        }
                        { $_ -eq 'Ioc' } {
                            # Output IOCs from import using 'type' and 'value' match
                            { $_.type -eq $Result.type -and $_.value -eq $Result.value }
                        }
                        { $_ -like '*Exclusion' } {
                            # Output exclusions from import using 'value' match
                            { $_.value -eq $Result.value }
                        }
                        { $_ -like '*Policy' } {
                            # Output policies from import using 'platform_name' and 'name'
                            { $_.platform_name -eq $Result.platform_name -and $_.name -eq $Result.name }
                        }
                        default {
                            # Output using 'name'
                            { $_.name -eq $Result.name }
                        }
                    }
                    $Param = @{
                        Item         = $Item
                        Type         = 'Import'
                        FilterScript = $ScriptBlock
                    }
                    Get-ConfigItem @Param
                }
            } elseif ($ConfigData.$Item.Import) {
                # Output all items
                $ConfigData.$Item.Import
            }
        }
        function Get-Reference ($Item) {
            try {
                # Retrieve existing configurations from CID, excluding 'platform_default'
                $Param = @{
                    Detailed = $true
                    All      = $true
                }
                if ($Item -match 'Policy') {
                    $Param['Filter'] = "name:!'platform_default'"
                }
                Write-Host "Retrieving '$Item'..."
                Compress-Reference -Object (& "Get-Falcon$($Item)" @Param | Where-Object { $_.name -ne
                    'platform_default' } | Select-Object $ConfigFields.$Item.Import)
            } catch {
                throw $_
            }
        }
        function Import-ConfigData ($FilePath) {
            # Load 'FalconConfig' archive into memory, extract files and convert from Json
            $Output = @{}
            $ByteStream = if ($PSVersionTable.PSVersion.Major -ge 6) {
                Get-Content -Path $FilePath -AsByteStream
            } else {
                Get-Content -Path $FilePath -Encoding Byte -Raw
            }
            [System.Reflection.Assembly]::LoadWithPartialName('System.IO.Compression') | Out-Null
            $FileStream = New-Object System.IO.MemoryStream
            $FileStream.Write($ByteStream,0,$ByteStream.Length)
            $ConfigArchive = New-Object System.IO.Compression.ZipArchive($FileStream)
            foreach ($FullName in $ConfigArchive.Entries.FullName) {
                $Filename = $ConfigArchive.GetEntry($FullName)
                $Item = ($FullName | Split-Path -Leaf).Split('.')[0]
                $Output[$Item] = @{
                    Import = (New-Object System.IO.StreamReader($Filename.Open())).ReadToEnd() | ConvertFrom-Json
                }
            }
            if ($FileStream) {
                $FileStream.Dispose()
            }
            ($Output.GetEnumerator()).foreach{
                # Remove unnecessary fields and retrieve existing CID configuration
                $_.Value.Import = Compress-Reference -Object $_.Value.Import
                $_.Value['Cid'] = [array] (Get-Reference -Item $_.Key)
            }
            $Output
        }
        function Invoke-ConfigArray ($Item) {
            # Find non-existent items and create them in batches of 20
            $ImportData = Get-ImportData -Item $Item
            if ($ImportData) {
                $Content = if ($Item -like '*Policy') {
                    # Filter to required fields for creating policies
                    $ImportData | Select-Object platform_name, name, description
                } elseif ($Item -eq 'Ioc') {
                    foreach ($Import in $ImportData) {
                        $Fields = foreach ($Value in $ConfigFields.$Item.Create) {
                            # Filter to required fields for 'IOC'
                            if ($Import.$Value) {
                                $Value
                            }
                        }
                        $Ioc = $Import | Select-Object $Fields
                        if ($Ioc.applied_globally -eq $true) {
                            # Output 'IOC' for creation if 'applied_globally' is true
                            $Ioc
                        } elseif ($ConfigData.HostGroup.Created.id -and $Ioc.host_groups) {
                            $Groups = @( $Ioc.host_groups ) | ForEach-Object {
                                # Get group names from 'HostGroup' import
                                $OldId = $_
                                $Param = @{
                                    Item         = 'HostGroup'
                                    Type         = 'Import'
                                    FilterScript = { $_.id -eq $OldId }
                                }
                                $Name = (Get-ConfigItem @Param).name
                                # Match name with created 'HostGroup'
                                if ($Name) {
                                    $Param.Type = 'Created'
                                    $Param.FilterScript = { $_.name -eq $Name }
                                    (Get-ConfigItem @Param).id
                                }
                            }
                            if ($Groups) {
                                # Update 'host_groups' with newly created 'HostGroup' ids
                                $Ioc.host_groups = @( $Groups )
                                $Ioc
                            }
                        }
                    }
                } else {
                    # Select fields for 'HostGroup'
                    $ImportData | Select-Object name, group_type, description, assignment_rule | ForEach-Object {
                        if ($_.group_type -eq 'static') {
                            $_.PSObject.Properties.Remove('assignment_rule')
                        }
                        $_
                    }
                }
                try {
                    for ($i = 0; $i -lt ($Content | Measure-Object).Count; $i += 20) {
                        $Request = & "New-Falcon$Item" -Array @($Content[$i..($i + 19)])
                        if ($Request) {
                            if ($ConfigFields.$Item.Import) {
                                $Request | Select-Object $ConfigFields.$Item.Import
                            } else {
                                $Request
                            }
                        }
                    }
                } catch {
                    throw $_
                }
            }
        }
        function Invoke-ConfigItem ($Command, $Content) {
            $Type = $Command -replace '\w+\-Falcon', $null -replace 'Setting', 'Policy'
            try {
                # Create/modify/enable item and notify host
                $Request = & $Command @Content
                if ($Request) {
                    if ($ConfigFields.$Type.Import -and $Type -ne 'FirewallGroup') {
                        # Output 'import' fields, unless creating a firewall rule group
                        $Request | Select-Object $ConfigFields.$Type.Import
                    } else {
                        $Request
                    }
                }
            } catch {
                throw $_
            }
        }
        # Convert 'Path' to absolute and set 'OutputFile'
        $ArchivePath = $Script:Falcon.Api.Path($PSBoundParameters.Path)
        $Param = @{
            Path      = (Get-Location).Path
            ChildPath = "FalconConfig_$(Get-Date -Format FileDate).csv"
        }
        $OutputFile = Join-Path @Param
    }
    process {
        #  Create 'ConfigData' and import configuration files
        $ConfigData = Import-ConfigData -FilePath $ArchivePath
        if ($ConfigData.SensorUpdatePolicy.Import) {
            $Builds = try {
                Write-Host "Retrieving available sensor builds..."
                Get-FalconBuild
            } catch {
                throw "Failed to retrieve available builds for 'SensorUpdate' policy creation."
            }
            foreach ($Policy in $ConfigData.SensorUpdatePolicy.Import) {
                # Update tagged builds with current tagged build versions
                if ($Policy.settings.build -match '^\d+\|') {
                    $Tag = ($Policy.settings.build -split '\|', 2)[-1]
                    $CurrentBuild = ($Builds | Where-Object { ($_.build -like "*|$Tag") -and
                        ($_.platform -eq $Policy.platform_name) }).build
                    if ($Policy.settings.build -ne $CurrentBuild) {
                        $Policy.settings.build = $CurrentBuild
                    }
                }
            }
        }
        try {
            if ($ConfigData.HostGroup.Import) {
                # Create Host Groups
                $Created = Invoke-ConfigArray -Item 'HostGroup'
                if ($Created) {
                    $ConfigData.HostGroup['Created'] = $Created
                    foreach ($Item in $Created) {
                        Write-Host "Created HostGroup '$($Item.name)'."
                    }
                }
            }
            foreach ($Pair in $ConfigData.GetEnumerator().Where({ $_.Key -eq 'Ioc' })) {
                # Create IOCs if corresponding Host Groups were created, or assigned to 'all'
                $ConfigData.($Pair.Key)['Created'] = Invoke-ConfigArray -Item $Pair.Key
                if ($ConfigData.($Pair.Key).Created) {
                    foreach ($Item in $ConfigData.($Pair.Key).Created) {
                        Write-Host "Created $($Pair.Key) '$($Item.type):$($Item.value)'."
                    }
                }
            }
            foreach ($Pair in $ConfigData.GetEnumerator().Where({ $_.Key -match '^(ML|SV)Exclusion$' })) {
                # Create exclusions if corresponding Host Groups were created, or assigned to 'all'
                $ImportData = Get-ImportData -Item $Pair.Key
                if ($ImportData) {
                    $ConfigData.($Pair.Key)['Created'] = foreach ($Import in $ImportData) {
                        $Content = @{
                            Value = $Import.value
                        }
                        if ($Import.excluded_from) {
                            $Content['ExcludedFrom'] = $Import.excluded_from
                        }
                        $Content['GroupIds'] = if ($Import.applied_globally -eq $true) {
                            'all'
                        } elseif ($ConfigData.HostGroup.Created.id) {
                            foreach ($Name in $Import.groups.name) {
                                # Get created Host Group identifiers
                                $Param = @{
                                    Item         = 'HostGroup'
                                    Type         = 'Created'
                                    FilterScript = { $_.name -eq $Name }
                                }
                                (Get-ConfigItem @Param).id
                            }
                        }
                        if ($Content.GroupIds) {
                            $Param = @{
                                Command = "New-Falcon$($Pair.Key)"
                                Content = $Content
                            }
                            $Created = Invoke-ConfigItem @Param
                            if ($Created) {
                                Write-Host "Created $($Pair.Key) '$($Created.value)'."
                            }
                            $Created
                        }
                    }
                }
            }
            foreach ($Pair in $ConfigData.GetEnumerator().Where({ $_.Key -match '^.*Policy$' })) {
                # Create Policies
                $Created = Invoke-ConfigArray -Item $Pair.Key
                if ($Created) {
                    foreach ($Item in $Created) {
                        Write-Host "Created $($Item.platform_name) $($Pair.Key) '$($Item.name)'."
                    }
                    $ConfigData.($Pair.Key)['Created'] = foreach ($Policy in $Created) {
                        $Param = @{
                            Item = $Pair.Key
                            Type = 'Import'
                            FilterScript = { $_.platform_name -eq $Policy.platform_name -and $_.name -eq
                                $Policy.name }
                        }
                        $Import = Get-ConfigItem @Param
                        if ($Import.settings -or $Import.prevention_settings) {
                            if ($Pair.Key -eq 'FirewallPolicy') {
                                # Update Firewall policies with settings
                                $Content = @{
                                    PolicyId        = $Policy.id
                                    PlatformId      = $Import.settings.platform_id
                                    Enforce         = $Import.settings.enforce
                                    DefaultInbound  = $Import.settings.default_inbound
                                    DefaultOutbound = $Import.settings.default_outbound
                                    MonitorMode     = $Import.settings.test_mode
                                }
                                $RuleGroupIds = if ($Import.settings.rule_group_ids) {
                                    # Using 'rule_group_id', match 'name' of imported group to created group
                                    $Param = @{
                                        Item         = 'FirewallGroup'
                                        Type         = 'Import'
                                        FilterScript = { $Import.settings.rule_group_ids -contains $_.id }
                                    }
                                    $GroupNames = (Get-ConfigItem @Param).name
                                    foreach ($Name in $GroupNames) {
                                        $Param = @{
                                            Item         = 'FirewallGroup'
                                            Type         = 'Created'
                                            FilterScript = { $_.Name -eq $Name }
                                        }
                                        # Match 'name' to find created rule group id
                                        (Get-ConfigItem @Param).id
                                    }
                                }
                                if ($RuleGroupIds) {
                                    # Add created Rule Groups
                                    $Content['RuleGroupIds'] = $RuleGroupIds
                                }
                                $Param = @{
                                    Command = 'Edit-FalconFirewallSetting'
                                    Content = $Content
                                }
                                $Request = Invoke-ConfigItem @Param
                                if ($Request.resources_affected -eq 1) {
                                    # Append 'settings' to policy
                                    Add-Field -Object $Policy -Name 'settings' -Value $Import.settings
                                }
                            } else {
                                # Update other policies with settings
                                $Param = @{
                                    Command = "Edit-Falcon$($Pair.Key)"
                                    Content = @{
                                        Id       = $Policy.id
                                        Settings = if ($Import.prevention_settings) {
                                            $Import.prevention_settings
                                        } else {
                                            $Import.settings
                                        }
                                    }
                                }
                                $Request = Invoke-ConfigItem @Param
                                @('settings', 'prevention_settings').foreach{
                                    if ($Request.$_) {
                                        # Update 'settings' on policy
                                        $Policy.$_ = $Request.$_
                                    }
                                }
                            }
                            if ($Request) {
                                Write-Host "Applied settings to $($Pair.Key) '$($Policy.name)'."
                            }
                        }
                        foreach ($Group in $Import.groups) {
                            $Param = @{
                                Item         = 'HostGroup'
                                Type         = 'Created'
                                FilterScript = { $_.name -eq $Group.name }
                            }
                            $GroupId = (Get-ConfigItem @Param).id
                            if ($GroupId) {
                                # Assign group to policy
                                $Param = @{
                                    Command = "Invoke-Falcon$($Pair.Key)Action"
                                    Content = @{
                                        Name    = 'add-host-group'
                                        Id      = $Policy.id
                                        GroupId = $GroupId
                                    }
                                }
                                $Request = Invoke-ConfigItem @Param
                                if ($Request.groups) {
                                    # Update 'group' on policy
                                    $Policy.groups = $Request.groups
                                    Write-Host ("Assigned HostGroup '$($Group.name)' to $($Pair.Key) " +
                                        "'$($Policy.name)'.")
                                }
                            }
                        }
                        <# Future code for assigning custom IOA Rule Groups to Prevention policies
                        foreach ($Group in $Import.unknown_property) {
                            # Assign IOA Rule Groups to Prevention policies
                            $Param = @{
                                Item = 'IoaGroup'
                                Type = 'Created'
                                FilterScript = { $_.name -eq $Group.name }
                            }
                            $GroupId = (Get-ConfigItem @Param).id
                            if ($GroupId) {
                                # Assign group to policy
                                $Param = @{
                                    Command = "Invoke-Falcon$($Pair.Key)Action"
                                    Content = @{
                                        Name = "add-rule-group"
                                        Id = $Policy.id
                                        GroupId = $GroupId
                                    }
                                }
                                $Request = Invoke-ConfigItem @Param
                                if ($Request.unknown_property) {
                                    # Update 'group' on policy
                                    $Policy.unknown_property = $Request.unknown_property
                                }
                            }
                        } #>
                        if ($Import.enabled -eq $true -and $Policy.enabled -eq $false) {
                            $Param = @{
                                Command = "Invoke-Falcon$($Pair.Key)Action"
                                Content = @{
                                    Id = $Policy.id
                                    Name = 'enable'
                                }
                            }
                            $Request = Invoke-ConfigItem @Param
                            if ($Request) {
                                # Update 'enabled' status on policy
                                $Policy.enabled = $Request.enabled
                                Write-Host "Enabled $($Pair.Key) '$($Policy.Name)'."
                            }
                        }
                        # Output updated policy
                        $Policy
                    }
                }
            }
            foreach ($Pair in $ConfigData.GetEnumerator().Where({ $_.Key -match '^.*Policy$'})) {
                if ($Pair.Value.Created -and $Pair.Value.Cid) {
                    Write-Warning "There were existing $($Pair.Key) items. Verify policy precedence!"
                }
            }
            if ($ConfigData.FirewallGroup.Import) {
                # Create Firewall Rule Groups
                $ImportData = Get-ImportData -Item 'FirewallGroup'
                if ($ImportData) {
                    $ConfigData.FirewallGroup['Created'] = foreach ($Import in $ImportData) {
                        # Set required fields
                        $Content = @{
                            Name    = $Import.name
                            Enabled = $Import.enabled
                        }
                        switch ($Import) {
                            # Add optional fields
                            { $_.description } { $Content['Description'] = $_.description }
                            { $_.comment }     { $Content['Comment'] = $_.comment }
                        }
                        if ($Import.rule_ids) {
                            # Select required fields for each individual rule
                            $CreateFields = $ConfigFields.FirewallRule.Import | Where-Object { $_ -ne 'id' -and
                                $_ -ne 'family' }
                            $Rules = $ConfigData.FirewallRule.Import | Where-Object {
                                $Import.rule_ids -contains $_.family } | Select-Object $CreateFields
                            $Rules | ForEach-Object {
                                if ($_.name.length -gt 64) {
                                    # Trim rule names to 64 characters
                                    $_.name = ($_.name).SubString(0,63)
                                }
                            }
                            $Content['Rules'] = $Rules
                        }
                        $Param = @{
                            Command = 'New-FalconFirewallGroup'
                            Content = $Content
                        }
                        $NewGroup = Invoke-ConfigItem @Param
                        if ($NewGroup) {
                            # Output object with 'id' and 'name'
                            [PSCustomObject] @{
                                id   = $NewGroup
                                name = $Import.name
                            }
                            $Message = "Created FirewallGroup '$($Import.name)'"
                            if ($Rules) {
                                $Message += " with $(($Rules | Measure-Object).Count) rules"
                            }
                            Write-Host "$Message."
                        }
                    }
                }
            }
            if ($ConfigData.IoaGroup.Import) {
                # Create IOA Rule groups
                $ImportData = Get-ImportData -Item 'IoaGroup'
                if ($ImportData) {
                    $ConfigData.IoaGroup['Created'] = foreach ($Import in $ImportData) {
                        # Set required fields
                        $Content = @{
                            Platform = $Import.platform
                            Name     = $Import.name
                        }
                        switch ($Import) {
                            # Add optional fields
                            { $_.description } { $Content['Description'] = $_.description }
                            { $_.comment }     { $Content['Comment'] = $_.comment }
                        }
                        $Param = @{
                            Command = 'New-FalconIoaGroup'
                            Content = $Content
                        }
                        $NewGroup = Invoke-ConfigItem @Param
                        if ($NewGroup) {
                            Write-Host "Created $($NewGroup.platform) IoaGroup '$($NewGroup.name)'."
                            # Get date for adding 'comment' fields
                            $FileDate = Get-Date -Format FileDate
                            if ($Import.rules) {
                                $NewRules = Compress-Reference -Object $Import.rules |
                                    Select-Object $ConfigFields.IoaRule.Create
                                if ($NewRules) {
                                    $NewGroup.rules = foreach ($Rule in $NewRules) {
                                        # Create IOA Rule within IOA Group
                                        $Content = @{
                                            RulegroupId     = $NewGroup.id
                                            Name            = $Rule.name
                                            PatternSeverity = $Rule.pattern_severity
                                            RuletypeId      = $Rule.ruletype_id
                                            DispositionId   = $Rule.disposition_id
                                            FieldValues     = $Rule.field_values
                                        }
                                        @('description', 'comment').foreach{
                                            if ($Rule.$_) {
                                                $Content[$_] = $Rule.$_
                                            }
                                        }
                                        $Param = @{
                                            Command = 'New-FalconIoaRule'
                                            Content = $Content
                                        }
                                        $Created = Invoke-ConfigItem @Param
                                        if ($Created) {
                                            Write-Host "Created IoaRule '$($Created.name)'."
                                        }
                                        if ($Created.enabled -eq $false -and $Rule.enabled -eq $true) {
                                            # Enable IOA Rule
                                            $Created.enabled = $true
                                            #$ApiVersion = [string] (Get-FalconIoaGroup -Ids ($NewGroup.id)).version
                                            $Version = [string] (Get-FalconIoaGroup -Ids ($NewGroup.id)).version
                                            #$GroupVersion = if ($ApiVersion) {
                                            #    $ApiVersion
                                            #} else {
                                            #    1
                                            #}
                                            #if ($GroupVersion) {
                                            if ($Version) {
                                                $Param = @{
                                                    Command = 'Edit-FalconIoaRule'
                                                    Content = @{
                                                        RulegroupId      = $NewGroup.id
                                                        RuleUpdates      = $Created
                                                        RulegroupVersion = $Version #$GroupVersion
                                                        Comment          = if ($Rule.comment) {
                                                            $Rule.comment
                                                        } else {
                                                            "Enabled $FileDate"
                                                        }
                                                    }
                                                }
                                                $Enabled = Invoke-ConfigItem @Param
                                                if ($Enabled) {
                                                    # Output enable rule request result
                                                    $Enabled
                                                    Write-Host "Enabled IoaRule '$($Created.name)'."
                                                }
                                            }
                                        } else {
                                            # Output create rule request result
                                            $Created
                                        }
                                    }
                                }
                            }
                            if ($Import.enabled -eq $true) {
                                # Enable IOA Group
                                #$ApiVersion = [string] (Get-FalconIoaGroup -Ids ($NewGroup.id)).version
                                $Version = [string] (Get-FalconIoaGroup -Ids ($NewGroup.id)).version
                                #$GroupVersion = if ($ApiVersion) {
                                #    $ApiVersion
                                #} else {
                                #    1
                                #}
                                #if ($GroupVersion) {
                                if ($Version) {
                                    $Param = @{
                                        Command = 'Edit-FalconIoaGroup'
                                        Content = @{
                                            Id               = $NewGroup.id
                                            Name             = $NewGroup.name
                                            Enabled          = $true
                                            RulegroupVersion = $Version #$GroupVersion
                                            Description      = if ($NewGroup.description) {
                                                $NewGroup.description
                                            } else {
                                                "Imported $FileDate"
                                            }
                                            Comment = if ($NewGroup.comment) {
                                                $NewGroup.comment
                                            } else {
                                                "Enabled $FileDate"
                                            }
                                        }
                                    }
                                    $Enabled = Invoke-ConfigItem @Param
                                    if ($Enabled) {
                                        # Output group enabled result
                                        $Enabled
                                        Write-Host "Enabled IoaGroup '$($Enabled.name)'."
                                        Write-Warning ("IoaGroup '$($Enabled.name)' was not assigned to a " +
                                            "Prevention policy.")
                                    }
                                }
                            } else {
                                # Output group creation result
                                $NewGroup
                            }
                        }
                    }
                }
            }
        } catch {
            throw $_
        }
    }
    end {
        if ($ConfigData.Values.Created) {
            foreach ($Pair in $ConfigData.GetEnumerator().Where({ $_.Value.Created })) {
                $Pair.Value.Created | ForEach-Object {
                    # Output 'created' results to CSV
                    [PSCustomObject] @{
                        type = $Pair.Key
                        id = if ($_.instance_id) {
                            $_.instance_id
                        } else {
                            $_.id
                        }
                        name = if ($_.value) {
                            $_.value
                        } else {
                            $_.name
                        }
                        platform_name = if ($_.platform_name) {
                            $_.platform_name
                        } elseif ($_.platform) {
                            $_.platform
                        } else {
                            $null
                        }
                    } | Export-Csv -Path $OutputFile -NoTypeInformation -Append
                }
            }
            if (Test-Path $OutputFile) {
                Get-ChildItem -Path $OutputFile
            }
        } else {
            Write-Warning 'No items created.'
        }
    }
}
function Invoke-FalconDeploy {
<#
.Synopsis
Deploy and run an executable using Real-time Response
.Description
'Put' files will be checked for identical file names, and if any are found, the Sha256 hash values will be
compared between your local and cloud files. If they are different, a prompt will appear asking which file to use.

If the file is not present in 'Put' files, it will be uploaded.

Once uploaded, a Real-time Response session will be started for the designated Host(s), the file will be 'put'
into the root drive, and 'run' if successfully transferred.

Details of each step will be output to a CSV file in the current directory.
.Parameter Path
Path to local file
.Parameter Arguments
Arguments to include when running the executable
.Parameter Timeout
Length of time to wait for a result, in seconds
.Parameter QueueOffline
Add non-responsive Hosts to the offline queue
.Parameter HostIds
Host identifier(s)
.Parameter GroupId
Host Group identifier
.Role
real-time-response-admin:write
.Example
PS>Invoke-FalconDeploy -Path C:\files\example.exe -HostIds <id>, <id>

The file 'example.exe' will be 'put' and 'run' on <id> and <id>.
#>
    [CmdletBinding()]
    [CmdletBinding(DefaultParameterSetName = 'HostIds')]
    param(
        [Parameter(ParameterSetName = 'HostIds', Mandatory = $true, Position = 1)]
        [Parameter(ParameterSetName = 'GroupId', Mandatory = $true, Position = 1)]
        [ValidateScript({
            if (Test-Path $_) {
                $true
            } else {
                throw "Cannot find path '$_' because it does not exist."
            }
        })]
        [string] $Path,

        [Parameter(ParameterSetName = 'HostIds', Position = 2)]
        [Parameter(ParameterSetName = 'GroupId', Position = 2)]
        [string] $Arguments,

        [Parameter(ParameterSetName = 'HostIds', Position = 3)]
        [Parameter(ParameterSetName = 'GroupId', Position = 3)]
        [ValidateRange(30,600)]
        [int] $Timeout,

        [Parameter(ParameterSetName = 'HostIds')]
        [Parameter(ParameterSetName = 'GroupId')]
        [boolean] $QueueOffline,

        [Parameter(ParameterSetName = 'HostIds', Mandatory = $true)]
        [ValidatePattern('^\w{32}$')]
        [array] $HostIds,

        [Parameter(ParameterSetName = 'GroupId', Mandatory = $true)]
        [ValidatePattern('^\w{32}$')]
        [string] $GroupId
    )
    begin {
        # Fields to collect from 'Put' files list
        $PutFields = @('id', 'name', 'created_timestamp', 'modified_timestamp', 'sha256')
        function Write-RtrResult ($Object, $Step, $BatchId) {
            # Create output, append results and output to CSV
            $Output = foreach ($Item in $Object) {
                [PSCustomObject] @{
                    aid              = $Item.aid
                    batch_id         = $BatchId
                    session_id       = $null
                    cloud_request_id = $null
                    deployment_step  = $Step
                    complete         = $false
                    offline_queued   = $false
                    errors           = $null
                    stderr           = $null
                    stdout           = $null
                }
            }
            Get-RtrResult -Object $Object -Output $Output | Export-Csv $OutputFile -Append -NoTypeInformation
        }
        # Set output file and executable details
        $OutputFile = Join-Path -Path (Get-Location).Path -ChildPath "FalconDeploy_$(
            Get-Date -Format FileDateTime).csv"
        $FilePath = $Script:Falcon.Api.Path($PSBoundParameters.Path)
        $Filename = "$([System.IO.Path]::GetFileName($FilePath))"
        $ProcessName = "$([System.IO.Path]::GetFileNameWithoutExtension($FilePath))"
        [array] $HostArray = if ($PSBoundParameters.GroupId) {
            try {
                # Find Host Group member identifiers
                Get-FalconHostGroupMember -Id $PSBoundParameters.GroupId
            } catch {
                throw $_
            }
        } else {
            # Use provided Host identifiers
            $PSBoundParameters.HostIds
        }
        if ($HostArray) {
            try {
                Write-Host "Checking cloud for existing file..."
                $CloudFile = Get-FalconPutFile -Filter "name:['$Filename']" -Detailed | Select-Object $PutFields |
                ForEach-Object {
                    [PSCustomObject] @{
                        id                 = $_.id
                        name               = $_.name
                        created_timestamp  = [datetime] $_.created_timestamp
                        modified_timestamp = [datetime] $_.modified_timestamp
                        sha256             = $_.sha256
                    }
                }
                $LocalFile = Get-ChildItem $FilePath | Select-Object CreationTime, Name, LastWriteTime |
                ForEach-Object {
                    [PSCustomObject] @{
                        name               = $_.Name
                        created_timestamp  = $_.CreationTime
                        modified_timestamp = $_.LastWriteTime
                        sha256             = ((Get-FileHash -Algorithm SHA256 -Path $FilePath).Hash).ToLower()
                    }
                }
                if ($LocalFile -and $CloudFile) {
                    if ($LocalFile.sha256 -eq $CloudFile.sha256) {
                        Write-Host "Matched hash values between local and cloud files..."
                    } else {
                        Write-Host "[CloudFile]"
                        $CloudFile | Select-Object name, created_timestamp, modified_timestamp, sha256 |
                            Format-List | Out-Host
                        Write-Host "[LocalFile]"
                        $LocalFile | Select-Object name, created_timestamp, modified_timestamp, sha256 |
                            Format-List | Out-Host
                        $FileChoice = $host.UI.PromptForChoice(
                            "'$Filename' exists in your 'Put' Files. Use existing version?", $null,
                            [System.Management.Automation.Host.ChoiceDescription[]] @("&Yes", "&No"), 0)
                        if ($FileChoice -eq 0) {
                            Write-Host "Proceeding with CloudFile: $($CloudFile.id)..."
                        } else {
                            $RemovePut = Remove-FalconPutFile -Id $CloudFile.id
                            if ($RemovePut.writes.resources_affected -eq 1) {
                                Write-Host "Removed CloudFile: $($CloudFile.id)"
                            }
                        }
                    }
                }
            } catch {
                throw $_
            }
        }
    }
    process {
        if ($HostArray) {
            $AddPut = if ($RemovePut.writes.resources_affected -eq 1 -or !$CloudFile) {
                Write-Host "Uploading $Filename..."
                $Param = @{
                    Path        = $FilePath
                    Name        = $Filename
                    Description = "$ProcessName"
                    Comment     = 'PSFalcon: Invoke-FalconDeploy'
                }
                Send-FalconPutFile @Param
            }
            if ($AddPut.writes.resources_affected -ne 1 -and !$CloudFile.id) {
                throw "Upload failed."
            }
            try {
                for ($i = 0; $i -lt ($HostArray | Measure-Object).Count; $i += 500) {
                    $Param = @{
                        HostIds = $HostArray[$i..($i + 499)]
                    }
                    switch -Regex ($PSBoundParameters.Keys) {
                        '(QueueOffline|Timeout)' { $Param[$_] = $PSBoundParameters.$_ }
                    }
                    $Session = Start-FalconSession @Param
                    $SessionHosts = if ($Session) {
                        # Output result to CSV and return list of successful 'session_start' hosts
                        Write-RtrResult -Object $Session.hosts -Step 'session_start' -BatchId $Session.batch_id
                        ($Session.hosts | Where-Object { $_.complete -eq $true -or
                            $_.offline_queued -eq $true }).aid
                    }
                    $PutHosts = if ($SessionHosts) {
                        # Invoke 'put' on successful hosts
                        Write-Host "Sending $Filename to $(($SessionHosts | Measure-Object).Count) host(s)..."
                        $Param = @{
                            BatchId         = $Session.batch_id
                            Command         = 'put'
                            Arguments       = "$Filename"
                            OptionalHostIds = $SessionHosts
                        }
                        if ($PSBoundParameters.Timeout) {
                            $Param['Timeout'] = $PSBoundParameters.Timeout
                        }
                        $CmdPut = Invoke-FalconAdminCommand @Param
                        if ($CmdPut) {
                            # Output result to CSV and return list of successful 'put_file' hosts
                            Write-RtrResult -Object $CmdPut -Step 'put_file' -BatchId $Session.batch_id
                            ($CmdPut | Where-Object { $_.stdout -eq 'Operation completed successfully.' -or
                                $_.offline_queued -eq $true }).aid
                        }
                    }
                    if ($PutHosts) {
                        # Invoke 'run'
                        Write-Host "Starting $Filename on $(($PutHosts | Measure-Object).Count) host(s)..."
                        $Arguments = "\$Filename"
                        if ($PSBoundParameters.Arguments) {
                            $Arguments += " -CommandLine=`"$($PSBoundParameters.Arguments)`""
                        }
                        $Param = @{
                            BatchId         = $Session.batch_id
                            Command         = 'run'
                            Arguments       = $Arguments
                            OptionalHostIds = $PutHosts
                        }
                        if ($PSBoundParameters.Timeout) {
                            $Param['Timeout'] = $PSBoundParameters.Timeout
                        }
                        $CmdRun = Invoke-FalconAdminCommand @Param
                        if ($CmdRun) {
                            # Output result to CSV
                            Write-RtrResult -Object $CmdRun -Step 'run_file' -BatchId $Session.batch_id
                        }
                    }
                }
            } catch {
                throw $_
            } finally {
                if (Test-Path $OutputFile) {
                    Get-ChildItem $OutputFile | Out-Host
                }
            }
        }
    }
}
function Invoke-FalconRTR {
<#
.Synopsis
Start Real-time Response session(s), execute a command and output the result(s)
.Parameter Command
Real-time Response command
.Parameter Arguments
Arguments to include with the command
.Parameter Timeout
Length of time to wait for a result, in seconds
.Parameter QueueOffline
Add non-responsive Hosts to the offline queue
.Parameter HostIds
Host identifier(s)
.Parameter GroupId
Host Group identifier
.Role
real-time-response-admin:write
.Example
PS>Invoke-FalconRTR runscript "-CloudFile='HelloWorld'" -HostIds <id>, <id>

The command 'runscript' will be used to execute the previously-created Response Script called 'HelloWorld'
on <id> and <id>.
#>
    [CmdletBinding(DefaultParameterSetName = 'HostIds')]
    param(
        [Parameter(ParameterSetName = 'HostIds', Mandatory = $true, Position = 1)]
        [Parameter(ParameterSetName = 'GroupId', Mandatory = $true, Position = 1)]
        [ValidateSet('cat', 'cd', 'clear', 'cp', 'csrutil', 'encrypt', 'env', 'eventlog', 'filehash', 'get',
            'getsid', 'history', 'ifconfig', 'ipconfig', 'kill', 'ls', 'map', 'memdump', 'mkdir', 'mount', 'mv',
            'netstat', 'ps', 'put', 'reg delete', 'reg load', 'reg query', 'reg set', 'reg unload', 'restart',
            'rm', 'run', 'runscript', 'shutdown', 'umount', 'unmap', 'update history', 'update install',
            'update list', 'users', 'xmemdump', 'zip')]
        [string] $Command,

        [Parameter(ParameterSetName = 'HostIds', Position = 2)]
        [Parameter(ParameterSetName = 'GroupId', Position = 2)]
        [string] $Arguments,

        [Parameter(ParameterSetName = 'HostIds', Position = 3)]
        [Parameter(ParameterSetName = 'GroupId', Position = 3)]
        [ValidateRange(30,600)]
        [int] $Timeout,

        [Parameter(ParameterSetName = 'HostIds')]
        [Parameter(ParameterSetName = 'GroupId')]
        [boolean] $QueueOffline,

        [Parameter(ParameterSetName = 'HostIds', Mandatory = $true)]
        [ValidatePattern('^\w{32}$')]
        [array] $HostIds,

        [Parameter(ParameterSetName = 'GroupId', Mandatory = $true)]
        [ValidatePattern('^\w{32}$')]
        [string] $GroupId
    )
    begin {
        function Initialize-Output ([array] $HostIds) {
            # Create initial array of output for each host
            ($HostIds).foreach{
                $Item = [PSCustomObject] @{
                    aid              = $_
                    batch_id         = $null
                    session_id       = $null
                    cloud_request_id = $null
                    complete         = $false
                    offline_queued   = $false
                    errors           = $null
                    stderr           = $null
                    stdout           = $null
                }
                if ($InvokeCmd -eq 'Invoke-FalconBatchGet') {
                    $Item.PSObject.Properties.Add((New-Object PSNoteProperty('batch_get_cmd_req_id', $null)))
                }
                if ($PSBoundParameters.GroupId) {
                    $Item.PSObject.Properties.Add((New-Object PSNoteProperty('batch_get_cmd_req_id', $null)))
                }
                $Item
            }
        }
        if ($PSBoundParameters.Timeout -and $PSBoundParameters.Command -eq 'runscript' -and
        $PSBoundParameters.Arguments -notmatch '-Timeout=\d{2,3}') {
            # Force 'Timeout' into 'Arguments' when using 'runscript'
            $PSBoundParameters.Arguments += " -Timeout=$($PSBoundParameters.Timeout)"
        }
        # Determine Real-time Response command to invoke
        $InvokeCmd = if ($PSBoundParameters.Command -eq 'get') {
            'Invoke-FalconBatchGet'
        } else {
            Get-RtrCommand $PSBoundParameters.Command
        }
    }
    process {
        $HostArray = if ($PSBoundParameters.GroupId) {
            try {
                # Find Host Group member identifiers
                Get-FalconHostGroupMember -Id $PSBoundParameters.GroupId
            } catch {
                throw $_
            }
        } else {
            # Use provided Host identifiers
            $PSBoundParameters.HostIds
        }
        try {
            for ($i = 0; $i -lt ($HostArray | Measure-Object).Count; $i += 500) {
                # Create baseline output and define request parameters
                [array] $Group = Initialize-Output $HostArray[$i..($i + 499)]
                $InitParam = @{
                    HostIds = $Group.aid
                }
                if ($PSBoundParameters.QueueOffline) {
                    $InitParam['QueueOffline'] = $PSBoundParameters.QueueOffline
                }
                # Define command request parameters
                if ($InvokeCmd -eq 'Invoke-FalconBatchGet') {
                    $CmdParam = @{
                        FilePath = $PSBoundParameters.Arguments
                    }
                } else {
                    $CmdParam = @{
                        Command = $PSBoundParameters.Command
                    }
                    if ($PSBoundParameters.Arguments) {
                        $CmdParam['Arguments'] = $PSBoundParameters.Arguments
                    }
                }
                if ($PSBoundParameters.Timeout) {
                    @($InitParam, $CmdParam).foreach{
                        $_['Timeout'] = $PSBoundParameters.Timeout
                    }
                }
                # Request session and capture initialization result
                $InitRequest = Start-FalconSession @InitParam
                $InitResult = Get-RtrResult -Object $InitRequest.hosts -Output $Group
                if ($InitRequest.batch_id) {
                    $InitResult | Where-Object { $_.session_id } | ForEach-Object {
                        # Add batch_id to initialized sessions
                        $_.batch_id = $InitRequest.batch_id
                    }
                    # Perform command request and capture result
                    $CmdRequest = & $InvokeCmd @CmdParam -BatchId $InitRequest.batch_id
                    $CmdResult = Get-RtrResult -Object $CmdRequest -Output $InitResult
                    if ($InvokeCmd -eq 'Invoke-FalconBatchGet' -and $CmdRequest.batch_get_cmd_req_id) {
                        $CmdResult | Where-Object { $_.session_id -and $_.complete -eq $true } | ForEach-Object {
                            # Add 'batch_get_cmd_req_id' and remove 'stdout' from session
                            $_.PSObject.Properties.Add((New-Object PSNoteProperty('batch_get_cmd_req_id',
                                $CmdRequest.batch_get_cmd_req_id)))
                            $_.stdout = $null
                        }
                    }
                    $CmdResult
                } else {
                    $InitResult
                }
            }
        } catch {
            throw $_
        }
    }
}
function Show-FalconMap {
<#
.Synopsis
Use your default browser to display indicators on the Falcon X Indicator Map. Invalid indicator values are ignored.
.Parameter Indicators
Real-time Response command
.Example
PS>Show-FalconMap -Indicators 93.184.216.34, example.com, <sha256_hash>

The default browser will open and the indicator map will be displayed for "ip:93.184.216.34", "domain:example.com",
and "hash:<sha256_hash>".
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 1)]
        [array] $Indicators
    )
    begin {
        $FalconUI = "$($Script:Falcon.Hostname -replace 'api', 'falcon')"
        $Inputs = ($PSBoundParameters.Indicators).foreach{
            $Type = Confirm-String $_
            $Value = if ($Type -match '^(domain|md5|sha256)$') {
                $_.ToLower()
            } else {
                $_
            }
            if ($Type) {
                "$($Type):'$Value'"
            }
        }
    }
    process {
        Start-Process "$($FalconUI)/intelligence/graph?indicators=$($Inputs -join ',')"
    }
}
function Show-FalconModule {
<#
.Synopsis
Display information about your PSFalcon installation.
.Description
Outputs an object containing module, user and system version information that is helpful for diagnosing problems
with the PSFalcon module.
#>
    [CmdletBinding()]
    param()
    begin {
        $Parent = Split-Path -Path $Script:Falcon.Api.Path($PSScriptRoot) -Parent
    }
    process {
        if (Test-Path "$Parent\PSFalcon.psd1") {
            $Module = Import-PowerShellDataFile $Parent\PSFalcon.psd1
            [PSCustomObject] @{
                ModuleVersion    = "v$($Module.ModuleVersion) {$($Module.GUID)}"
                ModulePath       = $Parent
                UserHome         = $HOME
                UserPSModulePath = ($env:PSModulePath -split ';') -join ', '
                UserSystem       = ("PowerShell $($PSVersionTable.PSEdition): v$($PSVersionTable.PSVersion)" +
                    " [$($PSVersionTable.OS)]")
                UserAgent        = $Script:Falcon.Api.Client.DefaultRequestHeaders.UserAgent.ToString()
            }
        } else {
            throw "Cannot find 'PSFalcon.psd1'"
        }
    }
}