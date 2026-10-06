Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'This action requires an elevated administrator token.'
    }
}

function Assert-DomainController {
    $domainRole = (Get-CimInstance -ClassName Win32_ComputerSystem -Property DomainRole).DomainRole
    if ($domainRole -notin 4, 5) {
        throw 'This Active Directory action must run on a domain controller.'
    }
}

function Assert-ValidIpAddress {
    param([Parameter(Mandatory)][string]$Address)
    $parsed = $null
    if (-not [Net.IPAddress]::TryParse($Address, [ref]$parsed)) {
        throw "Invalid IP address: $Address"
    }
    $parsed
}

function New-ActionResult {
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

function Write-ActionSuccess {
    param(
        [Parameter(Mandatory)][string]$Action,
        [Parameter(Mandatory)][string]$Target,
        [hashtable]$Details = @{}
    )
    New-ActionResult -Success $true -Action $Action -Target $Target -Details $Details | ConvertTo-Json -Depth 6 -Compress
}

function Write-ActionFailure {
    param(
        [Parameter(Mandatory)][string]$Action,
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][string]$ErrorMessage
    )
    New-ActionResult -Success $false -Action $Action -Target $Target -ErrorMessage $ErrorMessage | ConvertTo-Json -Depth 6 -Compress
}

Export-ModuleMember -Function Assert-Administrator, Assert-DomainController, Assert-ValidIpAddress, Write-ActionSuccess, Write-ActionFailure
