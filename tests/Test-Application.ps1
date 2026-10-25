#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'HardwareDiscovery.ps1')
Add-Type -AssemblyName System.Windows.Forms
function Assert($condition, $message) { if (-not $condition) { throw $message } }

# Real inventory/staging functions must accept the native MSFT_Volume property,
# including objects whose optional FileSystem projection is missing or empty.
foreach ($volume in @(
    [PSCustomObject]@{ FileSystemType='FAT32' },
    [PSCustomObject]@{ FileSystemType='FAT32'; FileSystem='' },
    [PSCustomObject]@{ FileSystem=' fat32 ' }
)) {
    Assert ((Get-VolumeFileSystemName $volume) -eq 'FAT32') 'FAT32 volume property normalization failed'
}
Assert ((Get-VolumeFileSystemName ([PSCustomObject]@{ FileSystemType='NTFS' })) -eq 'NTFS') 'NTFS incorrectly accepted'
Assert ((Get-VolumeFileSystemName ([PSCustomObject]@{})) -eq 'UNKNOWN') 'Missing filesystem must remain unknown'
$nativeQuery = ${function:Get-NativeVolumeFileSystem}
function Get-NativeVolumeFileSystem { param($DriveLetter) 'FAT32' }
Assert ((Get-VolumeFileSystemName ([PSCustomObject]@{ DriveLetter='E'; FileSystemType='Unknown'; FileSystem='' })) -eq 'FAT32') 'Direct Windows filesystem fallback failed'
Set-Item Function:Get-NativeVolumeFileSystem $nativeQuery
function Get-Volume { param($DriveLetter) $script:testVolume }
function Get-Partition { param($DriveLetter) [PSCustomObject]@{ DiskNumber=9 } }
function Get-Disk { param($Number) [PSCustomObject]@{ Number=9; IsBoot=$false; IsSystem=$false; BusType='USB'; PartitionStyle='GPT'; FriendlyName='Fixture USB' } }
$script:testVolume = [PSCustomObject]@{
    DriveLetter='E'; FileSystemType='FAT32'; FileSystem=''; DriveType='Removable'
    Size=2GB; SizeRemaining=1GB; FileSystemLabel='Fixture'
}
$inventory = @(Get-UsbDriveInventory)
Assert ($inventory.Count -eq 1 -and $inventory[0].FileSystem -eq 'FAT32' -and $inventory[0].ReadyToStage) 'Native FAT32 volume not ready in inventory'
Assert-StagingTarget -DriveLetter E -RepoRoot $root
$script:testVolume.FileSystemType = 'NTFS'
$rejected = $false
try { Assert-StagingTarget -DriveLetter E -RepoRoot $root } catch { $rejected = $true }
Assert $rejected 'NTFS staging was accepted'
Remove-Item Function:Get-Volume, Function:Get-Partition, Function:Get-Disk
Write-Host 'PASS: native FileSystemType, legacy FileSystem, FAT32 inventory and staging guards'

# Load the actual GUI refresh function without running hardware discovery or showing a window.
$tokens = $null; $parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'UsbCreatorGui.ps1'), [ref]$tokens, [ref]$parseErrors)
Assert ($parseErrors.Count -eq 0) 'GUI syntax error'
$fn = $ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Refresh-UsbDriveList'}, $true)
Invoke-Expression $fn.Extent.Text
$cmbUsbDrive = New-Object Windows.Forms.ComboBox
$chkAllDrives = New-Object Windows.Forms.CheckBox
function Get-UsbDriveInventory { param([switch]$IncludeNonRemovable) $script:fakeDrives }
foreach ($count in 0,1,3) {
    $script:fakeDrives = @(for ($i=0; $i -lt $count; $i++) { [PSCustomObject]@{ DisplayText="Drive $i FAT32"; ReadyToStage=($i -eq $count-1) } })
    Refresh-UsbDriveList
    Assert ($cmbUsbDrive.Items.Count -eq [Math]::Max(1,$count)) "USB item count failed for $count drives"
    Assert ($cmbUsbDrive.SelectedIndex -eq [Math]::Max(0,$count-1)) "USB selection failed for $count drives"
    Assert ($script:UsbDrives.Count -eq $count) "USB array normalization failed for $count drives"
}
$cmbUsbDrive.Dispose(); $chkAllDrives.Dispose()
Write-Host 'PASS: GUI refresh with zero, one FAT32 and multiple drives'

$efi = [IO.File]::ReadAllBytes((Join-Path $root 'usb-package/EFI/BOOT/BOOTX64.EFI'))
Assert (Test-EfiApplicationBytes $efi) 'Valid EFI rejected'
$fake = New-Object byte[] 1024; $fake[0]=0x4d; $fake[1]=0x5a
Assert (-not (Test-EfiApplicationBytes $fake)) 'MZ-only file accepted as EFI'
$efi[60]=255; $efi[61]=255; $efi[62]=255; $efi[63]=127
Assert (-not (Test-EfiApplicationBytes $efi)) 'Invalid PE offset accepted'
Write-Host 'PASS: EFI validation rejects malformed files'

