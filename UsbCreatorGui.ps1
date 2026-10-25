#Requires -Version 5.1
<#
.SYNOPSIS
    Windows GUI USB Stick Creator & Hardware Diagnostic Tool for the
    NVIDIA GeForce RTX 3000 Series (Ampere GA10x) & RTX 4000 Series (Ada AD10x) UEFI Unlocker.
.PARAMETER SelfTest
    Initializes the GUI form, runs all hardware discovery, profile generation, CONFIG.INI validation,
    and usb-package integrity checks, then exits cleanly with code 0 for automated verification.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$SelfTest
)

$ErrorActionPreference = "Stop"
$RepoRoot = $PSScriptRoot
. (Join-Path $RepoRoot "HardwareDiscovery.ps1")

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Color Palette (Modern Dark Diagnostic Theme)
$BgDark       = [System.Drawing.Color]::FromArgb(20, 23, 31)
$BgPanel      = [System.Drawing.Color]::FromArgb(29, 34, 46)
$BgInput      = [System.Drawing.Color]::FromArgb(16, 19, 27)
$FgPrimary    = [System.Drawing.Color]::FromArgb(235, 240, 248)
$FgMuted      = [System.Drawing.Color]::FromArgb(160, 172, 192)
$AccentGreen  = [System.Drawing.Color]::FromArgb(118, 185, 0)   # NVIDIA Green
$AccentBlue   = [System.Drawing.Color]::FromArgb(56, 139, 253)
$AccentAmber  = [System.Drawing.Color]::FromArgb(210, 153, 34)
$AccentRed    = [System.Drawing.Color]::FromArgb(248, 81, 73)

$FontHeader   = New-Object System.Drawing.Font("Segoe UI Semibold", 13)
$FontSub      = New-Object System.Drawing.Font("Segoe UI", 9.5)
$FontBold     = New-Object System.Drawing.Font("Segoe UI Semibold", 9.5)
$FontRegular  = New-Object System.Drawing.Font("Segoe UI", 9)
$FontMono     = New-Object System.Drawing.Font("Consolas", 9.25)

$script:HwReport = $null
$script:Catalog  = Get-SupportedGpuCatalog
$script:UpdatingControls = $false

# Main Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "NVIDIA RTX 3000 (GA10x) & RTX 4000 (AD10x) UEFI Unlocker - USB Stick Creator & Diagnostic Suite"
$form.Size = New-Object System.Drawing.Size(1340, 900)
$form.MinimumSize = New-Object System.Drawing.Size(1200, 820)
$form.StartPosition = "CenterScreen"
$form.BackColor = $BgDark
$form.ForeColor = $FgPrimary
$form.Font = $FontRegular

# Top Banner Panel
$bannerPanel = New-Object System.Windows.Forms.Panel
$bannerPanel.Dock = "Top"
$bannerPanel.Height = 68
$bannerPanel.BackColor = [System.Drawing.Color]::FromArgb(14, 17, 23)
$form.Controls.Add($bannerPanel)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "NVIDIA GeForce RTX 3000 (Ampere) & RTX 4000 (Ada) Pre-Boot UEFI Unlocker"
$lblTitle.Font = $FontHeader
$lblTitle.ForeColor = $AccentGreen
$lblTitle.Location = New-Object System.Drawing.Point(16, 10)
$lblTitle.AutoSize = $true
$bannerPanel.Controls.Add($lblTitle)

$lblSubtitle = New-Object System.Windows.Forms.Label
$lblSubtitle.Text = "Scanning system hardware, PCIe apertures, UEFI Secure Boot, Windows ESP, and NVIDIA 610.43.03 firmware package..."
$lblSubtitle.Font = $FontSub
$lblSubtitle.ForeColor = $FgMuted
$lblSubtitle.Location = New-Object System.Drawing.Point(18, 38)
$lblSubtitle.AutoSize = $true
$bannerPanel.Controls.Add($lblSubtitle)

$lblLockBadge = New-Object System.Windows.Forms.Label
$lblLockBadge.Text = "PROBING GPU STATE..."
$lblLockBadge.Font = $FontBold
$lblLockBadge.ForeColor = [System.Drawing.Color]::White
$lblLockBadge.BackColor = [System.Drawing.Color]::FromArgb(70, 80, 100)
$lblLockBadge.TextAlign = "MiddleCenter"
$lblLockBadge.Size = New-Object System.Drawing.Size(225, 36)
$lblLockBadge.Location = New-Object System.Drawing.Point(885, 16)
$lblLockBadge.Anchor = "Top, Right"
$bannerPanel.Controls.Add($lblLockBadge)

$lblBadge = New-Object System.Windows.Forms.Label
$lblBadge.Text = "SCANNING"
$lblBadge.Font = $FontBold
$lblBadge.ForeColor = [System.Drawing.Color]::White
$lblBadge.BackColor = $AccentBlue
$lblBadge.TextAlign = "MiddleCenter"
$lblBadge.Size = New-Object System.Drawing.Size(190, 36)
$lblBadge.Location = New-Object System.Drawing.Point(1120, 16)
$lblBadge.Anchor = "Top, Right"
$bannerPanel.Controls.Add($lblBadge)

# Main Content Container
$mainSplit = New-Object System.Windows.Forms.TableLayoutPanel
$mainSplit.Dock = "Fill"
$mainSplit.ColumnCount = 2
$mainSplit.RowCount = 2
$mainSplit.Padding = New-Object System.Windows.Forms.Padding(10)
$mainSplit.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 52))) | Out-Null
$mainSplit.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 48))) | Out-Null
$mainSplit.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 60))) | Out-Null
$mainSplit.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 40))) | Out-Null
$form.Controls.Add($mainSplit)
$mainSplit.BringToFront()

# ==============================================================================
# 1. TOP-LEFT PANEL: Hardware Discovery & Compatibility Checks
# ==============================================================================
$grpHw = New-Object System.Windows.Forms.GroupBox
$grpHw.Text = " 1. Discovered Hardware & Pre-Boot Readiness Checks "
$grpHw.Dock = "Fill"
$grpHw.ForeColor = $AccentGreen
$grpHw.BackColor = $BgPanel
$grpHw.Font = $FontBold
$grpHw.Margin = New-Object System.Windows.Forms.Padding(4)
$mainSplit.Controls.Add($grpHw, 0, 0)

$lblGpus = New-Object System.Windows.Forms.Label
$lblGpus.Text = "Discovered Display Adapters (PCIe Bus / Device / BAR0 / Architecture):"
$lblGpus.ForeColor = $FgPrimary
$lblGpus.Font = $FontRegular
$lblGpus.Location = New-Object System.Drawing.Point(12, 24)
$lblGpus.AutoSize = $true
$grpHw.Controls.Add($lblGpus)

$lstGpus = New-Object System.Windows.Forms.ListBox
$lstGpus.Location = New-Object System.Drawing.Point(12, 45)
$lstGpus.Size = New-Object System.Drawing.Size(640, 62)
$lstGpus.Anchor = "Top, Left, Right"
$lstGpus.BackColor = $BgInput
$lstGpus.ForeColor = $FgPrimary
$lstGpus.Font = $FontMono
$lstGpus.HorizontalScrollbar = $true
$grpHw.Controls.Add($lstGpus)

$lblLiveBench = New-Object System.Windows.Forms.Label
$lblLiveBench.Text = "Live Tensor Core Status: Probing..."
$lblLiveBench.Location = New-Object System.Drawing.Point(12, 111)
$lblLiveBench.Size = New-Object System.Drawing.Size(640, 38)
$lblLiveBench.Anchor = "Top, Left, Right"
$lblLiveBench.BackColor = [System.Drawing.Color]::FromArgb(20, 26, 38)
$lblLiveBench.ForeColor = $FgPrimary
$lblLiveBench.Font = $FontMono
$lblLiveBench.BorderStyle = "FixedSingle"
$lblLiveBench.Padding = New-Object System.Windows.Forms.Padding(6, 3, 6, 3)
$grpHw.Controls.Add($lblLiveBench)

