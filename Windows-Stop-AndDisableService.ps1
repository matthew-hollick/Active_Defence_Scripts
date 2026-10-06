[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param([Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$Name)

$action = 'StopAndDisableService'
$target = $Name
Import-Module (Join-Path $PSScriptRoot 'Common\Windows-ResponseRuntime.psm1') -Force
try {
    Assert-Administrator
    $service = Get-CimInstance Win32_Service -Filter "Name='$($Name.Replace("'", "''"))'"
    if (-not $service) { throw "Service not found: $Name" }
    $details = @{ displayName = $service.DisplayName; previousState = $service.State; previousStartMode = $service.StartMode; path = $service.PathName }
    if ($PSCmdlet.ShouldProcess($service.Name, 'Stop and disable service')) {
        if ($service.State -ne 'Stopped') { Stop-Service -Name $service.Name -Force -Confirm:$false }
        Set-Service -Name $service.Name -StartupType Disabled -Confirm:$false
    }
    Write-ActionSuccess -Action $action -Target $service.Name -Details $details
    exit 0
} catch {
    Write-ActionFailure -Action $action -Target $target -ErrorMessage $_.Exception.Message
    exit 1
}
