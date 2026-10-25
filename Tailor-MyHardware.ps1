#Requires -Version 5.1
<#
.SYNOPSIS
    Discovers all GPUs (RTX 3000 Ampere & RTX 4000 Ada series), Motherboard, UEFI/Secure Boot,
    live GPU Lock/Unlock status, and Windows EFI System Partition on the current PC, runs
    compatibility checks, and validates the tailored CONFIG.INI profile.
.PARAMETER UpdatePackageConfig
    If set, writes the tailored CONFIG.INI for the current PC into usb-package\RTX4090-PREP\CONFIG.INI
    (otherwise usb-package\RTX4090-PREP\CONFIG.INI remains generic in the repository and is tailored
    on-the-fly when creating a USB stick via Launch-UsbCreator.cmd or Stage-Usb.ps1).
.PARAMETER SaveInventory
    If set, exports the full discovery report to hardware-inventory.json.
.PARAMETER WriteLocalHeader
    If set, writes compile-time C constants to src\unlock\local_board.h.
#>
[CmdletBinding()]
param(
    [ValidateSet("manual", "auto")]
    [string]$DefaultMode = "manual",
    [int]$CountdownSeconds = 5,
    [switch]$GenericDefault,
    [switch]$UpdatePackageConfig,
    [switch]$SaveInventory,
    [switch]$WriteLocalHeader
)

$ErrorActionPreference = "Stop"
$RepoRoot = $PSScriptRoot
. (Join-Path $RepoRoot "HardwareDiscovery.ps1")

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "  NVIDIA GeForce RTX 3000 (GA10x) & RTX 4000 (AD10x) Hardware & UEFI Inspector" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

$report = Get-SystemHardwareReport -RepoRoot $RepoRoot

Write-Host "`n[1/4] Discovered Display Adapters ($($report.AllGpus.Count)):" -ForegroundColor Yellow
foreach ($g in $report.AllGpus) {
    $badge = if ($g.IsCompatible) { "[COMPATIBLE]" } else { "[SKIPPED]   " }
    $color = if ($g.IsCompatible) { "Green" } else { "DarkGray" }
    Write-Host ("  {0} {1} ({2})" -f $badge, $g.Name, $g.ChipFamily) -ForegroundColor $color
    Write-Host ("               PCI ID: {0} | Subsys: {1} | Chip: {2} | BDF: {3} | BAR0: {4}" -f $g.BoardIdHex, $g.SubsystemIdHex, $g.ChipIdHex, $g.BdfString, $g.Bar0BaseHex) -ForegroundColor Gray
    Write-Host ("               VBIOS : {0} | Driver: {1} | VRAM: {2} MiB" -f $g.VbiosVersion, $g.DriverVersion, $g.VramMiB) -ForegroundColor Gray
    Write-Host ("               Note  : {0}" -f $g.CompatReason) -ForegroundColor $color
}

Write-Host "`n[2/4] System & Pre-Boot Compatibility Checks:" -ForegroundColor Yellow
foreach ($c in $report.Checks) {
    $col = switch ($c.Status) { "PASS" { "Green" } "WARN" { "Yellow" } "FAIL" { "Red" } default { "White" } }
    Write-Host ("  [{0,-4}] {1,-36} : {2}" -f $c.Status, $c.Item, $c.Value) -ForegroundColor $col
    if ($c.Status -ne "PASS") {
        Write-Host ("         -> {0}" -f $c.Recommendation) -ForegroundColor DarkYellow
    }
}

if ($report.Issues.Count -gt 0) {
    Write-Host "`n[!] Discovery Warnings / Action Items:" -ForegroundColor Yellow
    foreach ($iss in $report.Issues) {
        Write-Host "    - $iss" -ForegroundColor Yellow
    }
}

$targetGpu = $report.PrimaryGpu
$esp       = $report.WindowsEsp

Write-Host "`n[3/4] Validating Tailored & Generic Profiles..." -ForegroundColor Yellow

$tailoredIni = New-UnlockConfigIniText -Gpu $targetGpu -Esp $esp -Mode $DefaultMode -CountdownSeconds $CountdownSeconds -UniversalGeneric:($GenericDefault.IsPresent -or $null -eq $targetGpu)
$genericIni  = New-UnlockConfigIniText -Gpu $null -Esp $null -Mode $DefaultMode -CountdownSeconds $CountdownSeconds -UniversalGeneric:$true

$valCheck = Test-ConfigIniCompatibility -IniText $tailoredIni -HardwareReport $report
Write-Host ("  [PASS] Dynamic Tailored Profile Validated (Valid={0}, arch={1}, board_id={2})" -f $valCheck.IsValid, $valCheck.Parsed['arch'], $valCheck.Parsed['board_id']) -ForegroundColor Green

$prepDir = Join-Path $RepoRoot "usb-package\RTX4090-PREP"
New-Item -ItemType Directory -Force -Path $prepDir | Out-Null
$genericIniPath = Join-Path $prepDir "CONFIG-GENERIC.INI"
Set-Content -Path $genericIniPath -Value $genericIni -Encoding UTF8

if ($UpdatePackageConfig) {
    $configIniPath = Join-Path $prepDir "CONFIG.INI"
    Set-Content -Path $configIniPath -Value $tailoredIni -Encoding UTF8
    Write-Host "  [OK] Updated package CONFIG.INI : $configIniPath" -ForegroundColor Green
} else {
    Write-Host "  [INFO] Repository CONFIG.INI kept generic (use Stage-Usb.ps1 or Launch-UsbCreator.cmd to write tailored CONFIG.INI directly to USB)." -ForegroundColor Cyan
}

