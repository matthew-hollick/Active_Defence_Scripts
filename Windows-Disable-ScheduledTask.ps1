[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$TaskName,
    [ValidateNotNullOrEmpty()][string]$TaskPath = '\'
)

$action = 'DisableScheduledTask'
$target = "$TaskPath$TaskName"
Import-Module (Join-Path $PSScriptRoot 'Common\Windows-ResponseRuntime.psm1') -Force
try {
    Assert-Administrator
    $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath
    $details = @{ state = $task.State.ToString(); author = $task.Author; actions = @($task.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) }
    if ($task.State -ne 'Disabled' -and $PSCmdlet.ShouldProcess($target, 'Disable scheduled task')) {
        Disable-ScheduledTask -InputObject $task | Out-Null
    }
    Write-ActionSuccess -Action $action -Target $target -Details $details
    exit 0
} catch {
    Write-ActionFailure -Action $action -Target $target -ErrorMessage $_.Exception.Message
    exit 1
}