$lblChecks = New-Object System.Windows.Forms.Label
$lblChecks.Text = "Automated Pre-Boot Compatibility & Firmware Asset Checks:"
$lblChecks.ForeColor = $FgPrimary
$lblChecks.Font = $FontRegular
$lblChecks.Location = New-Object System.Drawing.Point(12, 153)
$lblChecks.AutoSize = $true
$grpHw.Controls.Add($lblChecks)

$gridChecks = New-Object System.Windows.Forms.DataGridView
$gridChecks.Location = New-Object System.Drawing.Point(12, 173)
$gridChecks.Size = New-Object System.Drawing.Size(640, 219)
$gridChecks.Anchor = "Top, Bottom, Left, Right"
$gridChecks.BackgroundColor = $BgInput
$gridChecks.ForeColor = $FgPrimary
$gridChecks.GridColor = [System.Drawing.Color]::FromArgb(45, 52, 68)
$gridChecks.BorderStyle = "FixedSingle"
$gridChecks.AllowUserToAddRows = $false
$gridChecks.AllowUserToDeleteRows = $false
$gridChecks.AllowUserToResizeRows = $false
$gridChecks.ReadOnly = $true
$gridChecks.RowHeadersVisible = $false
$gridChecks.SelectionMode = "FullRowSelect"
$gridChecks.AutoSizeColumnsMode = "Fill"
$gridChecks.EnableHeadersVisualStyles = $false
$gridChecks.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(36, 42, 56)
$gridChecks.ColumnHeadersDefaultCellStyle.ForeColor = $FgPrimary
$gridChecks.ColumnHeadersDefaultCellStyle.Font = $FontBold
$gridChecks.DefaultCellStyle.BackColor = $BgInput
$gridChecks.DefaultCellStyle.ForeColor = $FgPrimary
$gridChecks.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(40, 56, 82)
$gridChecks.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
$gridChecks.DefaultCellStyle.Font = $FontRegular

$colStatus = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colStatus.Name = "Status"; $colStatus.HeaderText = "Status"; $colStatus.FillWeight = 13
$colItem   = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colItem.Name   = "Item";   $colItem.HeaderText   = "Check Item"; $colItem.FillWeight = 32
$colValue  = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colValue.Name  = "Value";  $colValue.HeaderText  = "Discovered Value / Notes"; $colValue.FillWeight = 55
[void]$gridChecks.Columns.Add($colStatus)
[void]$gridChecks.Columns.Add($colItem)
[void]$gridChecks.Columns.Add($colValue)
$grpHw.Controls.Add($gridChecks)

$pnlHwBtns = New-Object System.Windows.Forms.FlowLayoutPanel
$pnlHwBtns.Location = New-Object System.Drawing.Point(12, 398)
$pnlHwBtns.Size = New-Object System.Drawing.Size(640, 38)
$pnlHwBtns.Anchor = "Bottom, Left, Right"
$pnlHwBtns.BackColor = $BgPanel
$grpHw.Controls.Add($pnlHwBtns)

function New-StyledButton([string]$Text, [int]$Width, [System.Drawing.Color]$BgColor) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Size = New-Object System.Drawing.Size($Width, 32)
    $b.FlatStyle = "Flat"
    $b.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(70, 80, 100)
    $b.BackColor = $BgColor
    $b.ForeColor = [System.Drawing.Color]::White
    $b.Font = $FontBold
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    return $b
}

$btnRescan        = New-StyledButton "Rescan & Probe (<1s)" 155 $AccentBlue
$btnBenchBaseline = New-StyledButton "Benchmark (Save 'Before')" 180 ([System.Drawing.Color]::FromArgb(145, 95, 20))
$btnBench         = New-StyledButton "Benchmark & Compare ('After')" 195 ([System.Drawing.Color]::FromArgb(45, 115, 60))
$btnRebuild       = New-StyledButton "Rebuild .EFI" 95 ([System.Drawing.Color]::FromArgb(52, 62, 82))
$pnlHwBtns.Controls.AddRange(@($btnRescan, $btnBenchBaseline, $btnBench, $btnRebuild))

# ==============================================================================
# 2. TOP-RIGHT PANEL: Profile & CONFIG.INI Builder + Validator
# ==============================================================================
$grpCfg = New-Object System.Windows.Forms.GroupBox
$grpCfg.Text = " 2. Target GPU Profile & \RTX4090-PREP\CONFIG.INI Builder "
$grpCfg.Dock = "Fill"
$grpCfg.ForeColor = $AccentGreen
$grpCfg.BackColor = $BgPanel
$grpCfg.Font = $FontBold
$grpCfg.Margin = New-Object System.Windows.Forms.Padding(4)
$mainSplit.Controls.Add($grpCfg, 1, 0)

$lblProfileMode = New-Object System.Windows.Forms.Label
$lblProfileMode.Text = "Target Hardware Profile:"
$lblProfileMode.ForeColor = $FgPrimary
$lblProfileMode.Font = $FontRegular
$lblProfileMode.Location = New-Object System.Drawing.Point(12, 26)
$lblProfileMode.AutoSize = $true
$grpCfg.Controls.Add($lblProfileMode)

$cmbProfileType = New-Object System.Windows.Forms.ComboBox
$cmbProfileType.Location = New-Object System.Drawing.Point(165, 22)
$cmbProfileType.Size = New-Object System.Drawing.Size(425, 26)
$cmbProfileType.Anchor = "Top, Left, Right"
$cmbProfileType.DropDownStyle = "DropDownList"
$cmbProfileType.BackColor = $BgInput
$cmbProfileType.ForeColor = $FgPrimary
$cmbProfileType.Font = $FontRegular
[void]$cmbProfileType.Items.Add("Tailored for Detected Local GPU & Motherboard (Recommended for this PC)")
[void]$cmbProfileType.Items.Add("Generic discovery (RTX 3000 / 4000; unlock compatibility is experimental)")
[void]$cmbProfileType.Items.Add("Tailored for Specific GPU Model from RTX 3000 / 4000 Catalog...")
$cmbProfileType.SelectedIndex = 0
$grpCfg.Controls.Add($cmbProfileType)

$lblCatalogGpu = New-Object System.Windows.Forms.Label
$lblCatalogGpu.Text = "Catalog GPU Model:"
$lblCatalogGpu.ForeColor = $FgPrimary
$lblCatalogGpu.Font = $FontRegular
$lblCatalogGpu.Location = New-Object System.Drawing.Point(12, 56)
$lblCatalogGpu.AutoSize = $true
$grpCfg.Controls.Add($lblCatalogGpu)

$cmbCatalogGpu = New-Object System.Windows.Forms.ComboBox
$cmbCatalogGpu.Location = New-Object System.Drawing.Point(165, 52)
$cmbCatalogGpu.Size = New-Object System.Drawing.Size(425, 26)
$cmbCatalogGpu.Anchor = "Top, Left, Right"
$cmbCatalogGpu.DropDownStyle = "DropDownList"
$cmbCatalogGpu.BackColor = $BgInput
$cmbCatalogGpu.ForeColor = $FgPrimary
$cmbCatalogGpu.Font = $FontMono
$cmbCatalogGpu.Enabled = $false

