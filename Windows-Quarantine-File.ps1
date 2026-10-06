[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path,
    [string]$QuarantineDirectory = "$env:ProgramData\SIEMResponse\Quarantine"
)

$action = 'QuarantineFile'
$target = $Path
Import-Module (Join-Path $PSScriptRoot 'Common\Windows-ResponseRuntime.psm1') -Force
try {
    Assert-Administrator
    $file = Get-Item -LiteralPath $Path -Force
    if ($file.PSIsContainer) { throw 'The target must be a file.' }
    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    $destination = Join-Path $QuarantineDirectory "$hash.quarantine"
    if ($PSCmdlet.ShouldProcess($file.FullName, "Move to $destination")) {
        New-Item -ItemType Directory -Path $QuarantineDirectory -Force | Out-Null
        if (Test-Path -LiteralPath $destination) { throw "A quarantined file with SHA256 $hash already exists." }
        Move-Item -LiteralPath $file.FullName -Destination $destination
        Set-Acl -LiteralPath $destination -AclObject (Get-Acl -LiteralPath $QuarantineDirectory)
    }
    Write-ActionSuccess -Action $action -Target $target -Details @{ sha256 = $hash; quarantinePath = $destination; originalLength = $file.Length }
    exit 0
} catch {
    Write-ActionFailure -Action $action -Target $target -ErrorMessage $_.Exception.Message
    exit 1
}
