[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Name)

$action = 'DisableLocalUserAccount'
$target = $Name
Import-Module (Join-Path $PSScriptRoot 'Common\Windows-ResponseRuntime.psm1') -Force
try {
    Assert-Administrator
    $user = Get-LocalUser -Name $Name
    if ($user.Enabled -and $PSCmdlet.ShouldProcess($user.Name, 'Disable local user account')) {
        Disable-LocalUser -Name $user.Name -Confirm:$false
    }
    Write-ActionSuccess -Action $action -Target $user.Name -Details @{ changed = [bool]$user.Enabled; sid = $user.SID.Value }
    exit 0
} catch {
    Write-ActionFailure -Action $action -Target $target -ErrorMessage $_.Exception.Message
    exit 1
}