$script:CatalogItems = New-Object System.Collections.Generic.List[object]
foreach ($k in ($script:Catalog.Keys | Sort-Object { $script:Catalog[$_].Arch }, { $script:Catalog[$_].Name })) {
    $entry = $script:Catalog[$k]
    $boardHex = "0x{0}10de" -f $k.ToLower()
    $chipHex  = "0x{0:x8}" -f $entry.DefaultChipId
    $obj = [PSCustomObject]@{
        DevId        = $k
        Name         = $entry.Name
        ChipFamily   = $entry.Chip
        Arch         = $entry.Arch
        Series       = $entry.Series
        BoardIdHex   = $boardHex
        ChipIdHex    = $chipHex
        Display      = "[{0,-6} | {1}] {2} (PCI 10DE:{3})" -f $entry.Arch.ToUpper(), $entry.Chip, $entry.Name, $k
    }
    $script:CatalogItems.Add($obj)
    [void]$cmbCatalogGpu.Items.Add($obj.Display)
}
if ($cmbCatalogGpu.Items.Count -gt 0) { $cmbCatalogGpu.SelectedIndex = 0 }
$grpCfg.Controls.Add($cmbCatalogGpu)

$lblBootMode = New-Object System.Windows.Forms.Label
$lblBootMode.Text = "UEFI Boot Mode:"
$lblBootMode.ForeColor = $FgPrimary
$lblBootMode.Font = $FontRegular
$lblBootMode.Location = New-Object System.Drawing.Point(12, 86)
$lblBootMode.AutoSize = $true
$grpCfg.Controls.Add($lblBootMode)

$cmbBootMode = New-Object System.Windows.Forms.ComboBox
$cmbBootMode.Location = New-Object System.Drawing.Point(165, 82)
$cmbBootMode.Size = New-Object System.Drawing.Size(295, 26)
$cmbBootMode.DropDownStyle = "DropDownList"
$cmbBootMode.BackColor = $BgInput
$cmbBootMode.ForeColor = $FgPrimary
$cmbBootMode.Font = $FontRegular
[void]$cmbBootMode.Items.Add("manual - Interactive [U] Unlock / [S] Skip")
[void]$cmbBootMode.Items.Add("auto   - Countdown then Unlock & Boot Windows")
[void]$cmbBootMode.Items.Add("probe  - Read-Only Hardware Diagnostics Probe")
$cmbBootMode.SelectedIndex = 0
$grpCfg.Controls.Add($cmbBootMode)

$lblCountdown = New-Object System.Windows.Forms.Label
$lblCountdown.Text = "Wait (s):"
$lblCountdown.ForeColor = $FgPrimary
$lblCountdown.Font = $FontRegular
$lblCountdown.Location = New-Object System.Drawing.Point(468, 86)
$lblCountdown.AutoSize = $true
$grpCfg.Controls.Add($lblCountdown)

$numCountdown = New-Object System.Windows.Forms.NumericUpDown
$numCountdown.Location = New-Object System.Drawing.Point(530, 82)
$numCountdown.Size = New-Object System.Drawing.Size(60, 26)
$numCountdown.Minimum = 1
$numCountdown.Maximum = 60
$numCountdown.Value = 5
$numCountdown.BackColor = $BgInput
$numCountdown.ForeColor = $FgPrimary
$numCountdown.Font = $FontRegular
$grpCfg.Controls.Add($numCountdown)

# Safety Checkboxes Panel
$pnlChecks = New-Object System.Windows.Forms.FlowLayoutPanel
$pnlChecks.Location = New-Object System.Drawing.Point(12, 114)
$pnlChecks.Size = New-Object System.Drawing.Size(580, 56)
$pnlChecks.Anchor = "Top, Left, Right"
$pnlChecks.BackColor = $BgPanel
$grpCfg.Controls.Add($pnlChecks)

function New-CfgCheck([string]$Text, [bool]$Checked) {
    $c = New-Object System.Windows.Forms.CheckBox
    $c.Text = $Text
    $c.Checked = $Checked
    $c.AutoSize = $true
    $c.ForeColor = $FgPrimary
    $c.Font = $FontRegular
    $c.Margin = New-Object System.Windows.Forms.Padding(4, 2, 10, 2)
    return $c
}

$chkStrictBoard  = New-CfgCheck "Strict Board ID" $true
$chkStrictSubsys = New-CfgCheck "Strict Subsystem" $true
$chkStrictChip   = New-CfgCheck "Strict Chip ID" $false
$chkStrictBdf    = New-CfgCheck "Strict BDF" $false
$chkStrictBar0   = New-CfgCheck "Strict BAR0" $false
$chkStrictEsp    = New-CfgCheck "Strict ESP GUID" $false
$chkHeadless     = New-CfgCheck "Headless Fallback" $true
$chkPromDump     = New-CfgCheck "Save PROM Dump" $true
$pnlChecks.Controls.AddRange(@($chkStrictBoard, $chkStrictSubsys, $chkStrictChip, $chkStrictBdf, $chkStrictBar0, $chkStrictEsp, $chkHeadless, $chkPromDump))

$lblIniPreview = New-Object System.Windows.Forms.Label
$lblIniPreview.Text = "Live \RTX4090-PREP\CONFIG.INI Preview (Editable):"
$lblIniPreview.ForeColor = $FgPrimary
$lblIniPreview.Font = $FontRegular
$lblIniPreview.Location = New-Object System.Drawing.Point(12, 173)
$lblIniPreview.AutoSize = $true
$grpCfg.Controls.Add($lblIniPreview)

$txtConfigIni = New-Object System.Windows.Forms.TextBox
$txtConfigIni.Location = New-Object System.Drawing.Point(12, 193)
$txtConfigIni.Size = New-Object System.Drawing.Size(580, 198)
$txtConfigIni.Anchor = "Top, Bottom, Left, Right"
$txtConfigIni.Multiline = $true
$txtConfigIni.ScrollBars = "Both"
$txtConfigIni.WordWrap = $false
$txtConfigIni.AcceptsReturn = $true
$txtConfigIni.BackColor = $BgInput
$txtConfigIni.ForeColor = [System.Drawing.Color]::FromArgb(190, 235, 165)
$txtConfigIni.Font = $FontMono
$grpCfg.Controls.Add($txtConfigIni)

$pnlCfgBtns = New-Object System.Windows.Forms.FlowLayoutPanel
$pnlCfgBtns.Location = New-Object System.Drawing.Point(12, 398)
$pnlCfgBtns.Size = New-Object System.Drawing.Size(580, 38)
$pnlCfgBtns.Anchor = "Bottom, Left, Right"
$pnlCfgBtns.BackColor = $BgPanel
$grpCfg.Controls.Add($pnlCfgBtns)

$btnRegenIni    = New-StyledButton "Reset INI from Controls" 175 ([System.Drawing.Color]::FromArgb(52, 62, 82))
$btnValidateIni = New-StyledButton "Validate CONFIG.INI" 165 $AccentBlue
$btnSavePkgIni  = New-StyledButton "Save to usb-package" 170 ([System.Drawing.Color]::FromArgb(45, 110, 65))
$pnlCfgBtns.Controls.AddRange(@($btnRegenIni, $btnValidateIni, $btnSavePkgIni))

# ==============================================================================
# 3. BOTTOM PANEL: USB Stick Creator, Verifier & Live Diagnostic Log
# ==============================================================================
$grpUsb = New-Object System.Windows.Forms.GroupBox
$grpUsb.Text = " 3. USB UEFI Boot Stick Creator, Integrity Verifier & Diagnostic Console "
$grpUsb.Dock = "Fill"
$grpUsb.ForeColor = $AccentGreen
$grpUsb.BackColor = $BgPanel
$grpUsb.Font = $FontBold
$grpUsb.Margin = New-Object System.Windows.Forms.Padding(4)
$mainSplit.SetColumnSpan($grpUsb, 2)
$mainSplit.Controls.Add($grpUsb, 0, 1)

