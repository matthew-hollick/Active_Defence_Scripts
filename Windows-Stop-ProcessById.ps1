[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param([Parameter(Mandatory)][ValidateRange(1, 2147483647)][int]$ProcessId)

$action = 'StopProcessById'
$target = [string]$ProcessId
Import-Module (Join-Path $PSScriptRoot 'Common\Windows-ResponseRuntime.psm1') -Force
try {
    Assert-Administrator
    if ($ProcessId -eq $PID) { throw 'Refusing to terminate the response script process.' }
    $process = Get-Process -Id $ProcessId
    $details = @{ processName = $process.ProcessName; path = $process.Path }
    if ($PSCmdlet.ShouldProcess("$($process.ProcessName) ($ProcessId)", 'Force-stop process')) {
        Stop-Process -Id $ProcessId -Force -Confirm:$false
    }
    Write-ActionSuccess -Action $action -Target $target -Details $details
    exit 0
} catch {
    Write-ActionFailure -Action $action -Target $target -ErrorMessage $_.Exception.Message
    exit 1
}
