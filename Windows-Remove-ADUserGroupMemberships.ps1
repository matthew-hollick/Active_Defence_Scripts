[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Identity,
    [ValidateNotNullOrEmpty()][string]$PreserveGroups = 'Domain Users'
)

$action = 'RemoveADUserGroupMemberships'
$target = $Identity
Import-Module (Join-Path $PSScriptRoot 'Common\Windows-ResponseRuntime.psm1') -Force
try {
    Assert-Administrator
    Assert-DomainController
    Import-Module ActiveDirectory -ErrorAction Stop
    $preserved = @($PreserveGroups -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
    $user = Get-ADUser -Identity $Identity -Properties DistinguishedName
    $groups = @(Get-ADPrincipalGroupMembership -Identity $user | Where-Object { $_.Name -notin $preserved })
    $removed = @()
    foreach ($group in $groups) {
        if ($PSCmdlet.ShouldProcess("$($user.SamAccountName) from $($group.Name)", 'Remove AD group membership')) {
            Remove-ADGroupMember -Identity $group -Members $user -Confirm:$false
            $removed += $group.Name
        }
    }
    Write-ActionSuccess -Action $action -Target $user.SamAccountName -Details @{ removedGroups = $removed; preservedGroups = $preserved }
    exit 0
} catch {
    Write-ActionFailure -Action $action -Target $target -ErrorMessage $_.Exception.Message
    exit 1
}