$lblUsbDrive = New-Object System.Windows.Forms.Label
$lblUsbDrive.Text = "Target FAT32 USB Drive:"
$lblUsbDrive.ForeColor = $FgPrimary
$lblUsbDrive.Font = $FontBold
$lblUsbDrive.Location = New-Object System.Drawing.Point(14, 28)
$lblUsbDrive.AutoSize = $true
$grpUsb.Controls.Add($lblUsbDrive)

$cmbUsbDrive = New-Object System.Windows.Forms.ComboBox
$cmbUsbDrive.Location = New-Object System.Drawing.Point(180, 24)
$cmbUsbDrive.Size = New-Object System.Drawing.Size(590, 26)
$cmbUsbDrive.Anchor = "Top, Left, Right"
$cmbUsbDrive.DropDownStyle = "DropDownList"
$cmbUsbDrive.BackColor = $BgInput
$cmbUsbDrive.ForeColor = $FgPrimary
$cmbUsbDrive.Font = $FontMono
$grpUsb.Controls.Add($cmbUsbDrive)

$btnRefreshUsb = New-StyledButton "Refresh USB" 115 ([System.Drawing.Color]::FromArgb(52, 62, 82))
$btnRefreshUsb.Location = New-Object System.Drawing.Point(780, 21)
$btnRefreshUsb.Anchor = "Top, Right"
$grpUsb.Controls.Add($btnRefreshUsb)

$chkAllDrives = New-Object System.Windows.Forms.CheckBox
$chkAllDrives.Text = "Include non-USB data drives"
$chkAllDrives.ForeColor = $FgMuted
$chkAllDrives.Font = $FontRegular
$chkAllDrives.AutoSize = $true
$chkAllDrives.Location = New-Object System.Drawing.Point(905, 27)
$chkAllDrives.Anchor = "Top, Right"
$grpUsb.Controls.Add($chkAllDrives)

$btnCreateUsb = New-StyledButton "Create / Update Unlock USB Stick" 260 ([System.Drawing.Color]::FromArgb(88, 145, 0))
$btnCreateUsb.Location = New-Object System.Drawing.Point(14, 60)
$grpUsb.Controls.Add($btnCreateUsb)

$btnVerifyUsb = New-StyledButton "Verify Existing USB Stick" 205 $AccentBlue
$btnVerifyUsb.Location = New-Object System.Drawing.Point(284, 60)
$grpUsb.Controls.Add($btnVerifyUsb)

$btnVerifyPkg = New-StyledButton "Verify Local usb-package\" 205 ([System.Drawing.Color]::FromArgb(52, 62, 82))
$btnVerifyPkg.Location = New-Object System.Drawing.Point(499, 60)
$grpUsb.Controls.Add($btnVerifyPkg)

$btnExportFolder = New-StyledButton "Stage to Local Folder..." 195 ([System.Drawing.Color]::FromArgb(52, 62, 82))
$btnExportFolder.Location = New-Object System.Drawing.Point(714, 60)
$grpUsb.Controls.Add($btnExportFolder)

$btnCopyShutdown = New-StyledButton "Copy Cold Shutdown Cmd" 200 ([System.Drawing.Color]::FromArgb(120, 82, 20))
$btnCopyShutdown.Location = New-Object System.Drawing.Point(919, 60)
$grpUsb.Controls.Add($btnCopyShutdown)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(14, 98)
$progressBar.Size = New-Object System.Drawing.Size(1270, 12)
$progressBar.Anchor = "Top, Left, Right"
$progressBar.Style = "Continuous"
$grpUsb.Controls.Add($progressBar)

$rtbLog = New-Object System.Windows.Forms.RichTextBox
$rtbLog.Location = New-Object System.Drawing.Point(14, 116)
$rtbLog.Size = New-Object System.Drawing.Size(1270, 185)
$rtbLog.Anchor = "Top, Bottom, Left, Right"
$rtbLog.BackColor = $BgInput
$rtbLog.ForeColor = $FgPrimary
$rtbLog.Font = $FontMono
$rtbLog.ReadOnly = $true
$rtbLog.WordWrap = $false
$grpUsb.Controls.Add($rtbLog)

