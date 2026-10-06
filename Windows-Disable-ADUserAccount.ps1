[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Identity)

$action = 'DisableADUserAccount'
$target = $Identity
Import-Module (Join-Path $PSScriptRoot 'Common\Windows-ResponseRuntime.psm1') -Force
try {
    Assert-Administrator
    Assert-DomainController
    Import-Module ActiveDirectory -ErrorAction Stop
    $user = Get-ADUser -Identity $Identity -Properties Enabled, DistinguishedName
    if ($user.Enabled -and $PSCmdlet.ShouldProcess($user.DistinguishedName, 'Disable AD user account')) {
        Disable-ADAccount -Identity $user -Confirm:$false
    }
    Write-ActionSuccess -Action $action -Target $user.SamAccountName -Details @{ distinguishedName = $user.DistinguishedName; changed = [bool]$user.Enabled }
    exit 0
} catch {
    Write-ActionFailure -Action $action -Target $target -ErrorMessage $_.Exception.Message
    exit 1
}
