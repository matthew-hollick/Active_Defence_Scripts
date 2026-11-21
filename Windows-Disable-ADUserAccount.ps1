[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Identity)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$action = 'DisableADUserAccount'
$target = $Identity
$changed = $false
$protectedGroupName = 'IR-Protected-Accounts'
Import-Module (Join-Path $PSScriptRoot 'Common\Windows-ResponseRuntime.psm1') -Force
try {
    Assert-Administrator
    Assert-DomainController
    Import-Module ActiveDirectory -ErrorAction Stop
    $server = [System.Net.Dns]::GetHostEntry($env:COMPUTERNAME).HostName
    $user = Get-ADUser -Identity $Identity -Server $server -Properties Enabled, DistinguishedName, SID, ObjectGUID, UserPrincipalName, adminCount, MemberOf -ErrorAction Stop
    if ($user.SID.Value -match '-500$' -or $user.SID.Value -match '-502$' -or $user.SamAccountName -like 'krbtgt*') {
        throw "Refusing to disable protected account $($user.SamAccountName) (built-in Administrator/krbtgt)."
    }
    $protectedGroup = Get-ADGroup -Filter "sAMAccountName -eq '$protectedGroupName'" -Server $server -ErrorAction Stop
    $memberOfProperty = $user.PSObject.Properties['MemberOf']
    $memberOf = if ($memberOfProperty) { @($memberOfProperty.Value) } else { @() }
    if ($protectedGroup -and ($memberOf -contains $protectedGroup.DistinguishedName)) {
        throw "Refusing to disable $($user.SamAccountName): direct member of protected group $protectedGroupName."
    }
    $previouslyEnabled = [bool]$user.Enabled
    $status = 'NoChange'
    if ($previouslyEnabled) {
        if ($PSCmdlet.ShouldProcess($user.DistinguishedName, 'Disable AD user account')) {
            Disable-ADAccount -Identity $user -Server $server -Confirm:$false -ErrorAction Stop
            $verifiedUser = Get-ADUser -Identity $user.ObjectGUID -Server $server -Properties Enabled -ErrorAction Stop
            if ($verifiedUser.Enabled) {
                throw 'Account still enabled after Disable-ADAccount.'
            }
            $changed = $true
            $status = 'Changed'
        } else {
            $status = 'Skipped'
        }
    }
    $userProperties = $user.PSObject.Properties
    $userPrincipalNameProperty = $userProperties['UserPrincipalName']
    $adminCountProperty = $userProperties['adminCount']
    $userPrincipalName = if ($userPrincipalNameProperty) { $userPrincipalNameProperty.Value } else { $null }
    $privileged = [bool]($adminCountProperty -and $adminCountProperty.Value -eq 1)
    Write-ActionSuccess -Action $action -Target $user.SamAccountName -Details @{
        distinguishedName = $user.DistinguishedName
        sid = $user.SID.Value
        objectGuid = $user.ObjectGUID.ToString()
        userPrincipalName = $userPrincipalName
        previouslyEnabled = $previouslyEnabled
        changed = $changed
        status = $status
        privileged = $privileged
        server = $server
    }
    exit 0
} catch {
    Write-ActionFailure -Action $action -Target $target -ErrorMessage $_.Exception.Message
    exit 1
}
