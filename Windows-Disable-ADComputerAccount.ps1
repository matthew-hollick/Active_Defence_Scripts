[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Identity)

$action = 'DisableADComputerAccount'
$target = $Identity
Import-Module (Join-Path $PSScriptRoot 'Common\Windows-ResponseRuntime.psm1') -Force
try {
    Assert-Administrator
    Assert-DomainController
    Import-Module ActiveDirectory -ErrorAction Stop
    $computer = Get-ADComputer -Identity $Identity -Properties Enabled, DistinguishedName
    if ($computer.Enabled -and $PSCmdlet.ShouldProcess($computer.DistinguishedName, 'Disable AD computer account')) {
        Disable-ADAccount -Identity $computer -Confirm:$false
    }
    Write-ActionSuccess -Action $action -Target $computer.SamAccountName -Details @{ distinguishedName = $computer.DistinguishedName; changed = [bool]$computer.Enabled }
    exit 0
} catch {
    Write-ActionFailure -Action $action -Target $target -ErrorMessage $_.Exception.Message
    exit 1
}
