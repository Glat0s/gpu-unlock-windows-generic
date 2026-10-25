#Requires -Version 5.1
<#
.SYNOPSIS
    Safely stages the RTX 3000 (GA10x) & RTX 4000 (AD10x) UEFI Unlocker package onto a FAT32 USB drive
    with comprehensive hardware, filesystem, free-space, config, and SHA-256 integrity checks.
.PARAMETER DriveLetter
    The drive letter of the FAT32 USB drive (e.g. "E" or "E:").
.PARAMETER Mode
    Boot mode to install as \EFI\BOOT\BOOTX64.EFI:
      - manual (default): Prompts for [U] to unlock + boot Windows, or [S] to skip unlock.
      - auto: Waits CountdownSeconds (default 5s) then unlocks + boots Windows automatically.
      - probe: Installs the read-only hardware diagnostics probe as BOOTX64.EFI.
.PARAMETER CountdownSeconds
    Countdown seconds when Mode is 'auto' (1..60, default 5).
.PARAMETER Generic
    If specified, installs the Universal Generic CONFIG.INI (board_id = any, arch = auto)
    to discover a catalog GPU at boot; physical compatibility remains experimental.
.PARAMETER VerifyOnly
    If specified, only runs integrity and compatibility checks on an already-staged USB drive.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Target FAT32 USB drive letter (e.g. E or E:)")]
    [string]$DriveLetter = "",

    [Parameter(Mandatory = $false, HelpMessage = "Optional local folder path to stage or verify")]
    [Alias("DestinationPath")]
    [string]$FolderPath = "",

    [Parameter(Mandatory = $false)]
    [ValidateSet("manual", "auto", "probe")]
    [string]$Mode = "manual",

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 60)]
    [int]$CountdownSeconds = 5,

    [Parameter(Mandatory = $false)]
    [switch]$Generic,

    [Parameter(Mandatory = $false)]
    [switch]$VerifyOnly
)

$ErrorActionPreference = "Stop"
$RepoRoot = $PSScriptRoot
. (Join-Path $RepoRoot "HardwareDiscovery.ps1")

$UsbPkgDir = Join-Path $RepoRoot "usb-package"
$hwReport = Get-SystemHardwareReport -RepoRoot $RepoRoot

if (-not $DriveLetter -and -not $FolderPath) {
    throw "Specify -DriveLetter <E> for a FAT32 USB stick, or -FolderPath <path> for a local staging folder."
}

if ($VerifyOnly) {
    if ($FolderPath) {
        Write-Host "=== Verifying Package Folder at $FolderPath ===" -ForegroundColor Cyan
        $res = Test-StagedUsbIntegrity -FolderPath $FolderPath -RepoRoot $RepoRoot -HardwareReport $hwReport
    } else {
        $cleanLetter = $DriveLetter.Trim().TrimEnd(':').ToUpper()
        Write-Host "=== Verifying Existing USB Stick at ${cleanLetter}:\ ===" -ForegroundColor Cyan
        $res = Test-StagedUsbIntegrity -DriveLetter $cleanLetter -RepoRoot $RepoRoot -HardwareReport $hwReport
    }
    foreach ($c in $res.Checks) {
        $col = switch ($c.Status) { "PASS" { "Green" } "WARN" { "Yellow" } "FAIL" { "Red" } }
        Write-Host ("  [{0,-4}] {1,-45} {2}" -f $c.Status, $c.Item, $c.Detail) -ForegroundColor $col
    }
    if (-not $res.AllPassed) {
        throw "Verification failed."
    }
    Write-Host "`nAll verification checks PASSED!" -ForegroundColor Green
    return
}

if (-not (Test-Path (Join-Path $UsbPkgDir "EFI\BOOT\BOOTX64.EFI"))) {
    throw "usb-package is incomplete or missing. Run 'python build.py' first."
}

Assert-StagingTarget -DriveLetter $DriveLetter -FolderPath $FolderPath -RepoRoot $RepoRoot

if ($FolderPath) {
    $TargetRoot = $FolderPath
    New-Item -ItemType Directory -Force -Path $TargetRoot | Out-Null
} else {
    $cleanLetter = $DriveLetter.Trim().TrimEnd(':').ToUpper()
    if ($cleanLetter.Length -ne 1 -or $cleanLetter -lt 'A' -or $cleanLetter -gt 'Z') {
        throw "Invalid drive letter '$DriveLetter'. Provide a single drive letter like E or E:."
    }

    $systemDrive = $env:SystemDrive.TrimEnd(':').ToUpper()
    if ($cleanLetter -eq $systemDrive) {
        throw "Refusing to stage onto system drive ${cleanLetter}:."
    }

    $vol = Get-Volume -DriveLetter $cleanLetter -ErrorAction Stop
    $fileSystem = Get-VolumeFileSystemName -Volume $vol
    if ($fileSystem -ne "FAT32") {
        throw "Target drive ${cleanLetter}: filesystem is '$fileSystem' (UNKNOWN means detection failed). FAT32 is required."
    }

    $part = Get-Partition -DriveLetter $cleanLetter -ErrorAction SilentlyContinue
    if ($part) {
        $disk = Get-Disk -Number $part.DiskNumber -ErrorAction SilentlyContinue
        if ($disk -and ($disk.IsBoot -or $disk.IsSystem)) {
            throw "Refusing to stage onto system/boot disk #$($disk.Number) (${cleanLetter}:)."
        }
    }

    $freeMB = [math]::Round($vol.SizeRemaining / 1MB, 1)
    $hasExisting = Test-Path "${cleanLetter}:\RTX4090-PREP\ASSETS\gsp_ga10x.bin"
    if ($freeMB -lt 95 -and -not $hasExisting) {
        throw "Target drive ${cleanLetter}: has only $freeMB MB free (~90 MB required for firmware assets)."
    }

    $TargetRoot = "${cleanLetter}:\"
}
Write-Host "`n=== Staging RTX 3000/4000 UEFI Unlocker to $TargetRoot (Mode: $Mode, Generic: $($Generic.IsPresent)) ===" -ForegroundColor Cyan