# ==============================================================================
# Helper Functions & Event Logic
# ==============================================================================
function Write-GuiLog {
    param(
        [string]$Message,
        [ValidateSet("INFO", "PASS", "WARN", "FAIL", "HEAD")]
        [string]$Level = "INFO"
    )
    $ts = (Get-Date).ToString("HH:mm:ss")
    $color = switch ($Level) {
        "PASS" { [System.Drawing.Color]::FromArgb(125, 225, 110) }
        "WARN" { [System.Drawing.Color]::FromArgb(245, 195, 80) }
        "FAIL" { [System.Drawing.Color]::FromArgb(255, 105, 95) }
        "HEAD" { [System.Drawing.Color]::FromArgb(110, 195, 255) }
        default { $FgPrimary }
    }
    $rtbLog.SelectionStart = $rtbLog.TextLength
    $rtbLog.SelectionLength = 0
    $rtbLog.SelectionColor = $color
    $rtbLog.AppendText("[$ts] [$Level] $Message`r`n")
    $rtbLog.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Update-ConfigPreviewFromControls {
    if ($script:UpdatingControls) { return }
    $modeIdx = $cmbBootMode.SelectedIndex
    $effMode = if ($modeIdx -eq 1) { "auto" } else { "manual" }
    $cdSec   = [int]$numCountdown.Value
    $profIdx = $cmbProfileType.SelectedIndex

    $espObj = if ($script:HwReport) { $script:HwReport.WindowsEsp } else { $null }

    if ($profIdx -eq 1) {
        # Universal Generic
        $ini = New-UnlockConfigIniText -Gpu $null -Esp $espObj -Mode $effMode -CountdownSeconds $cdSec `
            -UniversalGeneric:$true `
            -StrictBoard:$chkStrictBoard.Checked `
            -StrictSubsystem:$chkStrictSubsys.Checked `
            -StrictChip:$chkStrictChip.Checked `
            -StrictBdf:$chkStrictBdf.Checked `
            -StrictBar0:$chkStrictBar0.Checked `
            -StrictEsp:$chkStrictEsp.Checked `
            -AllowHeadlessHandoff:$chkHeadless.Checked `
            -SavePromDump:$chkPromDump.Checked
        $txtConfigIni.Text = ($ini -replace "`r?`n", "`r`n")
    } elseif ($profIdx -eq 2 -and $cmbCatalogGpu.SelectedIndex -ge 0) {
        # Catalog GPU selection
        $catItem = $script:CatalogItems[$cmbCatalogGpu.SelectedIndex]
        $synthGpu = [PSCustomObject]@{
            Name           = $catItem.Name
            ChipFamily     = $catItem.ChipFamily
            Arch           = $catItem.Arch
            BoardIdHex     = $catItem.BoardIdHex
            SubsystemIdHex = "any"
            ChipIdHex      = $catItem.ChipIdHex
            Segment        = 0
            Bus            = 1
            Device         = 0
            Function       = 0
            Bar0Base       = 0
            Bar0BaseHex    = "any"
        }
        $ini = New-UnlockConfigIniText -Gpu $synthGpu -Esp $null -Mode $effMode -CountdownSeconds $cdSec `
            -UniversalGeneric:$false `
            -StrictBoard:$chkStrictBoard.Checked `
            -StrictSubsystem:$false `
            -StrictChip:$chkStrictChip.Checked `
            -StrictBdf:$chkStrictBdf.Checked `
            -StrictBar0:$chkStrictBar0.Checked `
            -StrictEsp:$chkStrictEsp.Checked `
            -AllowHeadlessHandoff:$chkHeadless.Checked `
            -SavePromDump:$chkPromDump.Checked
        $txtConfigIni.Text = ($ini -replace "`r?`n", "`r`n")
    } else {
        # Tailored for local GPU
        $localGpu = if ($script:HwReport) { $script:HwReport.PrimaryGpu } else { $null }
        $isGenericFallback = ($null -eq $localGpu)
        $ini = New-UnlockConfigIniText -Gpu $localGpu -Esp $espObj -Mode $effMode -CountdownSeconds $cdSec `
            -UniversalGeneric:$isGenericFallback `
            -StrictBoard:$chkStrictBoard.Checked `
            -StrictSubsystem:$chkStrictSubsys.Checked `
            -StrictChip:$chkStrictChip.Checked `
            -StrictBdf:$chkStrictBdf.Checked `
            -StrictBar0:$chkStrictBar0.Checked `
            -StrictEsp:$chkStrictEsp.Checked `
            -AllowHeadlessHandoff:$chkHeadless.Checked `
            -SavePromDump:$chkPromDump.Checked
        $txtConfigIni.Text = ($ini -replace "`r?`n", "`r`n")
    }
}

function Refresh-UsbDriveList {
    $cmbUsbDrive.Items.Clear()
    $script:UsbDrives = @(Get-UsbDriveInventory -IncludeNonRemovable:($chkAllDrives.Checked))
    if ($script:UsbDrives.Count -eq 0) {
        [void]$cmbUsbDrive.Items.Add("(No USB drives detected - plug in a FAT32 USB stick and click Refresh USB, or use Stage to Local Folder)")
        $cmbUsbDrive.SelectedIndex = 0
    } else {
        $bestIdx = 0
        for ($i = 0; $i -lt $script:UsbDrives.Count; $i++) {
            [void]$cmbUsbDrive.Items.Add($script:UsbDrives[$i].DisplayText)
            if ($script:UsbDrives[$i].ReadyToStage) { $bestIdx = $i }
        }
        $cmbUsbDrive.SelectedIndex = $bestIdx
    }
}

function Update-LiveLockDisplay {
    param($LiveStatus)
    if (-not $LiveStatus -or -not $LiveStatus.Available) {
        $lblLockBadge.Text = "GPU STATE: N/A"
        $lblLockBadge.BackColor = [System.Drawing.Color]::FromArgb(70, 80, 100)
        $lblLiveBench.Text = "Live Tensor Core Status: Unavailable (compile benchmark via benchmark\Build-Benchmark.ps1)"
        $lblLiveBench.ForeColor = $FgMuted
        return
    }

    $pctF16  = [math]::Round($LiveStatus.F16Ratio * 100, 1)
    $pctBf16 = [math]::Round($LiveStatus.Bf16Ratio * 100, 1)

    if ($LiveStatus.IsUnlocked) {
        $lblLockBadge.Text = "GPU: UNLOCKED ($pctF16%)"
        $lblLockBadge.BackColor = $AccentGreen
        $lblLiveBench.ForeColor = [System.Drawing.Color]::FromArgb(135, 235, 115)
    } else {
        $lblLockBadge.Text = "GPU: LOCKED ($pctF16%)"
        $lblLockBadge.BackColor = $AccentAmber
        $lblLiveBench.ForeColor = [System.Drawing.Color]::FromArgb(245, 200, 90)
    }

    $line1 = "CURRENT BOOT : {0,-8} | f16/f32: {1,5:N1} TF/s ({2}%) | bf16/f32: {3,5:N1} TF/s ({4}%) | f16/f16: {5,5:N1} TF/s" -f `
        $LiveStatus.State, $LiveStatus.F16F32Tflops, $pctF16, $LiveStatus.Bf16F32Tflops, $pctBf16, $LiveStatus.F16F16Tflops

    if ($LiveStatus.Baseline -and $LiveStatus.Baseline.modes.'f16/f32') {
        $bF16  = [double]$LiveStatus.Baseline.modes.'f16/f32'.best_tflops
        $bBf16 = [double]$LiveStatus.Baseline.modes.'bf16/f32'.best_tflops
        $line2 = "BEFORE/AFTER : Baseline f16/f32 {0,5:N1} -> {1,5:N1} TF/s [{2:N2}x] | bf16/f32 {3,5:N1} -> {4,5:N1} TF/s [{5:N2}x]" -f `
            $bF16, $LiveStatus.F16F32Tflops, $LiveStatus.GainF16, $bBf16, $LiveStatus.Bf16F32Tflops, $LiveStatus.GainBf16
    } else {
        $line2 = "BEFORE/AFTER : No baseline saved yet. Click [Benchmark (Save 'Before')] prior to unlocking to compare!"
    }
    $lblLiveBench.Text = "$line1`r`n$line2"
}

function Refresh-HardwareReport {
    Write-GuiLog "Scanning PCIe display adapters, live Tensor Core lock/unlock state, Secure Boot, Windows ESP, and firmware assets..." "HEAD"
    $script:HwReport = Get-SystemHardwareReport -RepoRoot $RepoRoot

    $lstGpus.Items.Clear()
    foreach ($g in $script:HwReport.AllGpus) {
        $tag = if ($g.IsCompatible) { "[SUPPORTED $($g.Arch.ToUpper())]" } else { "[SKIPPED]" }
        $line = "$tag $($g.Name) | PCI $($g.BoardIdHex) | Subsys $($g.SubsystemIdHex) | Chip $($g.ChipIdHex) | BDF $($g.BdfString) | BAR0 $($g.Bar0BaseHex) | $($g.CompatReason)"
        [void]$lstGpus.Items.Add($line)
        $lvl = if ($g.IsCompatible) { "PASS" } else { "WARN" }
        Write-GuiLog "GPU Discovered: $line" $lvl
    }

    Update-LiveLockDisplay -LiveStatus $script:HwReport.LiveUnlockStatus
    if ($script:HwReport.LiveUnlockStatus -and $script:HwReport.LiveUnlockStatus.Available) {
        $ls = $script:HwReport.LiveUnlockStatus
        $lvl = if ($ls.IsUnlocked) { "PASS" } else { "WARN" }
        Write-GuiLog "Live GPU State: $($ls.SummaryText)" $lvl
    }

    $gridChecks.Rows.Clear()
    foreach ($c in $script:HwReport.Checks) {
        $valText = if ($c.Status -ne "PASS" -and $c.Recommendation) { "$($c.Value)  [$($c.Recommendation)]" } else { $c.Value }
        $rowIdx = $gridChecks.Rows.Add($c.Status, $c.Item, $valText)
        $row = $gridChecks.Rows[$rowIdx]
        switch ($c.Status) {
            "PASS" { $row.Cells[0].Style.ForeColor = [System.Drawing.Color]::FromArgb(125, 225, 110) }
            "WARN" { $row.Cells[0].Style.ForeColor = [System.Drawing.Color]::FromArgb(245, 195, 80) }
            "FAIL" { $row.Cells[0].Style.ForeColor = [System.Drawing.Color]::FromArgb(255, 105, 95) }
        }
    }

    if ($script:HwReport.PrimaryGpu) {
        $pg = $script:HwReport.PrimaryGpu
        $lblSubtitle.Text = "Detected GPU: $($pg.Name) [$($pg.ChipFamily) | $($pg.BoardIdHex)]  |  Mainboard: $($script:HwReport.Motherboard.Product) (BIOS $($script:HwReport.Motherboard.BiosVersion))  |  OS: $($script:HwReport.OS.Caption)"
    } else {
        $lblSubtitle.Text = "No local RTX 3000/4000 GPU detected. Universal Generic Mode enabled to build a USB stick for another RTX 3000/4000 PC."
    }

    if ($script:HwReport.Issues.Count -gt 0) {
        $lblBadge.Text = "ACTION NEEDED ($($script:HwReport.Issues.Count))"
        $lblBadge.BackColor = $AccentRed
        foreach ($iss in $script:HwReport.Issues) { Write-GuiLog $iss "FAIL" }
    } else {
        $warnCount = ($script:HwReport.Checks | Where-Object { $_.Status -eq "WARN" }).Count
        if ($warnCount -gt 0) {
            $lblBadge.Text = "READY ($warnCount Note)"
            $lblBadge.BackColor = $AccentBlue
        } else {
            $lblBadge.Text = "ALL CHECKS PASSED"
            $lblBadge.BackColor = $AccentGreen
        }
    }

    Update-ConfigPreviewFromControls
    Refresh-UsbDriveList
    Write-GuiLog "Hardware & live lock-state inspection complete. Ready to benchmark, validate CONFIG.INI, or create USB stick." "PASS"
}

# Wire up Profile & Mode Change Events
$cmbProfileType.Add_SelectedIndexChanged({
    $script:UpdatingControls = $true
    $idx = $cmbProfileType.SelectedIndex
    $cmbCatalogGpu.Enabled = ($idx -eq 2)
    if ($idx -eq 1) {
        # Universal Generic
        $chkStrictBoard.Checked  = $false
        $chkStrictSubsys.Checked = $false
        $chkStrictChip.Checked   = $false
        $chkStrictBdf.Checked    = $false
        $chkStrictBar0.Checked   = $false
        $chkStrictEsp.Checked    = $false
    } elseif ($idx -eq 2) {
        # Specific Catalog GPU
        $chkStrictBoard.Checked  = $true
        $chkStrictSubsys.Checked = $false
        $chkStrictChip.Checked   = $false
    } else {
        # Local GPU
        $chkStrictBoard.Checked  = $true
        $chkStrictSubsys.Checked = $true
        $chkStrictChip.Checked   = $false
    }
    $script:UpdatingControls = $false
    Update-ConfigPreviewFromControls
})

$cmbCatalogGpu.Add_SelectedIndexChanged({ Update-ConfigPreviewFromControls })
$cmbBootMode.Add_SelectedIndexChanged({ Update-ConfigPreviewFromControls })
$numCountdown.Add_ValueChanged({ Update-ConfigPreviewFromControls })
foreach ($chk in @($chkStrictBoard, $chkStrictSubsys, $chkStrictChip, $chkStrictBdf, $chkStrictBar0, $chkStrictEsp, $chkHeadless, $chkPromDump)) {
    $chk.Add_CheckedChanged({ Update-ConfigPreviewFromControls })
}

$btnRegenIni.Add_Click({
    Update-ConfigPreviewFromControls
    Write-GuiLog "Regenerated CONFIG.INI preview from current profile controls." "INFO"
})

$btnValidateIni.Add_Click({
    $res = Test-ConfigIniCompatibility -IniText $txtConfigIni.Text -HardwareReport $script:HwReport
    if ($res.IsValid -and $res.Warnings.Count -eq 0) {
        Write-GuiLog "CONFIG.INI Validation PASSED: mode=$($res.Parsed['mode']), arch=$($res.Parsed['arch']), board_id=$($res.Parsed['board_id']), subsys=$($res.Parsed['subsystem_id'])" "PASS"
    } elseif ($res.IsValid) {
        Write-GuiLog "CONFIG.INI Syntax Valid with $($res.Warnings.Count) warning(s):" "WARN"
        foreach ($w in $res.Warnings) { Write-GuiLog "  Warning: $w" "WARN" }
    } else {
        Write-GuiLog "CONFIG.INI Validation FAILED with $($res.Errors.Count) error(s):" "FAIL"
        foreach ($e in $res.Errors) { Write-GuiLog "  Error: $e" "FAIL" }
    }
})

$btnSavePkgIni.Add_Click({
    $res = Test-ConfigIniCompatibility -IniText $txtConfigIni.Text -HardwareReport $script:HwReport
    if (-not $res.IsValid) {
        Write-GuiLog "Refusing to save invalid CONFIG.INI. Fix validation errors first." "FAIL"
        return
    }
    $outPath = Join-Path $RepoRoot "usb-package\RTX4090-PREP\CONFIG.INI"
    Set-Content -Path $outPath -Value $txtConfigIni.Text -Encoding ASCII
    Write-GuiLog "Saved validated CONFIG.INI to $outPath" "PASS"
})

$btnRescan.Add_Click({ Refresh-HardwareReport })
$btnRefreshUsb.Add_Click({
    Refresh-UsbDriveList
    Write-GuiLog "Refreshed USB drive inventory ($($script:UsbDrives.Count) candidate drive(s) found)." "INFO"
})
$chkAllDrives.Add_CheckedChanged({ Refresh-UsbDriveList })

function Invoke-GuiBenchmark {
    param([switch]$SaveBaseline)
    $modeLabel = if ($SaveBaseline) { "Baseline ('Before' Unlock)" } else { "Current ('After' / Comparison)" }
    Write-GuiLog "Running CUDA Numerical Validation (validate_gemm.exe) + Sustained Tensor Core Benchmark (mma_bench.exe 20000 3) [$modeLabel]..." "HEAD"
    $progressBar.Value = 25
    try {
        $mmaExe = Join-Path $RepoRoot "benchmark\mma_bench.exe"
        $valExe = Join-Path $RepoRoot "benchmark\validate_gemm.exe"
        if (-not (Test-Path $mmaExe) -or -not (Test-Path $valExe)) {
            Write-GuiLog "Compiling CUDA benchmarks via Build-Benchmark.ps1..." "INFO"
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "benchmark\Build-Benchmark.ps1") | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'Benchmark compilation failed.' }
        }
        $progressBar.Value = 50
        $res = Get-GpuLiveUnlockStatus -RepoRoot $RepoRoot -Iterations 20000 -Repetitions 3 -RunValidation -SaveReport -SaveAsBaseline:$SaveBaseline
        $progressBar.Value = 90
        if ($res.ValidationLog) {
            foreach ($l in ($res.ValidationLog -split "`r?`n")) {
                if ($l.Trim()) { Write-GuiLog "  [validate_gemm] $l" $(if ($res.ValidationPass) { "PASS" } else { "FAIL" }) }
            }
        }
        if ($res.RawOutput) {
            foreach ($l in ($res.RawOutput -split "`r?`n")) {
                if ($l.Trim()) { Write-GuiLog "  [mma_bench]     $l" "INFO" }
            }
        }
        Update-LiveLockDisplay -LiveStatus $res
        if (-not $res.Available -or -not $res.ValidationPass -or $res.State -eq 'ERROR') {
            throw $res.SummaryText
        }
        $lvl = if ($res.IsUnlocked) { "PASS" } else { "WARN" }
        Write-GuiLog "Benchmark Summary: $($res.SummaryText)" $lvl
        if ($res.ReportFilePath) {
            Write-GuiLog "Saved human-readable benchmark report: $($res.ReportFilePath)" "PASS"
        }
        if ($SaveBaseline) {
            Write-GuiLog "Saved 'Before' baseline report in benchmark-reports\. Reboot via the Unlock USB stick and click [Benchmark & Compare ('After')]!" "PASS"
        } elseif ($res.Baseline -and $res.Baseline.modes.'f16/f32') {
            $bF16  = [double]$res.Baseline.modes.'f16/f32'.best_tflops
            $bBf16 = [double]$res.Baseline.modes.'bf16/f32'.best_tflops
            Write-GuiLog ("Before vs. After Comparison: f16/f32 {0:N1} -> {1:N1} TF/s ({2:N2}x) | bf16/f32 {3:N1} -> {4:N1} TF/s ({5:N2}x)" -f `
                $bF16, $res.F16F32Tflops, $res.GainF16, $bBf16, $res.Bf16F32Tflops, $res.GainBf16) $lvl
        }
        $progressBar.Value = 100
    } catch {
        Write-GuiLog "Benchmark execution failed: $($_.Exception.Message)" "FAIL"
    } finally {
        $progressBar.Value = 0
    }
}

