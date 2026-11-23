[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Identity,
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$AdditionalIdentity
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$action = 'DisableADUserAccount'
$target = ''
$failureDetails = @{}
$protectedGroupName = 'IR-Protected-Accounts'
Import-Module (Join-Path $PSScriptRoot 'Common\Windows-ResponseRuntime.psm1') -Force
try {
    $uniqueIdentities = [System.Collections.Generic.List[string]]::new()
    $seenIdentities = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($identityValue in @($Identity) + @($AdditionalIdentity)) {
        if ($null -eq $identityValue) {
            continue
        }
        $trimmedIdentity = $identityValue.Trim()
        if ($trimmedIdentity.Length -gt 0 -and $seenIdentities.Add($trimmedIdentity)) {
            $uniqueIdentities.Add($trimmedIdentity)
        }
    }
    if ($uniqueIdentities.Count -eq 0) {
        throw 'At least one non-blank account identity must be supplied.'
    }
    $identities = [string[]]$uniqueIdentities.ToArray()
    $target = [string]::Join(' ', $identities)

    Assert-Administrator
    Assert-DomainController
    Import-Module ActiveDirectory -ErrorAction Stop
    $server = [System.Net.Dns]::GetHostEntry($env:COMPUTERNAME).HostName
    $protectedGroup = Get-ADGroup -Filter "sAMAccountName -eq '$protectedGroupName'" -Server $server -ErrorAction Stop

    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($accountIdentity in $identities) {
        $accountResult = [ordered]@{
            identity = $accountIdentity
            status = 'Failed'
            changed = $false
            error = $null
            samAccountName = $null
            distinguishedName = $null
            sid = $null
            objectGuid = $null
            userPrincipalName = $null
            previouslyEnabled = $null
            privileged = $null
        }
        try {
            $user = Get-ADUser -Identity $accountIdentity -Server $server -Properties Enabled, DistinguishedName, SID, ObjectGUID, UserPrincipalName, adminCount, MemberOf -ErrorAction Stop
            $accountResult.samAccountName = $user.SamAccountName
            $accountResult.distinguishedName = $user.DistinguishedName
            $accountResult.sid = $user.SID.Value
            $accountResult.objectGuid = $user.ObjectGUID.ToString()
            $accountResult.previouslyEnabled = [bool]$user.Enabled

            $userProperties = $user.PSObject.Properties
            $userPrincipalNameProperty = $userProperties['UserPrincipalName']
            $adminCountProperty = $userProperties['adminCount']
            if ($userPrincipalNameProperty) {
                $accountResult.userPrincipalName = $userPrincipalNameProperty.Value
            }
            $accountResult.privileged = [bool]($adminCountProperty -and $adminCountProperty.Value -eq 1)

            if ($user.SID.Value -match '-500$' -or $user.SID.Value -match '-502$' -or $user.SamAccountName -like 'krbtgt*') {
                throw "Refusing to disable protected account $($user.SamAccountName) (built-in Administrator/krbtgt)."
            }
            $memberOfProperty = $userProperties['MemberOf']
            $memberOf = if ($memberOfProperty) { @($memberOfProperty.Value) } else { @() }
            if ($protectedGroup -and ($memberOf -contains $protectedGroup.DistinguishedName)) {
                throw "Refusing to disable $($user.SamAccountName): direct member of protected group $protectedGroupName."
            }

            if ($accountResult.previouslyEnabled) {
                if ($PSCmdlet.ShouldProcess($user.DistinguishedName, 'Disable AD user account')) {
                    Disable-ADAccount -Identity $user -Server $server -Confirm:$false -ErrorAction Stop
                    $verifiedUser = Get-ADUser -Identity $user.ObjectGUID -Server $server -Properties Enabled -ErrorAction Stop
                    if ($verifiedUser.Enabled) {
                        throw 'Account still enabled after Disable-ADAccount.'
                    }
                    $accountResult.changed = $true
                    $accountResult.status = 'Changed'
                } else {
                    $accountResult.status = 'Skipped'
                }
            } else {
                $accountResult.status = 'NoChange'
            }
        } catch {
            $accountResult.status = 'Failed'
            $accountResult.changed = $false
            $accountResult.error = $_.Exception.Message
        }

        $results.Add($accountResult)
    }

    $resultArray = [object[]]$results.ToArray()
    $summary = [ordered]@{
        changed = 0
        noChange = 0
        skipped = 0
        failed = 0
    }
    foreach ($accountResult in $resultArray) {
        switch ($accountResult.status) {
            'Changed' { $summary.changed++ }
            'NoChange' { $summary.noChange++ }
            'Skipped' { $summary.skipped++ }
            'Failed' { $summary.failed++ }
        }
    }

    $details = @{
        server = $server
        requested = $identities.Count
        summary = $summary
        results = $resultArray
    }
    if ($summary.failed -eq 0) {
        Write-ActionSuccess -Action $action -Target $target -Details $details
        exit 0
    }

    $failedIdentities = @($resultArray | Where-Object { $_.status -eq 'Failed' } | ForEach-Object { $_.identity })
    $errorMessage = '{0} of {1} account(s) failed: {2}' -f $summary.failed, $identities.Count, [string]::Join(', ', [string[]]$failedIdentities)
    Write-ActionFailure -Action $action -Target $target -ErrorMessage $errorMessage -Details $details
    exit 1
} catch {
    Write-ActionFailure -Action $action -Target $target -ErrorMessage $_.Exception.Message -Details $failureDetails
    exit 1
}
