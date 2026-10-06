[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)][string]$Address,
    [ValidateSet('Inbound', 'Outbound', 'Both')][string]$Direction = 'Both'
)

$action = 'BlockRemoteIPAddress'
$target = $Address
Import-Module (Join-Path $PSScriptRoot 'Common\Windows-ResponseRuntime.psm1') -Force
try {
    Assert-Administrator
    $ip = Assert-ValidIpAddress -Address $Address
    $normalized = $ip.ToString()
    $directions = if ($Direction -eq 'Both') { @('Inbound', 'Outbound') } else { @($Direction) }
    $created = @()
    foreach ($item in $directions) {
        $displayName = "SIEM Response - Block $normalized - $item"
        $existing = Get-NetFirewallRule -DisplayName $displayName -ErrorAction SilentlyContinue
        if (-not $existing -and $PSCmdlet.ShouldProcess("$normalized ($item)", 'Create firewall block rule')) {
            New-NetFirewallRule -DisplayName $displayName -Group 'SIEM Response' -Direction $item -Action Block -RemoteAddress $normalized -Profile Any | Out-Null
            $created += $displayName
        }
    }
    Write-ActionSuccess -Action $action -Target $normalized -Details @{ direction = $Direction; createdRules = $created }
    exit 0
} catch {
    Write-ActionFailure -Action $action -Target $target -ErrorMessage $_.Exception.Message
    exit 1
}
