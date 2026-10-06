[CmdletBinding()]
param([string]$OutputDirectory = (Join-Path $PSScriptRoot 'packages'))

$ErrorActionPreference = 'Stop'
$catalog = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'catalog.json') -Raw | ConvertFrom-Json
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
Get-ChildItem -LiteralPath $OutputDirectory -Filter '*.zip' -File | Remove-Item -Force
foreach ($action in $catalog.actions) {
    $staging = Join-Path ([IO.Path]::GetTempPath()) ("elastic-script-" + [Guid]::NewGuid().ToString('N'))
    try {
        $scriptPath = Join-Path $PSScriptRoot $action.path
        if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { throw "Script not found: $($action.path)" }
        $stagedScript = Join-Path $staging $action.path
        New-Item -ItemType Directory -Path (Split-Path $stagedScript) -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $staging 'Common') -Force | Out-Null
        Copy-Item -LiteralPath $scriptPath -Destination $stagedScript
        $runtimePath = Join-Path $PSScriptRoot $action.runtime
        if (-not (Test-Path -LiteralPath $runtimePath -PathType Leaf)) { throw "Runtime not found: $($action.runtime)" }
        Copy-Item -LiteralPath $runtimePath -Destination (Join-Path $staging $action.runtime)
        $archive = Join-Path $OutputDirectory (Split-Path $action.package -Leaf)
        if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
        Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $archive -CompressionLevel Optimal
    } finally {
        if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
    }
}
Write-Output "Created $($catalog.actions.Count) Elastic Script Library packages in $OutputDirectory"