$btnBenchBaseline.Add_Click({ Invoke-GuiBenchmark -SaveBaseline })
$btnBench.Add_Click({ Invoke-GuiBenchmark })

$btnRebuild.Add_Click({
    Write-GuiLog "Rebuilding UEFI binaries (build.py) and running host verification suite (test.py)..." "HEAD"
    $progressBar.Value = 30
    try {
        $py = if (Test-Path "C:\Python314\python.exe") { "C:\Python314\python.exe" } else { "python.exe" }
        $bOut = & $py (Join-Path $RepoRoot "build.py") 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { throw "build.py failed:`n$bOut" }
        $progressBar.Value = 70
        $tOut = & $py (Join-Path $RepoRoot "test.py") 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { throw "test.py failed:`n$tOut" }
        $progressBar.Value = 100
        Write-GuiLog "UEFI compilation & host verification suite succeeded: $($tOut.Trim())" "PASS"
        Refresh-HardwareReport
    } catch {
        Write-GuiLog "Build/Test error: $($_.Exception.Message)" "FAIL"
    } finally {
        $progressBar.Value = 0
    }
})

$btnCopyShutdown.Add_Click({
    [System.Windows.Forms.Clipboard]::SetText("shutdown /s /f /t 0")
    Write-GuiLog "Copied 'shutdown /s /f /t 0' to clipboard. Run it in an Administrator terminal before booting from the USB stick so the GPU cold-resets WPR2." "PASS"
})

