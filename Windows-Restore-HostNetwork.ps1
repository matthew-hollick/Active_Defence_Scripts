[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param()

$action = 'RestoreHostNetwork'
$target = $env:COMPUTERNAME
Import-Module (Join-Path $PSScriptRoot 'Common\Windows-ResponseRuntime.psm1') -Force
try {
    Assert-Administrator
    $statePath = "$env:ProgramData\SIEMResponse\firewall-state.json"
    if (-not (Test-Path -LiteralPath $statePath)) { throw "Firewall state file not found: $statePath" }
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    if ($PSCmdlet.ShouldProcess($target, 'Restore pre-isolation firewall profile defaults')) {
        foreach ($profile in $state.profiles) {
            Set-NetFirewallProfile -Profile $profile.Name -Enabled ([bool]$profile.Enabled) -DefaultInboundAction $profile.DefaultInboundAction -DefaultOutboundAction $profile.DefaultOutboundAction
        }
        Get-NetFirewallRule -Group 'SIEM Response Isolation' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
        Remove-Item -LiteralPath $statePath -Force
    }
    Write-ActionSuccess -Action $action -Target $target -Details @{ restoredFrom = $statePath }
    exit 0
} catch {
    Write-ActionFailure -Action $action -Target $target -ErrorMessage $_.Exception.Message
    exit 1
}
