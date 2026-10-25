#Requires -Version 5.1
# Verify the extracted release before launching it. Does not change hardware or USB media.
$ErrorActionPreference = 'Stop'
$manifest = Get-Content (Join-Path $PSScriptRoot 'portable-manifest.json') -Raw | ConvertFrom-Json
foreach ($entry in $manifest.PSObject.Properties) {
    $path = Join-Path $PSScriptRoot $entry.Name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing file: $($entry.Name)" }
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $entry.Value) {
        throw "SHA-256 mismatch: $($entry.Name)"
    }
}
. (Join-Path $PSScriptRoot 'HardwareDiscovery.ps1')
$result = Test-StagedUsbIntegrity -FolderPath (Join-Path $PSScriptRoot 'usb-package') -RepoRoot $PSScriptRoot
if (-not $result.AllPassed) { throw ($result.Checks | Out-String) }
Write-Host 'Portable files and USB payload verified.' -ForegroundColor Green