$btnVerifyPkg.Add_Click({
    $pkgDir = Join-Path $RepoRoot "usb-package"
    Write-GuiLog "Verifying local package folder: $pkgDir ..." "HEAD"
    $progressBar.Value = 30
    try {
        $res = Test-StagedUsbIntegrity -FolderPath $pkgDir -RepoRoot $RepoRoot -HardwareReport $script:HwReport
        foreach ($c in $res.Checks) {
            Write-GuiLog ("{0,-42} : {1}" -f $c.Item, $c.Detail) $c.Status
        }
        if ($res.AllPassed) {
            Write-GuiLog "All 15 integrity & SHA-256 checks PASSED for local usb-package\!" "PASS"
        } else {
            Write-GuiLog "One or more integrity checks failed in usb-package\." "FAIL"
        }
    } catch {
        Write-GuiLog "Package verification error: $($_.Exception.Message)" "FAIL"
    } finally {
        $progressBar.Value = 0
    }
})

function Invoke-StageToTarget {
    param(
        [string]$DriveLetter = "",
        [string]$FolderPath = ""
    )
    $valRes = Test-ConfigIniCompatibility -IniText $txtConfigIni.Text -HardwareReport $script:HwReport
    if (-not $valRes.IsValid) {
        Write-GuiLog "Cannot stage: CONFIG.INI has syntax/validation errors:" "FAIL"
        foreach ($e in $valRes.Errors) { Write-GuiLog "  - $e" "FAIL" }
        return
    }

    $modeSelection = switch ($cmbBootMode.SelectedIndex) {
        1 { "auto" }
        2 { "probe" }
        default { "manual" }
    }

    $progressBar.Value = 15
    try {
        $usbPkg = Join-Path $RepoRoot "usb-package"
        Assert-StagingTarget -DriveLetter $DriveLetter -FolderPath $FolderPath -RepoRoot $RepoRoot
        if ($FolderPath) {
            $targetRoot = $FolderPath
            Write-GuiLog "Staging UEFI Unlocker package to folder: $targetRoot (Boot Mode: $modeSelection)..." "HEAD"
            New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null
        } else {
            $clean = $DriveLetter.Trim().TrimEnd(':').ToUpper()
            $targetRoot = "${clean}:\"
            Write-GuiLog "Staging UEFI Unlocker package to USB Drive $targetRoot (Boot Mode: $modeSelection)..." "HEAD"
        }

        $targetEfiBoot    = Join-Path $targetRoot "EFI\BOOT"
        $targetPrep       = Join-Path $targetRoot "RTX4090-PREP"
        $targetPrepAssets = Join-Path $targetPrep "ASSETS"
        $targetProbe      = Join-Path $targetRoot "GPU-PROBE"

        New-Item -ItemType Directory -Force -Path $targetEfiBoot    | Out-Null
        New-Item -ItemType Directory -Force -Path $targetPrep       | Out-Null
        New-Item -ItemType Directory -Force -Path $targetPrepAssets | Out-Null
        New-Item -ItemType Directory -Force -Path $targetProbe      | Out-Null

        $progressBar.Value = 30
        Copy-Item -Path (Join-Path $usbPkg "EFI\BOOT\*.EFI") -Destination $targetEfiBoot -Force
        switch ($modeSelection) {
            "manual" { Copy-Item -Path (Join-Path $usbPkg "EFI\BOOT\UNLOCK-MANUAL.EFI")  -Destination (Join-Path $targetEfiBoot "BOOTX64.EFI") -Force }
            "auto"   { Copy-Item -Path (Join-Path $usbPkg "EFI\BOOT\UNLOCK-AUTO.EFI")    -Destination (Join-Path $targetEfiBoot "BOOTX64.EFI") -Force }
            "probe"  { Copy-Item -Path (Join-Path $usbPkg "EFI\BOOT\PROBE-READONLY.EFI") -Destination (Join-Path $targetEfiBoot "BOOTX64.EFI") -Force }
        }

        Copy-Item -Path (Join-Path $usbPkg "GPU-PROBE\ALLOW-READONLY.TAG") -Destination (Join-Path $targetProbe "ALLOW-READONLY.TAG") -Force
        if (Test-Path (Join-Path $usbPkg "INSTRUCTIONS.txt")) {
            Copy-Item -Path (Join-Path $usbPkg "INSTRUCTIONS.txt") -Destination (Join-Path $targetRoot "INSTRUCTIONS.txt") -Force
        }

        $progressBar.Value = 55
        Write-GuiLog "Copying 9 NVIDIA 610.43.03 AD10x (RTX 4000) & GA10x (RTX 3000) firmware assets (~84.6 MB)..." "INFO"
        Copy-Item -Path (Join-Path $usbPkg "RTX4090-PREP\ASSETS\*") -Destination $targetPrepAssets -Force

        $progressBar.Value = 80
        Set-Content -Path (Join-Path $targetPrep "CONFIG.INI") -Value $txtConfigIni.Text -Encoding ASCII
        $genericText = New-UnlockConfigIniText -Gpu $null -Esp $null -Mode $(if ($modeSelection -eq "auto") { "auto" } else { "manual" }) -CountdownSeconds ([int]$numCountdown.Value) -UniversalGeneric:$true
        Set-Content -Path (Join-Path $targetPrep "CONFIG-GENERIC.INI") -Value $genericText -Encoding ASCII

        Write-GuiLog "Running post-stage PE/COFF, CONFIG.INI, and SHA-256 verification on $targetRoot ..." "HEAD"
        $ver = if ($FolderPath) {
            Test-StagedUsbIntegrity -FolderPath $FolderPath -RepoRoot $RepoRoot -HardwareReport $script:HwReport
        } else {
            Test-StagedUsbIntegrity -DriveLetter $DriveLetter -RepoRoot $RepoRoot -HardwareReport $script:HwReport
        }
        foreach ($c in $ver.Checks) {
            Write-GuiLog ("  {0,-40} : {1}" -f $c.Item, $c.Detail) $c.Status
        }
        $progressBar.Value = 100
        if ($ver.AllPassed) {
            Write-GuiLog "SUCCESS! Target $targetRoot is 100% verified and ready for UEFI boot." "PASS"
        } else {
            Write-GuiLog "Staging finished with verification errors on $targetRoot." "FAIL"
        }
        Refresh-UsbDriveList
    } catch {
        Write-GuiLog "Staging failed: $($_.Exception.Message)" "FAIL"
    } finally {
        $progressBar.Value = 0
    }
}

