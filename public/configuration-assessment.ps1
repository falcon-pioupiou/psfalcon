function Get-FalconConfigAssessment {
<#
.SYNOPSIS
Search for ConfigVantage assessments
.DESCRIPTION
Requires 'ConfigVantage: Read'.
.PARAMETER Filter
Falcon Query Language expression to limit results
.PARAMETER Facet
Include additional properties
.PARAMETER Sort
Property and direction to sort results
.PARAMETER Limit
Maximum number of results per request
.PARAMETER After
Pagination token to retrieve the next set of results
.PARAMETER All
Repeat requests until all available results are retrieved
.PARAMETER Total
Display total result count instead of results
.LINK
https://github.com/crowdstrike/psfalcon/wiki/Get-FalconConfigAssessment
#>
    [CmdletBinding(DefaultParameterSetName='/configuration-assessment/combined/assessments/v1:get',
        SupportsShouldProcess)]
    param(
        [Parameter(ParameterSetName='/configuration-assessment/combined/assessments/v1:get',Mandatory,Position=1)]
        [ValidateScript({ Test-FqlStatement $_ })]
        [string]$Filter,
        [Parameter(ParameterSetName='/configuration-assessment/combined/assessments/v1:get',Position=2)]
        [ValidateSet('host','finding.rule',IgnoreCase=$false)]
        [string[]]$Facet,
        [Parameter(ParameterSetName='/configuration-assessment/combined/assessments/v1:get',Position=3)]
        [ValidateSet('created_timestamp|asc','created_timestamp|desc','updated_timestamp|asc',
            'updated_timestamp|desc',IgnoreCase=$false)]
        [string]$Sort,
        [Parameter(ParameterSetName='/configuration-assessment/combined/assessments/v1:get',Position=4)]
        [ValidateRange(1,5000)]
        [int]$Limit,
        [Parameter(ParameterSetName='/configuration-assessment/combined/assessments/v1:get')]
        [string]$After,
        [Parameter(ParameterSetName='/configuration-assessment/combined/assessments/v1:get')]
        [switch]$All,
        [Parameter(ParameterSetName='/configuration-assessment/combined/assessments/v1:get')]
        [switch]$Total
    )
    begin {
        $Param = @{
            Command = $MyInvocation.MyCommand.Name
            Endpoint = $PSCmdlet.ParameterSetName
            Format = @{ Query = @('filter','sort','limit','facet','after') }
        }
    }
    process { Invoke-Falcon @Param -Inputs $PSBoundParameters }
}