foreach ($folder in $root, (Join-Path $root 'usb-package'), (Join-Path $root 'usb-package/nested')) {
    $rejected=$false
    try { Assert-StagingTarget -FolderPath $folder -RepoRoot $root } catch { $rejected=$true }
    Assert $rejected "Unsafe staging folder accepted: $folder"
}
Assert-StagingTarget -FolderPath (Join-Path $root 'build/test-staging') -RepoRoot $root
Write-Host 'PASS: staging destination checks'

# Cross-check C and PowerShell catalogs so recognition cannot silently diverge.
$catalog = Get-SupportedGpuCatalog
$cText = Get-Content (Join-Path $root 'src/unlock/gpu_catalog.h') -Raw
$cIds = @([regex]::Matches($cText,'\{\s*0x([0-9a-fA-F]{4})U,\s*GU_ARCH_') | ForEach-Object { $_.Groups[1].Value.ToUpper() })
Assert ($cIds.Count -eq $catalog.Count) 'GPU catalog counts differ'
foreach ($id in $cIds) { Assert ($catalog.ContainsKey($id)) "PowerShell missing C GPU ID $id" }
$cfg = New-UnlockConfigIniText -Gpu $null -Esp $null -UniversalGeneric $true
$res = Test-ConfigIniCompatibility -IniText $cfg
Assert $res.IsValid 'Generic INI rejected'
$pkg = Test-StagedUsbIntegrity -FolderPath (Join-Path $root 'usb-package') -RepoRoot $root
Assert $pkg.AllPassed ('Package integrity failed: ' + ($pkg.Checks | Where-Object Status -eq FAIL | Out-String))
Write-Host 'PASS: catalogs, generic profile, package structure and firmware hashes'

# Exercise subprocess exit handling, report output and decimal parsing on de-DE.
$fixtureRoot = Join-Path $root 'build/application-fixture'
$fixtureBench = Join-Path $fixtureRoot 'benchmark'
$null = New-Item -ItemType Directory -Force $fixtureBench
$zig = if ($env:ZIG_EXE) { $env:ZIG_EXE } else { Join-Path $root 'tools/zig-x86_64-windows-0.14.1/zig.exe' }
$env:ZIG_GLOBAL_CACHE_DIR = Join-Path $root 'build/zig-global-cache'
$env:ZIG_LOCAL_CACHE_DIR = Join-Path $root 'build/zig-local-cache'
& $zig cc (Join-Path $PSScriptRoot 'benchmark_stub.c') -o (Join-Path $fixtureBench 'mma_bench.exe')
Assert ($LASTEXITCODE -eq 0) 'Failed to compile benchmark fixture'
Copy-Item (Join-Path $fixtureBench 'mma_bench.exe') (Join-Path $fixtureBench 'validate_gemm.exe') -Force
$oldCulture = [Threading.Thread]::CurrentThread.CurrentCulture
try {
    [Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo('de-DE')
    $result = Get-GpuLiveUnlockStatus -RepoRoot $fixtureRoot -RunValidation -SaveReport
    Assert ($result.ValidationPass -and $result.F16F32Tflops -eq 90) 'Valid benchmark failed under de-DE'
    $text = Get-Content $result.ReportFilePath -Raw
    Assert ($text.Contains('90.0 TFLOPS')) 'Report rates must use invariant decimal TFLOPS'
    $env:GU_TEST_VALIDATION_FAIL = '1'
    $result = Get-GpuLiveUnlockStatus -RepoRoot $fixtureRoot -RunValidation
    Assert (-not $result.ValidationPass -and -not $result.IsUnlocked -and $result.State -eq 'ERROR') 'Failed validation accepted'
    $env:GU_TEST_VALIDATION_FAIL = $null
    $env:GU_TEST_INCOMPLETE = '1'
    $result = Get-GpuLiveUnlockStatus -RepoRoot $fixtureRoot
    Assert ($result.State -eq 'ERROR' -and -not $result.IsUnlocked) 'Incomplete metrics accepted'
    $env:GU_TEST_INCOMPLETE = $null
    $env:GU_TEST_BENCH_FAIL = '1'
    $result = Get-GpuLiveUnlockStatus -RepoRoot $fixtureRoot
    Assert (-not $result.Available -and -not $result.IsUnlocked) 'Nonzero benchmark exit accepted'
} finally {
    [Threading.Thread]::CurrentThread.CurrentCulture = $oldCulture
    $env:GU_TEST_VALIDATION_FAIL = $null
    $env:GU_TEST_INCOMPLETE = $null
    $env:GU_TEST_BENCH_FAIL = $null
}
Write-Host 'PASS: benchmark subprocess errors, validation, reports and de-DE parsing'

# Every PowerShell entry point must parse on Windows PowerShell 5.1.
foreach ($file in Get-ChildItem $root -Recurse -Filter *.ps1 | Where-Object FullName -notmatch '\\(tools|reference_repos|local)\\') {
    $errors=$null; $tokens=$null
    $null=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    Assert ($errors.Count -eq 0) "Syntax errors: $($file.FullName): $errors"
}
Write-Host 'All application regression checks passed.'
