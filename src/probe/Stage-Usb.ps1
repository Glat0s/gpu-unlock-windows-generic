# SPDX-License-Identifier: MIT
param([Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z]$')][string]$DriveLetter)
$ErrorActionPreference = 'Stop'
$probeProject = Split-Path -Parent $PSScriptRoot
$probePackage = Join-Path $probeProject 'build\read-only-probe\usb-package'
$probeBuild = Get-Content -LiteralPath (Join-Path $probeProject 'build\read-only-probe\build-result.json') -Raw | ConvertFrom-Json
$probePartition = @(Get-Partition -DriveLetter $DriveLetter)
if ($probePartition.Count -ne 1) { throw 'Drive letter does not identify exactly one partition.' }
$probeDisk = Get-Disk -Number $probePartition[0].DiskNumber
$probeVolume = Get-Volume -DriveLetter $DriveLetter
if ($probeDisk.BusType -ne 'USB' -or $probeDisk.IsBoot -or $probeDisk.IsSystem) { throw 'Refusing a non-USB, boot or system disk.' }
if ($probeVolume.FileSystem -ne 'FAT32') { throw 'A FAT32 USB volume is required. This script never formats disks.' }
$probeRoot = [IO.Path]::GetFullPath("${DriveLetter}:\")
$probeFiles = @('EFI\BOOT\BOOTX64.EFI','GPU-PROBE\ALLOW-READONLY.TAG','GPU-PROBE\BUILD.json')
foreach ($probeRelative in $probeFiles) {
    $probeSource = Join-Path $probePackage $probeRelative
    if (-not (Test-Path -LiteralPath $probeSource -PathType Leaf)) { throw "Missing package file: $probeRelative" }
    $probeTarget = [IO.Path]::GetFullPath((Join-Path $probeRoot $probeRelative))
    if (-not $probeTarget.StartsWith($probeRoot,[StringComparison]::OrdinalIgnoreCase)) { throw 'Destination escaped the USB root.' }
    if (Test-Path -LiteralPath $probeTarget) {
        if (-not (Test-Path -LiteralPath $probeTarget -PathType Leaf)) { throw "Destination is not a regular file: $probeTarget" }
        if ((Get-FileHash -LiteralPath $probeTarget).Hash -ne (Get-FileHash -LiteralPath $probeSource).Hash) {
            throw "Existing file differs; refusing to replace it: $probeTarget"
        }
    }
}
if ((Get-FileHash -LiteralPath (Join-Path $probePackage 'EFI\BOOT\BOOTX64.EFI')).Hash.ToLower() -ne $probeBuild.sha256) {
    throw 'Packaged EFI hash differs from the tested build.'
}
foreach ($probeRelative in $probeFiles) {
    $probeTarget = Join-Path $probeRoot $probeRelative
    if (-not (Test-Path -LiteralPath $probeTarget)) {
        [IO.Directory]::CreateDirectory((Split-Path -Parent $probeTarget)) | Out-Null
        [IO.File]::Copy((Join-Path $probePackage $probeRelative),$probeTarget,$false)
    }
    if ((Get-FileHash -LiteralPath $probeTarget).Hash -ne (Get-FileHash -LiteralPath (Join-Path $probePackage $probeRelative)).Hash) {
        throw "Copy verification failed: $probeTarget"
    }
}
$probeStage = [ordered]@{ drive_letter=$DriveLetter.ToUpper(); disk_number=$probeDisk.Number;
    device=$probeDisk.FriendlyName; bytes=$probeDisk.Size; filesystem=$probeVolume.FileSystem;
    efi_sha256=$probeBuild.sha256; disk_formatted=$false; existing_files_replaced=$false;
    boot_settings_changed=$false; unlock_staged=$false; staged_at=(Get-Date).ToString('o') }
$probeStage | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $probeProject 'build\read-only-probe\usb-stage.json') -Encoding UTF8
$probeStage | ConvertTo-Json
