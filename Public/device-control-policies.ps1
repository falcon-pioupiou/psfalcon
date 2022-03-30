function Edit-FalconDeviceControlPolicy {
<#
.SYNOPSIS
Modify Falcon Device Control policies
.DESCRIPTION
Requires 'Device Control Policies: Write'.
.PARAMETER Array
An array of policies to modify in a single request
.PARAMETER Name
Policy name
.PARAMETER Description
Policy description
.PARAMETER Settings
Hashtable of policy settings
.PARAMETER Id
Policy identifier
.LINK

#>
    [CmdletBinding(DefaultParameterSetName='/policy/entities/device-control/v1:patch')]
    param(
        [Parameter(ParameterSetName='array',Mandatory)]
        [ValidateScript({
            foreach ($Object in $_) {
                $Param = @{
                    Object = $Object
                    Command = 'Edit-FalconDeviceControlPolicy'
                    Endpoint = '/policy/entities/device-control/v1:patch'
                    Required = @('id')
                    Pattern = @('id')
                }
                Confirm-Parameter @Param
            }
        })]
        [Alias('resources')]
        [array]$Array,

        [Parameter(ParameterSetName='/policy/entities/device-control/v1:patch',Position=1)]
        [string]$Name,

        [Parameter(ParameterSetName='/policy/entities/device-control/v1:patch',Position=2)]
        [System.Collections.Hashtable]$Settings,

        [Parameter(ParameterSetName='/policy/entities/device-control/v1:patch',Position=3)]
        [string]$Description,

        [Parameter(ParameterSetName='/policy/entities/device-control/v1:patch',Mandatory,ValueFromPipeline,
            ValueFromPipelineByPropertyName,Position=4)]
        [ValidatePattern('^\w{32}$')]
        [string]$Id
    )
    begin {
        $Param = @{
            Command = $MyInvocation.MyCommand.Name
            Endpoint = '/policy/entities/device-control/v1:patch'
            Format = @{
                Body = @{
                    resources = @('name','id','description','settings')
                    root = @('resources')
                }
            }
        }
    }
    process { Invoke-Falcon @Param -Inputs $PSBoundParameters }
}
function Get-FalconDeviceControlPolicy {
<#
.SYNOPSIS
Search for Falcon Device Control policies
.DESCRIPTION
Requires 'Device Control Policies: Read'.
.PARAMETER Id
Policy identifier
.PARAMETER Filter
Falcon Query Language expression to limit results
.PARAMETER Sort
Property and direction to sort results
.PARAMETER Limit
Maximum number of results per request
.PARAMETER Offset
Position to begin retrieving results
.PARAMETER Detailed
Retrieve detailed information
.PARAMETER All
Repeat requests until all available results are retrieved
.PARAMETER Total
Display total result count instead of results
.LINK

#>
    [CmdletBinding(DefaultParameterSetName='/policy/queries/device-control/v1:get')]
    param(
        [Parameter(ParameterSetName='/policy/entities/device-control/v1:get',Mandatory,ValueFromPipeline,
            ValueFromPipelineByPropertyName)]
        [ValidatePattern('^\w{32}$')]
        [Alias('ids')]
        [string[]]$Id,

        [Parameter(ParameterSetName='/policy/combined/device-control/v1:get',Position=1)]
        [Parameter(ParameterSetName='/policy/queries/device-control/v1:get',Position=1)]
        [ValidateScript({ Test-FqlStatement $_ })]
        [string]$Filter,

        [Parameter(ParameterSetName='/policy/combined/device-control/v1:get',Position=2)]
        [Parameter(ParameterSetName='/policy/queries/device-control/v1:get',Position=2)]
        [ValidateSet('created_by.asc','created_by.desc','created_timestamp.asc','created_timestamp.desc',
            'enabled.asc','enabled.desc','modified_by.asc','modified_by.desc','modified_timestamp.asc',
            'modified_timestamp.desc','name.asc','name.desc','platform_name.asc','platform_name.desc',
            'precedence.asc','precedence.desc',IgnoreCase=$false)]
        [string]$Sort,

        [Parameter(ParameterSetName='/policy/combined/device-control/v1:get',Position=3)]
        [Parameter(ParameterSetName='/policy/queries/device-control/v1:get',Position=3)]
        [ValidateRange(1,5000)]
        [int32]$Limit,

        [Parameter(ParameterSetName='/policy/combined/device-control/v1:get',Position=4)]
        [Parameter(ParameterSetName='/policy/queries/device-control/v1:get',Position=4)]
        [int32]$Offset,

        [Parameter(ParameterSetName='/policy/combined/device-control/v1:get',Mandatory)]
        [switch]$Detailed,

        [Parameter(ParameterSetName='/policy/combined/device-control/v1:get')]
        [Parameter(ParameterSetName='/policy/queries/device-control/v1:get')]
        [switch]$All,

        [Parameter(ParameterSetName='/policy/queries/device-control/v1:get')]
        [switch]$Total
    )
    begin {
        $Param = @{
            Command = $MyInvocation.MyCommand.Name
            Endpoint = $PSCmdlet.ParameterSetName
            Format = @{ Query = @('sort','ids','offset','filter','limit') }
        }
        [System.Collections.ArrayList]$IdArray = @()
    }
    process {
        if ($Id) {
            @($Id).foreach{ [void]$IdArray.Add($_) }
        } else {
            Invoke-Falcon @Param -Inputs $PSBoundParameters
        }
    }
    end {
        if ($IdArray) {
            $PSBoundParameters['Id'] = @($IdArray | Select-Object -Unique)
            Invoke-Falcon @Param -Inputs $PSBoundParameters
        }
    }
}
function Get-FalconDeviceControlPolicyMember {
<#
.SYNOPSIS
Search for members of Falcon Device Control policies
.DESCRIPTION
Requires 'Device Control Policies: Read'.
.PARAMETER Id
Policy identifier
.PARAMETER Filter
Falcon Query Language expression to limit results
.PARAMETER Sort
Property and direction to sort results
.PARAMETER Limit
Maximum number of results per request
.PARAMETER Offset
Position to begin retrieving results
.PARAMETER Detailed
Retrieve detailed information
.PARAMETER All
Repeat requests until all available results are retrieved
.PARAMETER Total
Display total result count instead of results
.LINK

#>
    [CmdletBinding(DefaultParameterSetName='/policy/queries/device-control-members/v1:get')]
    param(
        [Parameter(ParameterSetName='/policy/queries/device-control-members/v1:get',ValueFromPipeline,
            ValueFromPipelineByPropertyName,Position=1)]
        [Parameter(ParameterSetName='/policy/combined/device-control-members/v1:get',ValueFromPipeline,
            ValueFromPipelineByPropertyName,Position=1)]
        [ValidatePattern('^\w{32}$')]
        [string]$Id,

        [Parameter(ParameterSetName='/policy/queries/device-control-members/v1:get',Position=2)]
        [Parameter(ParameterSetName='/policy/combined/device-control-members/v1:get',Position=2)]
        [ValidateScript({ Test-FqlStatement $_ })]
        [string]$Filter,

        [Parameter(ParameterSetName='/policy/queries/device-control-members/v1:get',Position=3)]
        [Parameter(ParameterSetName='/policy/combined/device-control-members/v1:get',Position=3)]
        [string]$Sort,

        [Parameter(ParameterSetName='/policy/queries/device-control-members/v1:get',Position=4)]
        [Parameter(ParameterSetName='/policy/combined/device-control-members/v1:get',Position=4)]
        [ValidateRange(1,5000)]
        [int32]$Limit,

        [Parameter(ParameterSetName='/policy/queries/device-control-members/v1:get',Position=5)]
        [Parameter(ParameterSetName='/policy/combined/device-control-members/v1:get',Position=5)]
        [int32]$Offset,

        [Parameter(ParameterSetName='/policy/combined/device-control-members/v1:get',Mandatory)]
        [switch]$Detailed,

        [Parameter(ParameterSetName='/policy/combined/device-control-members/v1:get')]
        [Parameter(ParameterSetName='/policy/queries/device-control-members/v1:get')]
        [switch]$All,

        [Parameter(ParameterSetName='/policy/queries/device-control-members/v1:get')]
        [switch]$Total
    )
    begin {
        $Param = @{
            Command = $MyInvocation.MyCommand.Name
            Endpoint = $PSCmdlet.ParameterSetName
            Format = @{ Query = @('sort','offset','filter','id','limit') }
        }
    }
    process { Invoke-Falcon @Param -Inputs $PSBoundParameters }
}
function Invoke-FalconDeviceControlPolicyAction {
<#
.SYNOPSIS
Perform actions on Falcon Device Control policies
.DESCRIPTION
Requires 'Device Control Policies: Write'.
.PARAMETER Name
Action to perform
.PARAMETER Id
Policy identifier
.PARAMETER GroupId
Host group identifier
.LINK

#>
    [CmdletBinding(DefaultParameterSetName='/policy/entities/device-control-actions/v1:post')]
    param(
        [Parameter(ParameterSetName='/policy/entities/device-control-actions/v1:post',Mandatory,
           Position=1)]
        [ValidateSet('add-host-group','disable','enable','remove-host-group',IgnoreCase=$false)]
        [Alias('action_name')]
        [string]$Name,

        [Parameter(ParameterSetName='/policy/entities/device-control-actions/v1:post',Mandatory,Position=2)]
        [ValidatePattern('^\w{32}$')]
        [string]$Id,

        [Parameter(ParameterSetName='/policy/entities/device-control-actions/v1:post',ValueFromPipeline,
            ValueFromPipelineByPropertyName,Position=3)]
        [ValidatePattern('^\w{32}$')]
        [string]$GroupId
    )
    begin {
        $Param = @{
            Command = $MyInvocation.MyCommand.Name
            Endpoint = $PSCmdlet.ParameterSetName
            Format = @{
                Query = @('action_name')
                Body = @{ root = @('ids','action_parameters') }
            }
        }
    }
    process {
        $PSBoundParameters['Ids'] = @($PSBoundParameters.Id)
        [void]$PSBoundParameters.Remove('Id')
        if ($PSBoundParameters.GroupId) {
            $PSBoundParameters['action_parameters'] = @(
                @{
                    name = 'group_id'
                    value = $PSBoundParameters.GroupId
                }
            )
            [void]$PSBoundParameters.Remove('GroupId')
        }
        Invoke-Falcon @Param -Inputs $PSBoundParameters
    }
}
function New-FalconDeviceControlPolicy {
<#
.SYNOPSIS
Create Falcon Device Control policies
.DESCRIPTION
Requires 'Device Control Policies: Write'.
.PARAMETER Array
An array of policies to create in a single request
.PARAMETER Name
Policy name
.PARAMETER PlatformName
Operating system platform
.PARAMETER Description
Policy description
.PARAMETER Settings
Hashtable of policy settings
.LINK

#>
    [CmdletBinding(DefaultParameterSetName='/policy/entities/device-control/v1:post')]
    param(
        [Parameter(ParameterSetName='array',Mandatory)]
        [ValidateScript({
            foreach ($Object in $_) {
                $Param = @{
                    Object = $Object
                    Command = 'New-FalconDeviceControlPolicy'
                    Endpoint = '/policy/entities/device-control/v1:post'
                    Required = @('name','platform_name')
                    Content = @('platform_name')
                    Format = @{ platform_name = 'PlatformName' }
                }
                Confirm-Parameter @Param
            }
        })]
        [Alias('resources')]
        [array]$Array,

        [Parameter(ParameterSetName='/policy/entities/device-control/v1:post',Mandatory,Position=1)]
        [string]$Name,

        [Parameter(ParameterSetName='/policy/entities/device-control/v1:post',Mandatory,Position=2)]
        [ValidateSet('Windows','Mac','Linux',IgnoreCase=$false)]
        [Alias('platform_name')]
        [string]$PlatformName,

        [Parameter(ParameterSetName='/policy/entities/device-control/v1:post',Position=3)]
        [string]$Description,

        [Parameter(ParameterSetName='/policy/entities/device-control/v1:post',Position=4)]
        [Alias('settings')]
        [System.Collections.Hashtable]$Setting
    )
    begin {
        $Param = @{
            Command = $MyInvocation.MyCommand.Name
            Endpoint = '/policy/entities/device-control/v1:post'
            Format = @{
                Body = @{
                    resources = @('name','description','platform_name','settings')
                    root = @('resources')
                }
            }
        }
    }
    process { Invoke-Falcon @Param -Inputs $PSBoundParameters }
}
function Remove-FalconDeviceControlPolicy {
<#
.SYNOPSIS
Remove Falcon Device Control policies
.DESCRIPTION
Requires 'Device Control Policies: Write'.
.PARAMETER Id
Policy identifier
.LINK

#>
    [CmdletBinding(DefaultParameterSetName='/policy/entities/device-control/v1:delete')]
    param(
        [Parameter(ParameterSetName='/policy/entities/device-control/v1:delete',Mandatory,ValueFromPipeline,
            ValueFromPipelineByPropertyName,Position=1)]
        [ValidatePattern('^\w{32}$')]
        [Alias('ids')]
        [string[]]$Id
    )
    begin {
        $Param = @{
            Command = $MyInvocation.MyCommand.Name
            Endpoint = $PSCmdlet.ParameterSetName
            Format = @{ Query = @('ids') }
        }
        [System.Collections.ArrayList]$IdArray = @()
    }
    process { if ($Id) { @($Id).foreach{ [void]$IdArray.Add($_) }}}
    end {
        if ($IdArray) {
            $PSBoundParameters['Id'] = @($IdArray | Select-Object -Unique)
            Invoke-Falcon @Param -Inputs $PSBoundParameters
        }
    }
}
function Set-FalconDeviceControlPrecedence {
<#
.SYNOPSIS
Set Falcon Device Control policy precedence
.DESCRIPTION
Requires 'Device Control Policies: Write'.

All policy identifiers must be supplied in order (with the exception of the 'platform_default' policy) to define
policy precedence.
.PARAMETER PlatformName
Operating system platform
.PARAMETER Id
Policy identifiers in desired precedence order
.LINK

#>
    [CmdletBinding(DefaultParameterSetName='/policy/entities/device-control-precedence/v1:post')]
    param(
        [Parameter(ParameterSetName='/policy/entities/device-control-precedence/v1:post',Mandatory,Position=1)]
        [ValidateSet('Windows','Mac','Linux',IgnoreCase=$false)]
        [Alias('platform_name')]
        [string]$PlatformName,

        [Parameter(ParameterSetName='/policy/entities/device-control-precedence/v1:post',Mandatory,Position=2)]
        [ValidatePattern('^\w{32}$')]
        [Alias('ids')]
        [string[]]$Id
    )
    begin {
        $Param = @{
            Command = $MyInvocation.MyCommand.Name
            Endpoint = $PSCmdlet.ParameterSetName
            Format = @{ Body = @{ root = @('platform_name','ids') }}
        }
    }
    process { Invoke-Falcon @Param -Inputs $PSBoundParameters }
}