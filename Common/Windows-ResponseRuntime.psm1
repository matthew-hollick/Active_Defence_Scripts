Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Checks that the current process has administrator privileges.
#>
function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'This action requires an elevated administrator token.'
    }
}

<#
.SYNOPSIS
Checks that the current machine is a domain controller.
#>
function Assert-DomainController {
    $domainRole = (Get-CimInstance -ClassName Win32_ComputerSystem -Property DomainRole).DomainRole
    if ($domainRole -notin 4, 5) {
        throw 'This Active Directory action must run on a domain controller.'
    }
}

<#
.SYNOPSIS
Parses and returns a valid IP address.
#>
function Assert-ValidIpAddress {
    param([Parameter(Mandatory)][string]$Address)
    $parsed = $null
    if (-not [Net.IPAddress]::TryParse($Address, [ref]$parsed)) {
        throw "Invalid IP address: $Address"
    }
    $parsed
}

<#
.SYNOPSIS
Creates an in-memory action result object.
#>
function ConvertTo-ActionResult {
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory)][bool]$Success,
        [Parameter(Mandatory)][string]$Action,
        [Parameter(Mandatory)][string]$Target,
        [hashtable]$Details = @{},
        [string]$ErrorMessage
    )
    [ordered]@{
        success = $Success
        action = $Action
        target = $Target
        host = $env:COMPUTERNAME
        timestampUtc = [DateTime]::UtcNow.ToString('o')
        details = $Details
        error = $ErrorMessage
    }
}

<#
.SYNOPSIS
Writes a successful action result as compressed JSON.
#>
function Write-ActionSuccess {
    param(
        [Parameter(Mandatory)][string]$Action,
        [Parameter(Mandatory)][string]$Target,
        [hashtable]$Details = @{}
    )
    ConvertTo-ActionResult -Success $true -Action $Action -Target $Target -Details $Details | ConvertTo-Json -Depth 6 -Compress
}

<#
.SYNOPSIS
Writes a failed action result as compressed JSON.
#>
function Write-ActionFailure {
    param(
        [Parameter(Mandatory)][string]$Action,
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][string]$ErrorMessage,
        [hashtable]$Details = @{}
    )
    ConvertTo-ActionResult -Success $false -Action $Action -Target $Target -Details $Details -ErrorMessage $ErrorMessage | ConvertTo-Json -Depth 6 -Compress
}

Export-ModuleMember -Function Assert-Administrator, Assert-DomainController, Assert-ValidIpAddress, Write-ActionSuccess, Write-ActionFailure
