[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$AllowRemoteAddress)

$action = 'IsolateHost'
$target = $env:COMPUTERNAME
Import-Module (Join-Path $PSScriptRoot 'Common\Windows-ResponseRuntime.psm1') -Force
try {
    Assert-Administrator
    $allowed = @($AllowRemoteAddress -split ',' | ForEach-Object { (Assert-ValidIpAddress -Address $_.Trim()).ToString() } | Select-Object -Unique)
    $statePath = "$env:ProgramData\SIEMResponse\firewall-state.json"
    $profiles = @(Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction)
    if ($PSCmdlet.ShouldProcess($target, "Isolate host except $($allowed -join ', ')")) {
        New-Item -ItemType Directory -Path (Split-Path $statePath) -Force | Out-Null
        @{ capturedUtc = [DateTime]::UtcNow.ToString('o'); profiles = $profiles } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $statePath -Encoding UTF8
        Get-NetFirewallRule -Group 'SIEM Response Isolation' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
        New-NetFirewallRule -DisplayName 'SIEM Response Isolation - Allowed Inbound' -Group 'SIEM Response Isolation' -Direction Inbound -Action Allow -RemoteAddress $allowed -Profile Any | Out-Null
        New-NetFirewallRule -DisplayName 'SIEM Response Isolation - Allowed Outbound' -Group 'SIEM Response Isolation' -Direction Outbound -Action Allow -RemoteAddress $allowed -Profile Any | Out-Null
        Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Block
    }
    Write-ActionSuccess -Action $action -Target $target -Details @{ allowedRemoteAddresses = $allowed; statePath = $statePath }
    exit 0
} catch {
    Write-ActionFailure -Action $action -Target $target -ErrorMessage $_.Exception.Message
    exit 1
}