$btnCreateUsb.Add_Click({
    if (-not $script:UsbDrives -or $script:UsbDrives.Count -eq 0 -or $cmbUsbDrive.SelectedIndex -lt 0) {
        Write-GuiLog "No USB drive is selected. Plug in a FAT32 USB drive and click 'Refresh USB', or use 'Stage to Local Folder...'." "WARN"
        return
    }
    $selDrive = $script:UsbDrives[$cmbUsbDrive.SelectedIndex]
    if (-not $selDrive.FileSystem -or $selDrive.FileSystem -eq 'UNKNOWN') {
        Write-GuiLog "Cannot determine the filesystem of $($selDrive.DriveLetter). $($selDrive.FileSystemDiagnostic)" "FAIL"
        return
    }
    if ($selDrive.FileSystem -ne "FAT32") {
        Write-GuiLog "Drive $($selDrive.DriveLetter) is formatted as $($selDrive.FileSystem). UEFI boot sticks MUST be formatted as FAT32." "FAIL"
        [System.Windows.Forms.MessageBox]::Show(
            "Drive $($selDrive.DriveLetter) ($($selDrive.DiskModel)) is formatted as $($selDrive.FileSystem).`n`nUEFI firmware can only boot from FAT32 partitions. Please format the USB stick as FAT32 and click 'Refresh USB'.",
            "FAT32 Formatting Required",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }
    if (-not $selDrive.ReadyToStage) {
        Write-GuiLog "Drive $($selDrive.DriveLetter) is not ready: $($selDrive.StatusNote)" "FAIL"
        return
    }
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Create / update the RTX 3000 & 4000 UEFI Unlocker on USB drive $($selDrive.DriveLetter) [$($selDrive.DiskModel)]?`n`nExisting files in \EFI\BOOT, \RTX4090-PREP, and \GPU-PROBE on $($selDrive.DriveLetter) will be updated.",
        "Confirm USB Stick Creation",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
        Invoke-StageToTarget -DriveLetter $selDrive.CleanLetter
    }
})

$btnVerifyUsb.Add_Click({
    if (-not $script:UsbDrives -or $script:UsbDrives.Count -eq 0 -or $cmbUsbDrive.SelectedIndex -lt 0) {
        Write-GuiLog "No USB drive selected to verify. Click 'Verify Local usb-package\' to verify the built package." "WARN"
        return
    }
    $selDrive = $script:UsbDrives[$cmbUsbDrive.SelectedIndex]
    Write-GuiLog "Verifying existing USB stick at $($selDrive.DriveLetter)\ ..." "HEAD"
    try {
        $ver = Test-StagedUsbIntegrity -DriveLetter $selDrive.CleanLetter -RepoRoot $RepoRoot -HardwareReport $script:HwReport
        foreach ($c in $ver.Checks) {
            Write-GuiLog ("  {0,-40} : {1}" -f $c.Item, $c.Detail) $c.Status
        }
        if ($ver.AllPassed) {
            Write-GuiLog "All 15 USB integrity & SHA-256 verification checks PASSED on $($selDrive.DriveLetter)\!" "PASS"
        } else {
            Write-GuiLog "Verification failed on $($selDrive.DriveLetter)\." "FAIL"
        }
    } catch {
        Write-GuiLog "USB verification error: $($_.Exception.Message)" "FAIL"
    }
})

$btnExportFolder.Add_Click({
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
    $fbd.Description = "Select a destination folder to stage the complete USB UEFI Unlocker structure"
    $fbd.SelectedPath = $RepoRoot
    if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Invoke-StageToTarget -FolderPath $fbd.SelectedPath
    }
})

# Initial Load
Refresh-HardwareReport

if ($SelfTest) {
    Write-Host "=== UsbCreatorGui.ps1 Automated Self-Test ===" -ForegroundColor Cyan
    Write-Host "  1. Discovered GPUs         : $($script:HwReport.AllGpus.Count) (Compatible: $($script:HwReport.CompatibleGpus.Count))" -ForegroundColor Green
    if ($script:HwReport.LiveUnlockStatus -and $script:HwReport.LiveUnlockStatus.Available) {
        Write-Host "  2. Live Lock/Unlock Probe  : $($script:HwReport.LiveUnlockStatus.SummaryText)" -ForegroundColor Yellow
    } else {
        Write-Host "  2. CUDA probe unavailable; hardware-independent GUI checks continue." -ForegroundColor Yellow
    }
    Write-Host "  3. Catalog Models Loaded   : $($script:CatalogItems.Count) RTX 3000 (GA10x) & RTX 4000 (AD10x) models" -ForegroundColor Green

    # Test switching to Universal Generic Mode
    $cmbProfileType.SelectedIndex = 1
    $genValid = Test-ConfigIniCompatibility -IniText $txtConfigIni.Text -HardwareReport $script:HwReport
    if (-not $genValid.IsValid) { throw "SelfTest failed: Generic CONFIG.INI invalid" }
    Write-Host "  3. Generic Profile Builder : PASS (arch=$($genValid.Parsed['arch']), board_id=$($genValid.Parsed['board_id']))" -ForegroundColor Green

    # Test switching to Catalog Mode (e.g. RTX 3090 GA102)
    $rtx3090Idx = 0
    for ($i = 0; $i -lt $script:CatalogItems.Count; $i++) {
        if ($script:CatalogItems[$i].DevId -eq "2204") { $rtx3090Idx = $i; break }
    }
    $cmbProfileType.SelectedIndex = 2
    $cmbCatalogGpu.SelectedIndex = $rtx3090Idx
    $catValid = Test-ConfigIniCompatibility -IniText $txtConfigIni.Text -HardwareReport $null
    if (-not $catValid.IsValid -or $catValid.Parsed['board_id'] -ne '0x220410de' -or $catValid.Parsed['arch'] -ne 'ampere') {
        throw "SelfTest failed: Catalog RTX 3090 CONFIG.INI invalid"
    }
    Write-Host "  4. Catalog Profile Builder : PASS (RTX 3090 GA102 -> arch=$($catValid.Parsed['arch']), board_id=$($catValid.Parsed['board_id']))" -ForegroundColor Green

    # Switch back to Tailored Local GPU Mode
    $cmbProfileType.SelectedIndex = 0
    $locValid = Test-ConfigIniCompatibility -IniText $txtConfigIni.Text -HardwareReport $script:HwReport
    if (-not $locValid.IsValid) { throw "SelfTest failed: Local Tailored CONFIG.INI invalid" }
    Write-Host "  5. Local Tailored Builder  : PASS (arch=$($locValid.Parsed['arch']), board_id=$($locValid.Parsed['board_id']))" -ForegroundColor Green

    # Verify usb-package integrity
    $pkgRes = Test-StagedUsbIntegrity -FolderPath (Join-Path $RepoRoot "usb-package") -RepoRoot $RepoRoot -HardwareReport $script:HwReport
    if (-not $pkgRes.AllPassed) { throw "SelfTest failed: usb-package integrity check failed" }
    Write-Host "  6. Package SHA-256 Check   : PASS ($($pkgRes.Checks.Count)/$($pkgRes.Checks.Count) checks passed)" -ForegroundColor Green

    $form.Dispose()
    Write-Host "=== UsbCreatorGui.ps1 Self-Test PASSED! ===" -ForegroundColor Green
    exit 0
}

[void]$form.ShowDialog()