$TargetEfiBoot    = Join-Path $TargetRoot "EFI\BOOT"
$TargetPrep       = Join-Path $TargetRoot "RTX4090-PREP"
$TargetPrepAssets = Join-Path $TargetPrep "ASSETS"
$TargetProbe      = Join-Path $TargetRoot "GPU-PROBE"

New-Item -ItemType Directory -Force -Path $TargetEfiBoot    | Out-Null
New-Item -ItemType Directory -Force -Path $TargetPrep       | Out-Null
New-Item -ItemType Directory -Force -Path $TargetPrepAssets | Out-Null
New-Item -ItemType Directory -Force -Path $TargetProbe      | Out-Null

# 1. Copy EFI loaders
Copy-Item -Path (Join-Path $UsbPkgDir "EFI\BOOT\*.EFI") -Destination $TargetEfiBoot -Force
switch ($Mode) {
    "manual" { Copy-Item -Path (Join-Path $UsbPkgDir "EFI\BOOT\UNLOCK-MANUAL.EFI") -Destination (Join-Path $TargetEfiBoot "BOOTX64.EFI") -Force }
    "auto"   { Copy-Item -Path (Join-Path $UsbPkgDir "EFI\BOOT\UNLOCK-AUTO.EFI")   -Destination (Join-Path $TargetEfiBoot "BOOTX64.EFI") -Force }
    "probe"  { Copy-Item -Path (Join-Path $UsbPkgDir "EFI\BOOT\PROBE-READONLY.EFI")-Destination (Join-Path $TargetEfiBoot "BOOTX64.EFI") -Force }
}

# 2. Copy Probe Tag & Instructions
Copy-Item -Path (Join-Path $UsbPkgDir "GPU-PROBE\ALLOW-READONLY.TAG") -Destination (Join-Path $TargetProbe "ALLOW-READONLY.TAG") -Force
if (Test-Path (Join-Path $UsbPkgDir "INSTRUCTIONS.txt")) {
    Copy-Item -Path (Join-Path $UsbPkgDir "INSTRUCTIONS.txt") -Destination (Join-Path $TargetRoot "INSTRUCTIONS.txt") -Force
}

# 3. Copy all 9 AD102 + GA102 firmware assets into \RTX4090-PREP\ASSETS\
Write-Host "Copying NVIDIA 610.43.03 AD10x (RTX 4000) & GA10x (RTX 3000) firmware assets (~84.6 MB)..." -ForegroundColor Yellow
Copy-Item -Path (Join-Path $UsbPkgDir "RTX4090-PREP\ASSETS\*") -Destination $TargetPrepAssets -Force

# 4. Generate and validate CONFIG.INI
$effectiveMode = if ($Mode -eq "auto") { "auto" } else { "manual" }
$iniText = New-UnlockConfigIniText -Gpu $hwReport.PrimaryGpu -Esp $hwReport.WindowsEsp `
    -Mode $effectiveMode -CountdownSeconds $CountdownSeconds -UniversalGeneric:($Generic.IsPresent -or ($null -eq $hwReport.PrimaryGpu))
$genericText = New-UnlockConfigIniText -Gpu $null -Esp $null -Mode $effectiveMode -CountdownSeconds $CountdownSeconds -UniversalGeneric:$true

Set-Content -Path (Join-Path $TargetPrep "CONFIG.INI")         -Value $iniText     -Encoding ASCII
Set-Content -Path (Join-Path $TargetPrep "CONFIG-GENERIC.INI") -Value $genericText -Encoding ASCII

# 5. Full post-stage verification (PE headers, CONFIG.INI syntax/compatibility, and SHA-256 of all 9 assets)
Write-Host "Running post-stage integrity & SHA-256 verification on $TargetRoot ..." -ForegroundColor Cyan
if ($FolderPath) {
    $verifyRes = Test-StagedUsbIntegrity -FolderPath $FolderPath -RepoRoot $RepoRoot -HardwareReport $hwReport
} else {
    $verifyRes = Test-StagedUsbIntegrity -DriveLetter $cleanLetter -RepoRoot $RepoRoot -HardwareReport $hwReport
}
foreach ($c in $verifyRes.Checks) {
    $col = switch ($c.Status) { "PASS" { "Green" } "WARN" { "Yellow" } "FAIL" { "Red" } }
    Write-Host ("  [{0,-4}] {1,-45} {2}" -f $c.Status, $c.Item, $c.Detail) -ForegroundColor $col
}

if (-not $verifyRes.AllPassed) {
    throw "Post-stage verification failed on $TargetRoot!"
}

Write-Host "`nUSB stick at $TargetRoot is verified and ready to boot!" -ForegroundColor Green
Write-Host "1. Perform a full cold shutdown ('shutdown /s /f /t 0')." -ForegroundColor Cyan
Write-Host "2. Power on, open your BIOS Boot Menu (key varies by motherboard), and select UEFI: USB Partition 1." -ForegroundColor Cyan