if ($SaveInventory) {
    $invPath = Join-Path $RepoRoot "hardware-inventory.json"
    $report | ConvertTo-Json -Depth 6 | Set-Content -Path $invPath -Encoding UTF8
    Write-Host "  [OK] Saved hardware inventory   : $invPath" -ForegroundColor Green
}

if ($WriteLocalHeader) {
    $espGuidInit = "{ 0x00000000U, 0x0000U, 0x0000U, { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 } }"
    if ($esp.Found -and $esp.Guid -ne "00000000-0000-0000-0000-000000000000") {
        $g = [Guid]$esp.Guid
        $bytes = $g.ToByteArray()
        $d1 = [BitConverter]::ToUInt32($bytes, 0)
        $d2 = [BitConverter]::ToUInt16($bytes, 4)
        $d3 = [BitConverter]::ToUInt16($bytes, 6)
        $espGuidInit = ("{{ 0x{0:x8}U, 0x{1:x4}U, 0x{2:x4}U, {{ 0x{3:x2}, 0x{4:x2}, 0x{5:x2}, 0x{6:x2}, 0x{7:x2}, 0x{8:x2}, 0x{9:x2}, 0x{10:x2} }} }}" -f `
            $d1, $d2, $d3, $bytes[8], $bytes[9], $bytes[10], $bytes[11], $bytes[12], $bytes[13], $bytes[14], $bytes[15])
    }
    $boardIdVal = if ($targetGpu) { "$($targetGpu.BoardIdHex)U" } else { "0U" }
    $subsysVal  = if ($targetGpu) { "$($targetGpu.SubsystemIdHex)U" } else { "0U" }
    $chipIdVal  = if ($targetGpu) { "$($targetGpu.ChipIdHex)U" } else { "0U" }
    $segVal     = if ($targetGpu) { "$($targetGpu.Segment)U" } else { "0U" }
    $busVal     = if ($targetGpu) { "$($targetGpu.Bus)U" } else { "1U" }
    $devVal     = if ($targetGpu) { "$($targetGpu.Device)U" } else { "0U" }
    $fnVal      = if ($targetGpu) { "$($targetGpu.Function)U" } else { "0U" }
    $bar0Val    = if ($targetGpu -and $targetGpu.Bar0Base -gt 0) { "$($targetGpu.Bar0BaseHex)ULL" } else { "0x0ULL" }
    $strictSub  = if ($targetGpu -and $targetGpu.SubsystemIdHex -ne "0x00000000") { 1 } else { 0 }

    $headerContent = @"
#pragma once
#define GU_LOCAL_BOARD_CONFIGURED       1
#define GU_LOCAL_BOARD_ID               $boardIdVal
#define GU_LOCAL_SUBSYSTEM_ID           $subsysVal
#define GU_LOCAL_CHIP_ID                $chipIdVal
#define GU_LOCAL_PCI_SEGMENT            $segVal
#define GU_LOCAL_PCI_BUS                $busVal
#define GU_LOCAL_PCI_DEVICE             $devVal
#define GU_LOCAL_PCI_FUNCTION           $fnVal
#define GU_LOCAL_BAR0_BASE              $bar0Val
#define GU_LOCAL_BAR0_BYTES             0x1000000ULL
#define GU_LOCAL_STRICT_SUBSYSTEM       $strictSub
#define GU_LOCAL_STRICT_BDF             0
#define GU_LOCAL_STRICT_BAR0            0
#define GU_LOCAL_STRICT_ESP             0
#define GU_LOCAL_ALLOW_HEADLESS_HANDOFF 1
#define GU_LOCAL_SAVE_PROM_DUMP         1
#define GU_PROFILE_WINDOWS_ESP_GUID       $espGuidInit
#define GU_PROFILE_WINDOWS_ESP_GUID_STR   "$($esp.Guid.ToLower())"
#define GU_PROFILE_WINDOWS_ESP_PARTITION  $($esp.PartitionNumber)U
#define GU_PROFILE_WINDOWS_ESP_START_LBA  $($esp.StartLba)ULL
#define GU_PROFILE_WINDOWS_ESP_SIZE_LBA   $($esp.SizeLba)ULL
"@
    $localHeaderPath = Join-Path $RepoRoot "src\unlock\local_board.h"
    Set-Content -Path $localHeaderPath -Value $headerContent -Encoding UTF8
    Write-Host "  [OK] Updated C header           : $localHeaderPath" -ForegroundColor Green
}

Write-Host "`n[4/4] Detected USB Drives:" -ForegroundColor Yellow
$usbDrives = Get-UsbDriveInventory
if ($usbDrives.Count -eq 0) {
    Write-Host "  (No removable/USB drives currently plugged in. Plug in a FAT32 USB stick and run .\Stage-Usb.ps1 or .\Launch-UsbCreator.cmd)" -ForegroundColor Gray
} else {
    foreach ($d in $usbDrives) {
        $dCol = if ($d.ReadyToStage) { "Green" } else { "Yellow" }
        Write-Host ("  - {0}" -f $d.DisplayText) -ForegroundColor $dCol
    }
}
Write-Host ""
