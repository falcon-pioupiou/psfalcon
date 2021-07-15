function Get-FalconStream {
<#
.Synopsis
List event streams in your environment
.Parameter Format
Format for streaming events [default: json]
.Parameter Appid
Label that identifies the connection
.Role
streaming:read
#>
    [CmdletBinding(DefaultParameterSetName = '/sensors/entities/datafeed/v2:get')]
    param(
        [Parameter(ParameterSetName = '/sensors/entities/datafeed/v2:get', Mandatory = $true, Position = 1)]
        [string] $AppId,

        [Parameter(ParameterSetName = '/sensors/entities/datafeed/v2:get', Position = 2)]
        [ValidateSet('json', 'flatjson')]
        [string] $Format
    )
    begin {
        $Param = @{
            Command  = $MyInvocation.MyCommand.Name
            Endpoint = $PSCmdlet.ParameterSetName
            Inputs   = $PSBoundParameters
            Headers  = @{
                ContentType = 'application/json'
            }
            Format   = @{
                Query = @('format', 'appId')
            }
        }
    }
    process {
        Invoke-Falcon @Param
    }
}
function Update-FalconStream {
<#
.Synopsis
Refresh an active event stream
.Parameter Appid
Label that identifies the connection
.Parameter Partition
Partition number to refresh
.Role
streaming:read
#>
    [CmdletBinding(DefaultParameterSetName = '/sensors/entities/datafeed-actions/v1/{partition}:post')]
    param(
        [Parameter(ParameterSetName = '/sensors/entities/datafeed-actions/v1/{partition}:post', Mandatory = $true,
            Position = 1)]
        [ValidatePattern('^\w{1,32}$')]
        [string] $AppId,

        [Parameter(ParameterSetName = '/sensors/entities/datafeed-actions/v1/{partition}:post', Mandatory = $true,
            Position = 2)]
        [int] $Partition
    )
    begin {
        $Endpoint = $PSCmdlet.ParameterSetName -replace '{partition}', $PSBoundParameters.Partition
        $PSBoundParameters.Remove('Partition')
        [void] $PSBoundParameters.Add('action_name', 'refresh_active_stream_session')
        $Param = @{
            Command  = $MyInvocation.MyCommand.Name
            Endpoint = $Endpoint
            Inputs   = $PSBoundParameters
            Headers  = @{
                ContentType = 'application/json'
            }
            Format   = @{
                Query = @('action_name', 'appId')
            }
        }
    }
    process {
        Invoke-Falcon @Param
    }
}