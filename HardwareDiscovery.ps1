#Requires -Version 5.1
<#
.SYNOPSIS
    Shared Hardware Discovery, Compatibility Analyzer, Config Validator, and USB Inspector
    for the RTX 3000 (Ampere GA10x) & RTX 4000 (Ada AD10x) Windows UEFI Unlocker.
#>

function Get-SupportedGpuCatalog {
    return @{
        # ================= RTX 4000 Series (Ada Lovelace - AD10x) =================
        "2684" = @{ Name = "GeForce RTX 4090";                Chip = "AD102"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x192000a1 }
        "2685" = @{ Name = "GeForce RTX 4090 D";              Chip = "AD102"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x192000a1 }
        "2689" = @{ Name = "GeForce RTX 4090 (AD102)";        Chip = "AD102"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x192000a1 }
        "2702" = @{ Name = "GeForce RTX 4080 SUPER";          Chip = "AD103"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x193000a1 }
        "2703" = @{ Name = "GeForce RTX 4080 (AD103)";        Chip = "AD103"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x193000a1 }
        "2704" = @{ Name = "GeForce RTX 4080";                Chip = "AD103"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x193000a1 }
        "2705" = @{ Name = "GeForce RTX 4070 Ti SUPER";       Chip = "AD103"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x193000a1 }
        "2709" = @{ Name = "GeForce RTX 4070 (AD103)";        Chip = "AD103"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x193000a1 }
        "2717" = @{ Name = "GeForce RTX 4090 Laptop GPU";     Chip = "AD103"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x193000a1 }
        "2757" = @{ Name = "GeForce RTX 4090 Laptop (Max-Q)"; Chip = "AD103"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x193000a1 }
        "2782" = @{ Name = "GeForce RTX 4070 Ti";             Chip = "AD104"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x194000a1 }
        "2783" = @{ Name = "GeForce RTX 4070 SUPER";          Chip = "AD104"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x194000a1 }
        "2786" = @{ Name = "GeForce RTX 4070";                Chip = "AD104"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x194000a1 }
        "2788" = @{ Name = "GeForce RTX 4060 Ti (AD104)";     Chip = "AD104"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x194000a1 }
        "27A0" = @{ Name = "GeForce RTX 4080 Laptop GPU";     Chip = "AD104"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x194000a1 }
        "27E0" = @{ Name = "GeForce RTX 4080 Laptop (Max-Q)"; Chip = "AD104"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x194000a1 }
        "2803" = @{ Name = "GeForce RTX 4060 Ti 8GB";         Chip = "AD106"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x196000a1 }
        "2805" = @{ Name = "GeForce RTX 4060 Ti 16GB";        Chip = "AD106"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x196000a1 }
        "2808" = @{ Name = "GeForce RTX 4060 (AD106)";        Chip = "AD106"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x196000a1 }
        "2820" = @{ Name = "GeForce RTX 4070 Laptop GPU";     Chip = "AD106"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x196000a1 }
        "2860" = @{ Name = "GeForce RTX 4070 Laptop (Max-Q)"; Chip = "AD106"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x196000a1 }
        "2882" = @{ Name = "GeForce RTX 4060";                Chip = "AD107"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x197000a1 }
        "28A0" = @{ Name = "GeForce RTX 4060 Laptop GPU";     Chip = "AD107"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x197000a1 }
        "28A1" = @{ Name = "GeForce RTX 4050 Laptop GPU";     Chip = "AD107"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x197000a1 }
        "28E0" = @{ Name = "GeForce RTX 4060 Laptop (Max-Q)"; Chip = "AD107"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x197000a1 }
        "28E1" = @{ Name = "GeForce RTX 4050 Laptop (Max-Q)"; Chip = "AD107"; Arch = "ada";    Series = "RTX 4000 (Ada Lovelace)"; DefaultChipId = 0x197000a1 }

        # ================= RTX 3000 Series (Ampere - GA10x) =================
        "2200" = @{ Name = "GeForce RTX 3090 Ti / GA102";     Chip = "GA102"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x172000a1 }
        "2203" = @{ Name = "GeForce RTX 3090 Ti";             Chip = "GA102"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x172000a1 }
        "2204" = @{ Name = "GeForce RTX 3090";                Chip = "GA102"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x172000a1 }
        "2205" = @{ Name = "GeForce RTX 3080 Ti 20GB";        Chip = "GA102"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x172000a1 }
        "2206" = @{ Name = "GeForce RTX 3080 10GB";           Chip = "GA102"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x172000a1 }
        "2207" = @{ Name = "GeForce RTX 3080 Ti (GA102)";     Chip = "GA102"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x172000a1 }
        "2208" = @{ Name = "GeForce RTX 3080 Ti 12GB";        Chip = "GA102"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x172000a1 }
        "220A" = @{ Name = "GeForce RTX 3080 12GB";           Chip = "GA102"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x172000a1 }
        "220D" = @{ Name = "NVIDIA CMP 90HX (GA102)";         Chip = "GA102"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x172000a1 }
        "2216" = @{ Name = "GeForce RTX 3080 10GB LHR";       Chip = "GA102"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x172000a1 }
        "222B" = @{ Name = "GeForce RTX 3080 (GA102)";        Chip = "GA102"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x172000a1 }
        "222F" = @{ Name = "GeForce RTX 3080 OEM (GA102)";    Chip = "GA102"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x172000a1 }
        "2414" = @{ Name = "GeForce RTX 3060 Ti (GA103)";     Chip = "GA103"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x173000a1 }
        "2420" = @{ Name = "GeForce RTX 3080 Ti Laptop GPU";  Chip = "GA103"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x173000a1 }
        "2460" = @{ Name = "GeForce RTX 3080 Ti Laptop Max-Q";Chip = "GA103"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x173000a1 }
        "2480" = @{ Name = "GeForce RTX 3070 / GA104";        Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "2482" = @{ Name = "GeForce RTX 3070 Ti";             Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "2483" = @{ Name = "GeForce RTX 3070 (GA104)";        Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "2484" = @{ Name = "GeForce RTX 3070";                Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "2486" = @{ Name = "GeForce RTX 3060 Ti";             Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "2487" = @{ Name = "GeForce RTX 3060 (GA104)";        Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "2488" = @{ Name = "GeForce RTX 3070 LHR";            Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "2489" = @{ Name = "GeForce RTX 3060 Ti LHR";         Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "248A" = @{ Name = "NVIDIA CMP 70HX (GA104)";         Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "248C" = @{ Name = "GeForce RTX 3060 Ti GDDR6X";      Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "248D" = @{ Name = "GeForce RTX 3070 / GA104";        Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "248E" = @{ Name = "GeForce RTX 3070 OEM (GA104)";    Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "249C" = @{ Name = "GeForce RTX 3080 Laptop GPU";     Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "249D" = @{ Name = "GeForce RTX 3070 Laptop GPU";     Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "249F" = @{ Name = "GeForce RTX 3070 Laptop GPU";     Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "24A0" = @{ Name = "GeForce RTX 3070 Ti Laptop GPU";  Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "24A4" = @{ Name = "GeForce RTX 3070 Laptop / GA104"; Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "24AC" = @{ Name = "GeForce RTX 3080 Laptop / GA104"; Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "24AD" = @{ Name = "GeForce RTX 3070 Laptop / GA104"; Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "24AF" = @{ Name = "GeForce RTX 3070 Laptop / GA104"; Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "24BF" = @{ Name = "GeForce RTX 3070 / GA104";        Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "24C0" = @{ Name = "GeForce RTX 3080 Ti / GA104";     Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "24C7" = @{ Name = "GeForce RTX 3060 / GA104";        Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "24C8" = @{ Name = "GeForce RTX 3070 Ti / GA104";     Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "24C9" = @{ Name = "GeForce RTX 3070 Ti (GA104)";     Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "24DC" = @{ Name = "GeForce RTX 3080 Laptop (Max-Q)"; Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "24DD" = @{ Name = "GeForce RTX 3070 Laptop (Max-Q)"; Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "24DF" = @{ Name = "GeForce RTX 3070 Laptop GPU";     Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "24E0" = @{ Name = "GeForce RTX 3070 Ti Laptop Max-Q";Chip = "GA104"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x174000a1 }
        "2501" = @{ Name = "GeForce RTX 3060 (GA106)";        Chip = "GA106"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x176000a1 }
        "2503" = @{ Name = "GeForce RTX 3060 12GB";           Chip = "GA106"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x176000a1 }
        "2504" = @{ Name = "GeForce RTX 3060 12GB LHR";       Chip = "GA106"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x176000a1 }
        "2505" = @{ Name = "GeForce RTX 3060 (GA106)";        Chip = "GA106"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x176000a1 }
        "2507" = @{ Name = "GeForce RTX 3050 8GB (GA106)";    Chip = "GA106"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x176000a1 }
        "2508" = @{ Name = "GeForce RTX 3050 OEM (GA106)";    Chip = "GA106"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x176000a1 }
        "2509" = @{ Name = "GeForce RTX 3050 (GA106)";        Chip = "GA106"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x176000a1 }
        "2520" = @{ Name = "GeForce RTX 3060 Laptop GPU";     Chip = "GA106"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x176000a1 }
        "252F" = @{ Name = "GeForce RTX 3060 / GA106";        Chip = "GA106"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x176000a1 }
        "2544" = @{ Name = "GeForce RTX 3060 / GA106";        Chip = "GA106"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x176000a1 }
        "2560" = @{ Name = "GeForce RTX 3060 Laptop (Max-Q)"; Chip = "GA106"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x176000a1 }
        "25A0" = @{ Name = "GeForce RTX 3050 Ti Laptop GPU";  Chip = "GA106"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x176000a1 }
        "25E0" = @{ Name = "GeForce RTX 3050 Ti Laptop Max-Q";Chip = "GA106"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x176000a1 }
        "2582" = @{ Name = "GeForce RTX 3050 8GB";            Chip = "GA107"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x177000a1 }
        "2584" = @{ Name = "GeForce RTX 3050 6GB";            Chip = "GA107"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x177000a1 }
        "25A2" = @{ Name = "GeForce RTX 3050 Laptop GPU";     Chip = "GA107"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x177000a1 }
        "25A5" = @{ Name = "GeForce RTX 3050 Laptop 4GB";     Chip = "GA107"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x177000a1 }
        "25E2" = @{ Name = "GeForce RTX 3050 Laptop (Max-Q)"; Chip = "GA107"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x177000a1 }
        "25E5" = @{ Name = "GeForce RTX 3050 Laptop (Max-Q)"; Chip = "GA107"; Arch = "ampere"; Series = "RTX 3000 (Ampere)";       DefaultChipId = 0x177000a1 }
    }
}

function Get-GpuLiveUnlockStatus {
    param(
        [string]$RepoRoot = $PSScriptRoot,
        [int]$Iterations = 2000,
        [int]$Repetitions = 1,
        [switch]$RunValidation,
        [switch]$SaveAsBaseline,
        [switch]$SaveReport
    )

    $benchDir   = Join-Path $RepoRoot "benchmark"
    $reportsDir = Join-Path $RepoRoot "benchmark-reports"
    $mmaExe     = Join-Path $benchDir "mma_bench.exe"
    $valExe     = Join-Path $benchDir "validate_gemm.exe"

    if (-not (Test-Path $mmaExe)) {
        return [PSCustomObject]@{
            Available      = $false
            State          = "UNKNOWN"
            SummaryText    = "mma_bench.exe not found (run benchmark\Build-Benchmark.ps1)"
            IsUnlocked     = $false
            F16F16Tflops   = 0.0
            F16F32Tflops   = 0.0
            Bf16F32Tflops  = 0.0
            S8S32Tops      = 0.0
            Dp4aTops       = 0.0
            FfmaTflops     = 0.0
            F16Ratio       = 0.0
            Bf16Ratio      = 0.0
            ValidationPass = $true
            ValidationLog  = ""
            Baseline       = $null
            GainF16        = 0.0
            GainBf16       = 0.0
            ReportFilePath = ""
            RawOutput      = ""
        }
    }

    $valPass = $true
    $valLog  = ""
    if ($RunValidation -and -not (Test-Path $valExe)) {
        $valPass = $false
        $valLog = "Validation executable missing: $valExe"
    }
    if ($RunValidation -and (Test-Path $valExe)) {
        try {
            $valOut = & $valExe 2>&1 | Out-String
            $valLog = $valOut.Trim()
            if ($LASTEXITCODE -ne 0) { $valPass = $false }
        } catch {
            $valPass = $false
            $valLog = $_.Exception.Message
        }
    }

    $smiLine = ""
    $nvidiaSmi = (Get-Command "nvidia-smi.exe" -ErrorAction SilentlyContinue).Source
    if (-not $nvidiaSmi -and (Test-Path "$env:SystemRoot\System32\nvidia-smi.exe")) {
        $nvidiaSmi = "$env:SystemRoot\System32\nvidia-smi.exe"
    }
    if ($nvidiaSmi) {
        try {
            $smiLine = (& $nvidiaSmi --query-gpu=name,pci.bus_id,driver_version,vbios_version,clocks.current.graphics,clocks.current.sm,power.draw --format=csv,noheader 2>$null | Select-Object -First 1)
            $smiLine = "$smiLine".Trim()
        } catch {}
    }

    $rawLines = @()
    try {
        $rawLines = & $mmaExe $Iterations $Repetitions 2>&1
        if ($LASTEXITCODE -ne 0) { throw "CUDA benchmark exited with code $LASTEXITCODE : $rawLines" }
    } catch {
        return [PSCustomObject]@{
            Available      = $false
            State          = "ERROR"
            SummaryText    = "Probe error: $($_.Exception.Message)"
            IsUnlocked     = $false
            F16F16Tflops   = 0.0
            F16F32Tflops   = 0.0
            Bf16F32Tflops  = 0.0
            S8S32Tops      = 0.0
            Dp4aTops       = 0.0
            FfmaTflops     = 0.0
            F16Ratio       = 0.0
            Bf16Ratio      = 0.0
            ValidationPass = $valPass
            ValidationLog  = $valLog
            Baseline       = $null
            GainF16        = 0.0
            GainBf16       = 0.0
            ReportFilePath = ""
            RawOutput      = ""
        }
    }

    $gpuHeader = ""
    $modes = [ordered]@{}
    foreach ($line in $rawLines) {
        $strLine = "$line".Trim()
        if ($strLine -match '^#\s*(.+)$') {
            $gpuHeader = $matches[1].Trim()
        } elseif ($strLine -match '^(f16/f16|f16/f32|bf16/f32|s8/s32|dp4a|ffma)\s+([0-9]+\.[0-9]+)\s+(.+)$') {
            $mName = $matches[1].Trim()
            $mBest = [double]::Parse($matches[2], [Globalization.CultureInfo]::InvariantCulture)
            $mRuns = $matches[3].Trim()
            $modes[$mName] = [ordered]@{
                best_tflops = $mBest
                runs        = $mRuns
            }
        }
    }

    $f16f16  = if ($modes["f16/f16"])  { [double]$modes["f16/f16"].best_tflops }  else { 0.0 }
    $f16f32  = if ($modes["f16/f32"])  { [double]$modes["f16/f32"].best_tflops }  else { 0.0 }
    $bf16f32 = if ($modes["bf16/f32"]) { [double]$modes["bf16/f32"].best_tflops } else { 0.0 }
    $s8s32   = if ($modes["s8/s32"])   { [double]$modes["s8/s32"].best_tflops }   else { 0.0 }
    $dp4a    = if ($modes["dp4a"])     { [double]$modes["dp4a"].best_tflops }     else { 0.0 }
    $ffma    = if ($modes["ffma"])     { [double]$modes["ffma"].best_tflops }     else { 0.0 }

    $f16Ratio  = if ($f16f16 -gt 0) { [math]::Round($f16f32 / $f16f16, 3) } else { 0.0 }
    $bf16Ratio = if ($f16f16 -gt 0) { [math]::Round($bf16f32 / $f16f16, 3) } else { 0.0 }
    $completeMetrics = $f16f16 -gt 0 -and $f16f32 -gt 0 -and $bf16f32 -gt 0
    if (-not $completeMetrics) { $valPass = $false; $valLog += " Incomplete benchmark metrics." }
    $isUnlocked = ($completeMetrics -and $valPass -and $f16Ratio -ge 0.82 -and $bf16Ratio -ge 0.80 -and $f16f16 -gt 10.0)
    $stateStr   = if (-not $completeMetrics -or -not $valPass) { "ERROR" } elseif ($isUnlocked) { "UNLOCKED" } elseif ($f16f16 -gt 0) { "LOCKED" } else { "UNKNOWN" }

    # Look up the most recent baseline report in benchmark-reports\ (if any) before saving a new non-baseline report
    $baselineObj = $null
    $gainF16  = 0.0
    $gainBf16 = 0.0
    if ((Test-Path $reportsDir) -and -not $SaveAsBaseline) {
        $latestBaseFile = Get-ChildItem -Path $reportsDir -Filter "*-BASELINE.txt" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latestBaseFile) {
            try {
                $baseText = Get-Content $latestBaseFile.FullName -Raw
                $bF16 = 0.0; $bBf16 = 0.0; $bF16F16 = 0.0
                if ($baseText -match 'f16/f16\s+\|[^|]+\|\s*([0-9]+\.[0-9]+)\s+TFLOPS') { $bF16F16 = [double]::Parse($matches[1], [Globalization.CultureInfo]::InvariantCulture) }
                if ($baseText -match 'f16/f32\s+\|[^|]+\|\s*([0-9]+\.[0-9]+)\s+TFLOPS') { $bF16    = [double]::Parse($matches[1], [Globalization.CultureInfo]::InvariantCulture) }
                if ($baseText -match 'bf16/f32\s+\|[^|]+\|\s*([0-9]+\.[0-9]+)\s+TFLOPS') { $bBf16   = [double]::Parse($matches[1], [Globalization.CultureInfo]::InvariantCulture) }
                # Compare stable GPU identity, excluding clocks and power telemetry.
                $identity = (($smiLine -split "," | Select-Object -First 4) -join ",").Trim()
                $sameGpu = $identity -and $baseText.Contains("Telemetry (SMI)   : $identity,")
                if ($sameGpu -and $bF16 -gt 0 -and $bBf16 -gt 0) {
                    $gainF16  = [math]::Round($f16f32 / $bF16, 2)
                    $gainBf16 = [math]::Round($bf16f32 / $bBf16, 2)
                    $baselineObj = [PSCustomObject]@{
                        FileName = $latestBaseFile.Name
                        modes    = [PSCustomObject]@{
                            'f16/f16'  = [PSCustomObject]@{ best_tflops = $bF16F16 }
                            'f16/f32'  = [PSCustomObject]@{ best_tflops = $bF16 }
                            'bf16/f32' = [PSCustomObject]@{ best_tflops = $bBf16 }
                        }
                    }
                }
            } catch {}
        }
    }

    $pctF16  = [math]::Round($f16Ratio * 100, 1)
    $pctBf16 = [math]::Round($bf16Ratio * 100, 1)
    $summary = if (-not $completeMetrics -or -not $valPass) {
        "ERROR: benchmark metrics incomplete or numerical validation failed. $valLog"
    } elseif ($isUnlocked) {
        "UNLOCKED (Full-Rate Active: f16/f32={0:F1} TF/s [{1}%], bf16/f32={2:F1} TF/s [{3}%], f16/f16={4:F1} TF/s)" -f $f16f32, $pctF16, $bf16f32, $pctBf16, $f16f16
    } elseif ($f16f16 -gt 0) {
        "LOCKED / STOCK (Half-Rate Cap Active: f16/f32={0:F1} TF/s [{1}%], bf16/f32={2:F1} TF/s [{3}%] vs f16/f16={4:F1} TF/s)" -f $f16f32, $pctF16, $bf16f32, $pctBf16, $f16f16
    } else {
        "Unable to measure Tensor Core rate"
    }

    # Save human-readable timestamped report in benchmark-reports\ when running a full benchmark or explicitly requested
    $savedReportPath = ""
    if (($SaveReport -or $SaveAsBaseline -or $Iterations -ge 10000) -and $f16f16 -gt 0) {
        New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null
        $nowLocal = Get-Date
        $nowUtc   = $nowLocal.ToUniversalTime()
        $stamp    = $nowLocal.ToString("yyyy-MM-dd_HH-mm-ss-fffffff")
        $suffix   = if ($SaveAsBaseline) { "$stateStr-BASELINE" } else { $stateStr }
        $fileName = "benchmark-report-$stamp-$suffix.txt"
        $savedReportPath = Join-Path $reportsDir $fileName

        $f16f16Runs  = if ($modes["f16/f16"])  { $modes["f16/f16"].runs }  else { "-" }
        $f16f32Runs  = if ($modes["f16/f32"])  { $modes["f16/f32"].runs }  else { "-" }
        $bf16f32Runs = if ($modes["bf16/f32"]) { $modes["bf16/f32"].runs } else { "-" }
        $s8s32Runs   = if ($modes["s8/s32"])   { $modes["s8/s32"].runs }   else { "-" }
        $dp4aRuns    = if ($modes["dp4a"])     { $modes["dp4a"].runs }     else { "-" }
        $ffmaRuns    = if ($modes["ffma"])     { $modes["ffma"].runs }     else { "-" }

        $compSection = if ($SaveAsBaseline) {
            "  Saved as Baseline Report ($fileName).`r`n  Run the benchmark again after booting via the Unlock USB stick to compare Before vs. After speedup."
        } elseif ($baselineObj) {
            $bF16  = $baselineObj.modes.'f16/f32'.best_tflops
            $bBf16 = $baselineObj.modes.'bf16/f32'.best_tflops
            "  Baseline Reference : $($baselineObj.FileName)`r`n" +
            ("  f16/f32  Throughput: {0,6:F1} TFLOPS (Before) -> {1,6:F1} TFLOPS (Current)  [{2:F2}x Speedup]`r`n" -f $bF16, $f16f32, $gainF16) +
            ("  bf16/f32 Throughput: {0,6:F1} TFLOPS (Before) -> {1,6:F1} TFLOPS (Current)  [{2:F2}x Speedup]" -f $bBf16, $bf16f32, $gainBf16)
        } else {
            "  No prior *-BASELINE.txt report found in benchmark-reports\."
        }

        $valSection = if ($valLog) {
            "  Status : $(if ($valPass) { 'PASSED (0 mismatches)' } else { 'FAILED' })`r`n" +
            (($valLog -split "`r?`n" | ForEach-Object { "  $_" }) -join "`r`n")
        } else {
            "  (Skipped in quick probe mode)"
        }

        $reportText = @"
================================================================================
  NVIDIA GeForce RTX 3000 (GA10x) & RTX 4000 (AD10x) Tensor Core Benchmark Report
================================================================================
Timestamp (Local) : $($nowLocal.ToString("yyyy-MM-dd HH:mm:ss"))
Timestamp (UTC)   : $($nowUtc.ToString("yyyy-MM-ddTHH:mm:ssZ"))
Report File       : $fileName
GPU Summary       : $(if ($gpuHeader) { $gpuHeader } else { "NVIDIA GeForce RTX GPU" })
Telemetry (SMI)   : $(if ($smiLine) { $smiLine } else { "N/A" })
Unlock Verdict    : $summary

--------------------------------------------------------------------------------
1. TENSOR CORE & FP32 INSTRUCTION THROUGHPUT (TFLOPS / TOPS)
--------------------------------------------------------------------------------
  Mode      | Unit / Accumulator Precision               | Best Rate      | All Repetitions
  --------- | ------------------------------------------ | -------------- | -------------------
  f16/f16   | FP16 Tensor Core (FP16 Accumulate - Stock) | $(($f16f16.ToString('F1', [Globalization.CultureInfo]::InvariantCulture) + ' TFLOPS').PadRight(14)) | $f16f16Runs
  f16/f32   | FP16 Tensor Core (FP32 Accumulate - SS0)   | $(($f16f32.ToString('F1', [Globalization.CultureInfo]::InvariantCulture) + ' TFLOPS').PadRight(14)) | $f16f32Runs
  bf16/f32  | BF16 Tensor Core (FP32 Accumulate - SS1)   | $(($bf16f32.ToString('F1', [Globalization.CultureInfo]::InvariantCulture) + ' TFLOPS').PadRight(14)) | $bf16f32Runs
  s8/s32    | INT8 Tensor Core (INT32 Accumulate)        | $(($s8s32.ToString('F1', [Globalization.CultureInfo]::InvariantCulture) + ' TOPS').PadRight(14)) | $s8s32Runs
  dp4a      | INT8 Dot-Product (dp4a.s32.s32)            | $(($dp4a.ToString('F1', [Globalization.CultureInfo]::InvariantCulture) + ' TOPS').PadRight(14)) | $dp4aRuns
  ffma      | FP32 CUDA Core Scalar FMA (fma.rn.f32)     | $(($ffma.ToString('F1', [Globalization.CultureInfo]::InvariantCulture) + ' TFLOPS').PadRight(14)) | $ffmaRuns

--------------------------------------------------------------------------------
2. SPEED-SELECT (SS0 / SS1) RATIO ANALYSIS
--------------------------------------------------------------------------------
  FP16/FP32 vs FP16/FP16 Ratio : $pctF16% ($f16Ratio)  [Expected: ~50% Locked, ~100% Unlocked]
  BF16/FP32 vs FP16/FP16 Ratio : $pctBf16% ($bf16Ratio)  [Expected: ~50% Locked, ~100% Unlocked]
  Current Boot State           : $stateStr

--------------------------------------------------------------------------------
3. BEFORE vs. AFTER COMPARISON
--------------------------------------------------------------------------------
$compSection

--------------------------------------------------------------------------------
4. NUMERICAL CORRECTNESS VALIDATION (cuBLAS GEMM vs CPU FP32 Reference)
--------------------------------------------------------------------------------
$valSection
================================================================================
"@
        Set-Content -Path $savedReportPath -Value $reportText -Encoding UTF8
        if ($SaveAsBaseline) {
            $baselineObj = [PSCustomObject]@{
                FileName = $fileName
                modes    = [PSCustomObject]@{
                    'f16/f16'  = [PSCustomObject]@{ best_tflops = $f16f16 }
                    'f16/f32'  = [PSCustomObject]@{ best_tflops = $f16f32 }
                    'bf16/f32' = [PSCustomObject]@{ best_tflops = $bf16f32 }
                }
            }
            $gainF16  = 1.0
            $gainBf16 = 1.0
        }
    }

    return [PSCustomObject]@{
        Available      = ($f16f16 -gt 0)
        State          = $stateStr
        SummaryText    = $summary
        IsUnlocked     = $isUnlocked
        F16F16Tflops   = $f16f16
        F16F32Tflops   = $f16f32
        Bf16F32Tflops  = $bf16f32
        S8S32Tops      = $s8s32
        Dp4aTops       = $dp4a
        FfmaTflops     = $ffma
        F16Ratio       = $f16Ratio
        Bf16Ratio      = $bf16Ratio
        ValidationPass = $valPass
        ValidationLog  = $valLog
        Baseline       = $baselineObj
        GainF16        = $gainF16
        GainBf16       = $gainBf16
        ReportFilePath = $savedReportPath
        RawOutput      = ($rawLines -join "`r`n")
    }
}

function Get-SystemHardwareReport {
    param(
        [string]$RepoRoot = $PSScriptRoot
    )

    $catalog = Get-SupportedGpuCatalog
    $checks  = New-Object System.Collections.Generic.List[object]
    $issues  = New-Object System.Collections.Generic.List[string]

    # 1. Query nvidia-smi if available for VBIOS, Driver, and BDF
    $smiMap = @{}
    $smiCmd = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
    if ($smiCmd) {
        try {
            $smiLines = & nvidia-smi --query-gpu=pci.bus_id,name,vbios_version,driver_version,memory.total,pci.sub_device_id --format=csv,noheader,nounits 2>$null
            foreach ($line in $smiLines) {
                $parts = $line -split ",\s*"
                if ($parts.Count -ge 5) {
                    $busKey = $parts[0].Trim()
                    if ($busKey -match '([0-9A-Fa-f]{2}):([0-9A-Fa-f]{2})\.([0-9A-Fa-f])') {
                        $normBdf = "{0:x2}:{1:x2}.{2:x1}" -f [Convert]::ToInt32($matches[1],16), [Convert]::ToInt32($matches[2],16), [Convert]::ToInt32($matches[3],16)
                        $smiMap[$normBdf] = @{
                            Name          = $parts[1].Trim()
                            VbiosVersion  = $parts[2].Trim()
                            DriverVersion = $parts[3].Trim()
                            VramMiB       = $parts[4].Trim()
                        }
                    }
                }
            }
        } catch {}
    }

    # 2. Enumerate all Display Adapters via WMI / PnP
    $allGpus = New-Object System.Collections.Generic.List[object]
    $compatibleGpus = New-Object System.Collections.Generic.List[object]
    $hasIgpu = $false

    $memMap = @{}
    try {
        foreach ($m in (Get-CimInstance Win32_DeviceMemoryAddress -ErrorAction SilentlyContinue)) {
            if ($null -ne $m.StartingAddress) {
                $memMap[[uint64]$m.StartingAddress] = $m
            }
        }
    } catch {}
    $allAllocRes = @(Get-CimInstance Win32_AllocatedResource -ErrorAction SilentlyContinue)

    $videoControllers = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
    foreach ($vc in $videoControllers) {
        $pnpId = "$($vc.PNPDeviceID)"
        $ven = ""; $dev = ""; $subsys = "00000000"; $rev = "00"
        if ($pnpId -match 'VEN_([0-9A-Fa-f]{4})&DEV_([0-9A-Fa-f]{4})') {
            $ven = $matches[1].ToUpper()
            $dev = $matches[2].ToUpper()
        }
        if ($pnpId -match 'SUBSYS_([0-9A-Fa-f]{8})') {
            $subsys = $matches[1].ToUpper()
        }
        if ($pnpId -match 'REV_([0-9A-Fa-f]{2})') {
            $rev = $matches[1].ToUpper()
        }

        if ($ven -in @("8086", "1002") -and $vc.Name -notmatch 'Radeon RX [6789]') {
            $hasIgpu = $true
        }

        # Locate PCI Location & BAR0
        $seg = 0; $bus = 1; $device = 0; $func = 0
        $bdfFound = $false
        if ($pnpId) {
            try {
                $locProp = Get-PnpDeviceProperty -InstanceId $pnpId -KeyName "DEVPKEY_Device_LocationInfo" -ErrorAction SilentlyContinue
                if ($locProp -and $locProp.Data -match 'bus\s+(\d+),\s*device\s+(\d+),\s*function\s+(\d+)') {
                    $bus = [int]$matches[1]
                    $device = [int]$matches[2]
                    $func = [int]$matches[3]
                    $bdfFound = $true
                }
            } catch {}
        }

        [uint64]$bar0Base = 0
        [uint64]$bar0Bytes = 0x1000000
        if ($pnpId -or $vc.DeviceID) {
            try {
                foreach ($ar in $allAllocRes) {
                    $depId = $ar.Dependent.CimInstanceProperties['DeviceID'].Value
                    $antStart = $ar.Antecedent.CimInstanceProperties['StartingAddress']
                    if (($depId -ieq $pnpId -or $depId -ieq $vc.DeviceID) -and $null -ne $antStart -and $null -ne $antStart.Value) {
                        [uint64]$sAddr = [uint64]$antStart.Value
                        $mem = $memMap[$sAddr]
                        if ($mem -and $null -ne $mem.EndingAddress) {
                            [uint64]$eAddr = [uint64]$mem.EndingAddress
                            [uint64]$len   = $eAddr - $sAddr + 1
                            if ($len -eq 0x1000000 -or ($len -gt 0x1000000 -and $len -lt 0x2000000 -and ($sAddr -band 0xFFFFFF) -eq 0)) {
                                $bar0Base = $sAddr
                                $bar0Bytes = 0x1000000
                                break
                            }
                        }
                    }
                }
            } catch {}
        }

        $normBdf = "{0:x2}:{1:x2}.{2:x1}" -f $bus, $device, $func
        $smiInfo = $smiMap[$normBdf]

        $catEntry = if ($ven -eq "10DE" -and $catalog.ContainsKey($dev)) { $catalog[$dev] } else { $null }
        $isCompatible = ($null -ne $catEntry)
        $compatReason = if ($isCompatible) {
            "Recognized $($catEntry.Series) ($($catEntry.Chip)); experimental unlock, hardware validation required"
        } elseif ($ven -eq "10DE") {
            if ($dev -match '^1[E|F]|^21') {
                "Unsupported Turing (RTX 2000 / GTX 1600) GPU - Only RTX 3000 (Ampere) and RTX 4000 (Ada) are supported"
            } elseif ($dev -match '^2[9|B|C]') {
                "Unsupported Blackwell (RTX 5000) GPU - Only RTX 3000 (Ampere) and RTX 4000 (Ada) are supported"
            } else {
                "NVIDIA Device 10DE:$dev is not a consumer GeForce RTX 3000/4000 target (professional cards already have full FP32 accumulate)"
            }
        } else {
            "Non-NVIDIA Display Adapter ($($vc.Name))"
        }

        $boardIdHex = if ($ven -and $dev) { "0x{0}{1}" -f $dev.ToLower(), $ven.ToLower() } else { "0x00000000" }
        $subsysHex  = "0x$($subsys.ToLower())"
        $chipIdVal  = if ($catEntry) {
            [uint32](($catEntry.DefaultChipId -band 0xFFFFFF00) -bor [Convert]::ToInt32($rev, 16))
        } else { 0 }
        $chipIdHex  = ("0x{0:x8}" -f $chipIdVal)

        $gpuObj = [PSCustomObject]@{
            Name           = if ($smiInfo) { $smiInfo.Name } else { $vc.Name }
            CatalogName    = if ($catEntry) { $catEntry.Name } else { $vc.Name }
            ChipFamily     = if ($catEntry) { $catEntry.Chip } else { "Unknown" }
            Series         = if ($catEntry) { $catEntry.Series } else { "Other" }
            Arch           = if ($catEntry) { $catEntry.Arch } else { "unknown" }
            PnpDeviceId    = $pnpId
            VendorId       = $ven
            DeviceId       = $dev
            BoardIdHex     = $boardIdHex
            SubsystemIdHex = $subsysHex
            ChipIdHex      = $chipIdHex
            Revision       = $rev
            Segment        = $seg
            Bus            = $bus
            Device         = $device
            Function       = $func
            BdfString      = ("{0:x4}:{1:x2}:{2:x2}.{3:x1}" -f $seg, $bus, $device, $func)
            BdfDetected    = $bdfFound
            Bar0Base       = $bar0Base
            Bar0BaseHex    = ("0x{0:x8}" -f $bar0Base)
            Bar0Bytes      = $bar0Bytes
            Bar0BytesHex   = ("0x{0:x8}" -f $bar0Bytes)
            VbiosVersion   = if ($smiInfo) { $smiInfo.VbiosVersion } else { "N/A (query at UEFI boot)" }
            DriverVersion  = if ($smiInfo) { $smiInfo.DriverVersion } else { $vc.DriverVersion }
            VramMiB        = if ($smiInfo) { $smiInfo.VramMiB } else { [math]::Round($vc.AdapterRAM / 1MB) }
            IsCompatible   = $isCompatible
            CompatReason   = $compatReason
            Status         = $vc.Status
        }
        $allGpus.Add($gpuObj)
        if ($isCompatible) {
            $compatibleGpus.Add($gpuObj)
        }
    }

    $liveUnlock = $null
    if ($compatibleGpus.Count -gt 0) {
        $primary = $compatibleGpus[0]
        $checks.Add([PSCustomObject]@{
            Category       = "GPU Hardware"
            Item           = "Target RTX 3000/4000 GPU"
            Status         = "PASS"
            Value          = "$($primary.Name) [$($primary.ChipFamily) | $($primary.BoardIdHex) | Subsys $($primary.SubsystemIdHex)]"
            Recommendation = $primary.CompatReason
        })
        $liveUnlock = Get-GpuLiveUnlockStatus -RepoRoot $RepoRoot -Iterations 2000 -Repetitions 1
        if ($liveUnlock.Available) {
            $checks.Add([PSCustomObject]@{
                Category       = "GPU Hardware"
                Item           = "Current Boot Lock/Unlock State"
                Status         = if ($liveUnlock.IsUnlocked) { "PASS" } else { "WARN" }
                Value          = $liveUnlock.SummaryText
                Recommendation = if ($liveUnlock.IsUnlocked) { "Full-rate FP16/BF16 -> FP32 Tensor Core FMA is currently ACTIVE on this boot!" } else { "GPU is currently in stock half-rate mode on this boot. Cold-shutdown and boot from the Unlock USB stick to unlock." }
            })
        }
        if ($primary.Bar0Base -gt 0 -and $primary.Bar0Bytes -eq 0x1000000) {
            $checks.Add([PSCustomObject]@{
                Category       = "GPU Hardware"
                Item           = "PCIe Location & BAR0 Aperture"
                Status         = "PASS"
                Value          = "BDF $($primary.BdfString) | BAR0 $($primary.Bar0BaseHex) (16 MiB)"
                Recommendation = "Valid 16 MiB BAR0 MMIO aperture detected."
            })
        } else {
            $checks.Add([PSCustomObject]@{
                Category       = "GPU Hardware"
                Item           = "PCIe Location & BAR0 Aperture"
                Status         = "WARN"
                Value          = "BDF $($primary.BdfString) | BAR0 $($primary.Bar0BaseHex)"
                Recommendation = "BAR0 base was not reported by WMI; CONFIG.INI will use bar0_base = any so UEFI discovers BAR0 dynamically."
            })
        }
    } else {
        $issues.Add("No compatible NVIDIA GeForce RTX 3000 (GA10x) or RTX 4000 (AD10x) GPU was detected on this machine.")
        $checks.Add([PSCustomObject]@{
            Category       = "GPU Hardware"
            Item           = "Target RTX 3000/4000 GPU"
            Status         = "WARN"
            Value          = "None detected locally ($($allGpus.Count) adapter(s) scanned)"
            Recommendation = "Use 'Universal Generic Mode' to build a USB stick for another RTX 3000/4000 PC."
        })
    }

    # 3. Motherboard, CPU, OS
    $board = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue | Select-Object -First 1
    $bios  = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue | Select-Object -First 1
    $cpu   = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    $os    = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue | Select-Object -First 1

    $cpuName = if ($cpu) { $cpu.Name.Trim() } else { "Unknown CPU" }
    if ($cpuName -match 'KF\b|F\b') {
        $hasIgpu = $false
    }

    $checks.Add([PSCustomObject]@{
        Category       = "Motherboard & CPU"
        Item           = "Host Platform"
        Status         = "PASS"
        Value          = "$($board.Manufacturer) $($board.Product) (BIOS $($bios.SMBIOSBIOSVersion)) | $cpuName"
        Recommendation = if ($hasIgpu) { "CPU/Platform has secondary/iGPU display adapter." } else { "No iGPU detected (dGPU drives display); GOP reconnect + headless fallback enabled." }
    })

    # 4. Secure Boot Check
    $secureBoot = "Unknown"
    try {
        $sbVal = Confirm-SecureBootUEFI -ErrorAction Stop
        $secureBoot = if ($sbVal) { "Enabled" } else { "Disabled" }
    } catch {
        try {
            $regSb = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State" -Name "UEFISecureBootEnabled" -ErrorAction Stop
            $secureBoot = if ($regSb.UEFISecureBootEnabled -eq 1) { "Enabled" } else { "Disabled" }
        } catch {
            $secureBoot = "Unsupported/Legacy"
        }
    }

    if ($secureBoot -eq "Disabled") {
        $checks.Add([PSCustomObject]@{
            Category       = "UEFI & Boot"
            Item           = "UEFI Secure Boot"
            Status         = "PASS"
            Value          = "Disabled"
            Recommendation = "Ready to boot unsigned custom UEFI unlocker."
        })
    } elseif ($secureBoot -eq "Enabled") {
        $issues.Add("UEFI Secure Boot is currently ENABLED. You must disable Secure Boot in your motherboard BIOS before booting the USB stick.")
        $checks.Add([PSCustomObject]@{
            Category       = "UEFI & Boot"
            Item           = "UEFI Secure Boot"
            Status         = "FAIL"
            Value          = "Enabled (Blocks unsigned .EFI)"
            Recommendation = "Disable Secure Boot in BIOS settings before booting the USB stick."
        })
    } else {
        $checks.Add([PSCustomObject]@{
            Category       = "UEFI & Boot"
            Item           = "UEFI Secure Boot"
            Status         = "WARN"
            Value          = $secureBoot
            Recommendation = "Ensure motherboard is in UEFI mode with Secure Boot Disabled."
        })
    }

    # 5. Fast Startup (Hiberboot) Check
    $fastStartup = "Unknown"
    try {
        $hb = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -ErrorAction Stop
        $fastStartup = if ($hb.HiberbootEnabled -eq 1) { "Enabled" } else { "Disabled" }
    } catch {}

    if ($fastStartup -eq "Disabled") {
        $checks.Add([PSCustomObject]@{
            Category       = "UEFI & Boot"
            Item           = "Windows Fast Startup"
            Status         = "PASS"
            Value          = "Disabled"
            Recommendation = "Standard shutdown performs a full cold boot."
        })
    } else {
        $checks.Add([PSCustomObject]@{
            Category       = "UEFI & Boot"
            Item           = "Windows Fast Startup"
            Status         = "WARN"
            Value          = "$fastStartup"
            Recommendation = "Use 'shutdown /s /f /t 0' or disable Fast Startup so the GPU powers down completely (WPR2 reset) before USB boot."
        })
    }

    # 6. Windows EFI System Partition (ESP) Discovery
    $espPartGuidString = "00000000-0000-0000-0000-000000000000"
    $espPartNumber = 0
    [uint64]$espStartLba = 0
    [uint64]$espSizeLba  = 0
    $espDiskNumber = -1
    $espDiskModel  = "Unknown"
    $espFound      = $false

    try {
        $espPart = Get-Partition | Where-Object { $_.GptType -eq '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' } | Select-Object -First 1
        if ($espPart) {
            $espFound          = $true
            $espPartGuidString = $espPart.Guid.Trim('{}').ToLower()
            $espPartNumber     = [int]$espPart.PartitionNumber
            $espStartLba       = [uint64]($espPart.Offset / 512)
            $espSizeLba        = [uint64]($espPart.Size / 512)
            $espDiskNumber     = [int]$espPart.DiskNumber
            $diskObj           = Get-Disk -Number $espDiskNumber -ErrorAction SilentlyContinue
            if ($diskObj) { $espDiskModel = $diskObj.FriendlyName }
        }
    } catch {}

    if ($espFound) {
        $checks.Add([PSCustomObject]@{
            Category       = "UEFI & Boot"
            Item           = "Windows 10/11 EFI System Partition"
            Status         = "PASS"
            Value          = "Disk $espDiskNumber ($espDiskModel) Part $espPartNumber | GUID $espPartGuidString"
            Recommendation = "LBA Start $espStartLba, Size $espSizeLba sectors."
        })
    } else {
        $issues.Add("Could not auto-detect a GPT EFI System Partition on internal disks.")
        $checks.Add([PSCustomObject]@{
            Category       = "UEFI & Boot"
            Item           = "Windows 10/11 EFI System Partition"
            Status         = "WARN"
            Value          = "Not detected via Get-Partition"
            Recommendation = "CONFIG.INI will set windows_esp_guid = auto so UEFI locates bootmgfw.efi automatically."
        })
    }

    # 7. Firmware Assets & Compiled EFI Binaries Check
    $manifestPath = Join-Path $RepoRoot "firmware-manifest.json"
    $assetsDir    = Join-Path $RepoRoot "usb-package\RTX4090-PREP\ASSETS"
    $efiDir       = Join-Path $RepoRoot "usb-package\EFI\BOOT"
    $assetCount   = 0
    $assetExpected = 9
    $assetsOk     = $true

    if (Test-Path $manifestPath) {
        $pins = Get-Content $manifestPath -Raw | ConvertFrom-Json
        foreach ($prop in $pins.PSObject.Properties) {
            $fPath = Join-Path $assetsDir $prop.Name
            if ((Test-Path $fPath) -and ((Get-Item $fPath).Length -eq $prop.Value.bytes)) {
                $assetCount++
            } else {
                $assetsOk = $false
            }
        }
    } else {
        $assetsOk = $false
    }

    $efiFiles = @("BOOTX64.EFI", "UNLOCK-MANUAL.EFI", "UNLOCK-AUTO.EFI", "PROBE-READONLY.EFI")
    $efiOk = $true
    foreach ($ef in $efiFiles) {
        if (-not (Test-Path (Join-Path $efiDir $ef))) { $efiOk = $false }
    }

    if ($assetsOk -and $efiOk) {
        $checks.Add([PSCustomObject]@{
            Category       = "Package Integrity"
            Item           = "UEFI Loaders & AD10x/GA10x Firmware"
            Status         = "PASS"
            Value          = "4 EFI binaries + $assetCount/$assetExpected NVIDIA 610.43.03 assets ready"
            Recommendation = "Both RTX 3000 (GA10x) and RTX 4000 (AD10x) firmware sets are staged in usb-package\."
        })
    } else {
        $issues.Add("usb-package is missing compiled EFI binaries or firmware assets ($assetCount/$assetExpected). Run 'python build.py'.")
        $checks.Add([PSCustomObject]@{
            Category       = "Package Integrity"
            Item           = "UEFI Loaders & AD10x/GA10x Firmware"
            Status         = "FAIL"
            Value          = "EFI OK: $efiOk | Assets: $assetCount/$assetExpected"
            Recommendation = "Run 'python build.py' to compile EFI loaders and stage firmware assets."
        })
    }

    return [PSCustomObject]@{
        TimestampUtc   = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        OS             = [PSCustomObject]@{
            Caption        = if ($os) { $os.Caption } else { "Windows" }
            Version        = if ($os) { $os.Version } else { "" }
            BuildNumber    = if ($os) { $os.BuildNumber } else { "" }
            SecureBoot     = $secureBoot
            FastStartup    = $fastStartup
        }
        Motherboard    = [PSCustomObject]@{
            Manufacturer   = if ($board) { $board.Manufacturer } else { "" }
            Product        = if ($board) { $board.Product } else { "" }
            BiosVersion    = if ($bios)  { $bios.SMBIOSBIOSVersion } else { "" }
            CpuName        = $cpuName
            HasIgpu        = $hasIgpu
        }
        WindowsEsp     = [PSCustomObject]@{
            Found           = $espFound
            DiskNumber      = $espDiskNumber
            DiskModel       = $espDiskModel
            PartitionNumber = $espPartNumber
            Guid            = $espPartGuidString
            StartLba        = $espStartLba
            SizeLba         = $espSizeLba
        }
        AllGpus          = $allGpus
        CompatibleGpus   = $compatibleGpus
        PrimaryGpu       = if ($compatibleGpus.Count -gt 0) { $compatibleGpus[0] } else { $null }
        LiveUnlockStatus = $liveUnlock
        Checks           = $checks
        Issues           = $issues
    }
}

function New-UnlockConfigIniText {
    param(
        [Parameter(Mandatory = $false)] $Gpu,
        [Parameter(Mandatory = $false)] $Esp,
        [ValidateSet("manual", "auto")] [string]$Mode = "manual",
        [int]$CountdownSeconds = 5,
        [bool]$UniversalGeneric = $false,
        [bool]$StrictBoard = $true,
        [bool]$StrictSubsystem = $true,
        [bool]$StrictChip = $true,
        [bool]$StrictBdf = $false,
        [bool]$StrictBar0 = $false,
        [bool]$StrictEsp = $false,
        [bool]$AllowHeadlessHandoff = $true,
        [bool]$SavePromDump = $true
    )

    if ($UniversalGeneric -or ($null -eq $Gpu)) {
        return @"
# ==============================================================================
# RTX 3000 (Ampere GA10x) & RTX 4000 (Ada AD10x) UEFI Unlocker
# Universal Generic Configuration (\RTX4090-PREP\CONFIG.INI)
# Generated: $((Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"))
# ==============================================================================
# Auto-discovers any supported NVIDIA GeForce RTX 3000 Series (GA102..GA107)
# or RTX 4000 Series (AD102..AD107) GPU and any Windows 10/11 ESP at boot.

mode = $Mode
countdown = $CountdownSeconds

arch = auto
board_id = any
subsystem_id = any
chip_id = any
pci_segment = any
pci_bus = any
pci_device = any
pci_function = any
bar0_base = any

strict_board = 0
strict_subsystem = 0
strict_chip = 0
strict_bdf = 0
strict_bar0 = 0
strict_esp = 0

allow_headless_handoff = $(if ($AllowHeadlessHandoff) { 1 } else { 0 })
save_prom_dump = $(if ($SavePromDump) { 1 } else { 0 })

windows_esp_guid = auto
windows_esp_partition = auto
windows_esp_start_lba = auto
windows_esp_size_lba = auto
"@
    }

    $espGuidStr  = if ($Esp -and $Esp.Found -and $Esp.Guid -ne "00000000-0000-0000-0000-000000000000") { $Esp.Guid } else { "auto" }
    $espPartStr  = if ($Esp -and $Esp.Found -and $Esp.PartitionNumber -gt 0) { $Esp.PartitionNumber } else { "auto" }
    $espStartStr = if ($Esp -and $Esp.Found -and $Esp.StartLba -gt 0) { $Esp.StartLba } else { "auto" }
    $espSizeStr  = if ($Esp -and $Esp.Found -and $Esp.SizeLba -gt 0)  { $Esp.SizeLba } else { "auto" }
    $bar0Str     = if ($Gpu.Bar0Base -gt 0) { $Gpu.Bar0BaseHex } else { "any" }

    return @"
# ==============================================================================
# RTX 3000 (Ampere GA10x) & RTX 4000 (Ada AD10x) UEFI Unlocker
# Tailored Hardware Configuration (\RTX4090-PREP\CONFIG.INI)
# Generated: $((Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"))
# Target GPU: $($Gpu.Name) ($($Gpu.ChipFamily) - $($Gpu.Series))
# ==============================================================================

mode = $Mode
countdown = $CountdownSeconds

# Target GPU Identity & Architecture (ada = RTX 4000, ampere = RTX 3000):
arch = $($Gpu.Arch)
board_id = $($Gpu.BoardIdHex)
subsystem_id = $($Gpu.SubsystemIdHex)
chip_id = $($Gpu.ChipIdHex)
pci_segment = $($Gpu.Segment)
pci_bus = $($Gpu.Bus)
pci_device = $($Gpu.Device)
pci_function = $($Gpu.Function)
bar0_base = $bar0Str

# Validation Strictness Flags (1 = enforce exact match, 0 = allow dynamic fallback):
strict_board = $(if ($StrictBoard) { 1 } else { 0 })
strict_subsystem = $(if ($StrictSubsystem) { 1 } else { 0 })
strict_chip = $(if ($StrictChip) { 1 } else { 0 })
strict_bdf = $(if ($StrictBdf) { 1 } else { 0 })
strict_bar0 = $(if ($StrictBar0 -and $Gpu.Bar0Base -gt 0) { 1 } else { 0 })
strict_esp = $(if ($StrictEsp -and $espGuidStr -ne "auto") { 1 } else { 0 })

# Display Reconnect & Diagnostics:
allow_headless_handoff = $(if ($AllowHeadlessHandoff) { 1 } else { 0 })
save_prom_dump = $(if ($SavePromDump) { 1 } else { 0 })

# Target Windows 10/11 EFI System Partition (ESP):
windows_esp_guid = $espGuidStr
windows_esp_partition = $espPartStr
windows_esp_start_lba = $espStartStr
windows_esp_size_lba = $espSizeStr
"@
}

function Test-ConfigIniCompatibility {
    param(
        [Parameter(Mandatory = $true)] [string]$IniText,
        [Parameter(Mandatory = $false)] $HardwareReport
    )

    $catalog = Get-SupportedGpuCatalog
    $errors   = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]
    $parsed   = @{}

    $validKeys = @(
        "mode", "countdown", "countdown_sec", "arch", "series", "board_id", "subsystem_id", "chip_id",
        "pci_segment", "pci_bus", "pci_device", "pci_function", "bar0_base", "bar0_bytes",
        "strict_board", "strict_subsystem", "strict_chip", "strict_bdf", "strict_bar0", "strict_esp",
        "allow_headless_handoff", "save_prom_dump",
        "windows_esp_guid", "windows_esp_partition", "windows_esp_start_lba", "windows_esp_size_lba",
        "esp_guid", "esp_part", "esp_start_lba", "esp_size_lba"
    )

    $lineNum = 0
    foreach ($rawLine in ($IniText -split "`r?`n")) {
        $lineNum++
        $clean = ($rawLine -replace '[#;].*$', '').Trim()
        if (-not $clean) { continue }
        if ($clean -notmatch '^([A-Za-z0-9_]+)\s*=\s*(.+)$') {
            $errors.Add("Line ${lineNum}: Malformed key=value syntax: '$clean'")
            continue
        }
        $k = $matches[1].ToLower()
        $v = $matches[2].Trim()
        if ($k -notin $validKeys) {
            $warnings.Add("Line ${lineNum}: Unrecognized configuration key '$k'")
        }
        $parsed[$k] = $v
    }

    if ($parsed.ContainsKey("mode") -and $parsed["mode"].ToLower() -notin @("manual", "auto", "automatic")) {
        $errors.Add("Invalid mode '$($parsed["mode"])' (must be 'manual' or 'auto').")
    }
    if ($parsed.ContainsKey("countdown")) {
        $cd = 0
        if (-not [int]::TryParse($parsed["countdown"], [ref]$cd) -or $cd -lt 1 -or $cd -gt 60) {
            $errors.Add("Invalid countdown '$($parsed["countdown"])' (must be 1..60 seconds).")
        }
    }
    if ($parsed.ContainsKey("board_id") -and $parsed["board_id"].ToLower() -notin @("any", "auto")) {
        if ($parsed["board_id"] -match '^0x([0-9A-Fa-f]{4})([0-9A-Fa-f]{4})$') {
            $devHex = $matches[1].ToUpper()
            $venHex = $matches[2].ToUpper()
            if ($venHex -ne "10DE") {
                $errors.Add("board_id '$($parsed["board_id"])' does not have NVIDIA Vendor ID 10de.")
            } elseif (-not $catalog.ContainsKey($devHex)) {
                $warnings.Add("board_id '$($parsed["board_id"])' (Device 0x$devHex) is not in the standard RTX 3000/4000 catalog.")
            } elseif ($HardwareReport -and $HardwareReport.PrimaryGpu) {
                $localBoard = $HardwareReport.PrimaryGpu.BoardIdHex.ToLower()
                if ($parsed["board_id"].ToLower() -ne $localBoard -and $parsed["strict_board"] -ne "0") {
                    $warnings.Add("board_id '$($parsed["board_id"])' differs from this PC's detected GPU ($localBoard).")
                }
            }
        } else {
            $errors.Add("Invalid board_id '$($parsed["board_id"])' (expected 0xXXXX10de or 'any').")
        }
    }
    if ($parsed.ContainsKey("windows_esp_guid") -and $parsed["windows_esp_guid"].ToLower() -notin @("auto", "any")) {
        $g = [Guid]::Empty
        if (-not [Guid]::TryParse($parsed["windows_esp_guid"], [ref]$g)) {
            $errors.Add("Invalid windows_esp_guid '$($parsed["windows_esp_guid"])' (expected UUID format or 'auto').")
        }
    }

    return [PSCustomObject]@{
        IsValid  = ($errors.Count -eq 0)
        Errors   = $errors
        Warnings = $warnings
        Parsed   = $parsed
    }
}

function Test-EfiApplicationBytes {
    param([byte[]]$Bytes)
    try {
        if ($Bytes.Length -lt 256 -or $Bytes[0] -ne 0x4d -or $Bytes[1] -ne 0x5a) { return $false }
        $pe = [BitConverter]::ToUInt32($Bytes, 60)
        if ($pe -gt $Bytes.Length - 256) { return $false }
        if ([BitConverter]::ToUInt32($Bytes, $pe) -ne 0x4550) { return $false }
        if ([BitConverter]::ToUInt16($Bytes, $pe + 4) -ne 0x8664) { return $false }
        if ([BitConverter]::ToUInt16($Bytes, $pe + 24) -ne 0x20b) { return $false }
        if ([BitConverter]::ToUInt16($Bytes, $pe + 92) -ne 10) { return $false }
        return $true
    } catch { return $false }
}

function Get-NativeVolumeFileSystem {
    param([Parameter(Mandatory = $true)][string]$DriveLetter)
    if (-not ('GpuUsb.NativeVolume' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
namespace GpuUsb {
    public static class NativeVolume {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetVolumeInformationW(
            string root, StringBuilder label, uint labelLength, out uint serial,
            out uint maxComponentLength, out uint flags, StringBuilder fileSystem,
            uint fileSystemLength);
    }
}
'@
    }
    $letter = $DriveLetter.Trim().TrimEnd(':')
    if ($letter -notmatch '^[A-Za-z]$') { throw 'Invalid volume drive letter.' }
    $label = New-Object Text.StringBuilder 261
    $format = New-Object Text.StringBuilder 261
    [uint32]$serial = 0; [uint32]$maxComponent = 0; [uint32]$flags = 0
    $ok = [GpuUsb.NativeVolume]::GetVolumeInformationW("${letter}:\", $label, 261,
        [ref]$serial, [ref]$maxComponent, [ref]$flags, $format, 261)
    if (-not $ok) {
        $code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "GetVolumeInformationW for ${letter}: failed (Windows error $code): $([ComponentModel.Win32Exception]::new($code).Message)"
    }
    return $format.ToString().Trim().ToUpperInvariant()
}

function Get-VolumeFileSystemName {
    param([Parameter(Mandatory = $true)]$Volume, [ref]$Diagnostic)
    if ($Diagnostic) { $Diagnostic.Value = '' }
    # MSFT_Volume exposes FileSystemType; FileSystem is only available on some
    # PowerShell projections. Never interpret a missing property as a format.
    foreach ($property in 'FileSystemType', 'FileSystem') {
        $value = "$($Volume.$property)".Trim().ToUpperInvariant()
        if ($value -in @('FAT32', 'FAT', 'FAT16', 'NTFS', 'EXFAT', 'REFS', 'UDF', 'CDFS')) { return $value }
    }
    $letter = "$($Volume.DriveLetter)".Trim().TrimEnd(':')
    if ($letter -match '^[A-Za-z]$') {
        try {
            $nativeFormat = Get-NativeVolumeFileSystem -DriveLetter $letter
            if ($nativeFormat) { return $nativeFormat }
        } catch {
            if ($Diagnostic) { $Diagnostic.Value = $_.Exception.Message }
            Write-Warning "Filesystem query: $($_.Exception.Message)"
        }
        try {
            $driveInfo = New-Object System.IO.DriveInfo("${letter}:\")
            if ($driveInfo.IsReady) { return $driveInfo.DriveFormat.Trim().ToUpperInvariant() }
        } catch {}
        try {
            $logicalDisk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='${letter}:'" -ErrorAction Stop
            $format = "$($logicalDisk.FileSystem)".Trim().ToUpperInvariant()
            if ($format) { return $format }
        } catch {}
    }
    return 'UNKNOWN'
}

function Assert-StagingTarget {
    param([string]$DriveLetter = '', [string]$FolderPath = '', [string]$RepoRoot = $PSScriptRoot)
    if ($DriveLetter -and $FolderPath) { throw 'Specify a drive OR a folder, not both.' }
    if ($FolderPath) {
        $target = [IO.Path]::GetFullPath($FolderPath).TrimEnd('\')
        $repo = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\')
        $source = Join-Path $repo 'usb-package'
        if ($target -eq $repo -or $target -eq $source -or $target.StartsWith($source + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Choose a separate output folder outside usb-package and different from the application root.'
        }
        if ($target -eq [IO.Path]::GetPathRoot($target).TrimEnd('\')) { throw 'Use drive staging for a drive root.' }
        return
    }
    $letter = $DriveLetter.Trim().TrimEnd(':').ToUpperInvariant()
    if ($letter -notmatch '^[A-Z]$') { throw 'Provide a single target drive letter.' }
    if ($letter -eq $env:SystemDrive.TrimEnd(':').ToUpperInvariant()) { throw 'Refusing to overwrite the system drive.' }
    $volume = Get-Volume -DriveLetter $letter -ErrorAction Stop
    $partition = Get-Partition -DriveLetter $letter -ErrorAction Stop
    $disk = Get-Disk -Number $partition.DiskNumber -ErrorAction Stop
    if ($disk.IsBoot -or $disk.IsSystem) { throw 'Refusing to overwrite a system/boot disk.' }
    $diagnostic = ''
    $fileSystem = Get-VolumeFileSystemName -Volume $volume -Diagnostic ([ref]$diagnostic)
    if ($fileSystem -eq 'UNKNOWN') { throw "Cannot determine target filesystem. $diagnostic" }
    if ($fileSystem -ne 'FAT32') { throw "Target must be FAT32 (detected $fileSystem)." }
    $required = (Get-ChildItem (Join-Path $RepoRoot 'usb-package') -File -Recurse | Measure-Object Length -Sum).Sum
    if ($volume.SizeRemaining -lt ($required + 1MB)) { throw 'Insufficient free space for a complete package copy.' }
}

function Get-UsbDriveInventory {
    param(
        [Alias("IncludeNonRemovable")]
        [switch]$IncludeFixedNonSystem
    )

    $drives = New-Object System.Collections.Generic.List[object]
    $sysDrive = $env:SystemDrive.TrimEnd(':').ToUpper()

    try {
        $volumes = @(Get-Volume -ErrorAction Stop | Where-Object { $_.DriveLetter -ne $null } | Sort-Object DriveLetter)
    } catch {
        Write-Warning "USB discovery unavailable: $($_.Exception.Message). Use an elevated PowerShell session to inspect disks."
        return
    }
    foreach ($vol in $volumes) {
        $letter = "$($vol.DriveLetter)".ToUpper()
        if ($letter -eq $sysDrive) { continue }

        $part = Get-Partition -DriveLetter $letter -ErrorAction SilentlyContinue
        $disk = if ($part) { Get-Disk -Number $part.DiskNumber -ErrorAction SilentlyContinue } else { $null }

        $isSystemOrBoot = if ($disk) { ($disk.IsBoot -or $disk.IsSystem) } else { ($letter -eq 'C') }
        if ($isSystemOrBoot) { continue }

        $busType = if ($disk) { "$($disk.BusType)" } else { "Unknown" }
        $isUsbOrRemovable = ($vol.DriveType -eq "Removable") -or ($busType -eq "USB")
        if (-not $isUsbOrRemovable -and -not $IncludeFixedNonSystem) {
            continue
        }

        $sizeMB = [math]::Round($vol.Size / 1MB, 1)
        $freeMB = [math]::Round($vol.SizeRemaining / 1MB, 1)
        $fsDiagnostic = ''
        $fs     = Get-VolumeFileSystemName -Volume $vol -Diagnostic ([ref]$fsDiagnostic)
        $partStyle = if ($disk) { "$($disk.PartitionStyle)" } else { "Unknown" }
        $model  = if ($disk) { $disk.FriendlyName } else { $vol.FileSystemLabel }

        $hasUnlocker = (Test-Path "${letter}:\EFI\BOOT\BOOTX64.EFI") -and (Test-Path "${letter}:\RTX4090-PREP\CONFIG.INI")
        $readyToStage = ($fs -eq "FAT32") -and ($freeMB -ge 100 -or ($hasUnlocker -and $freeMB -ge 10))
        $statusNote = if ($fs -eq 'UNKNOWN') {
            "Filesystem unavailable: $fsDiagnostic"
        } elseif ($fs -ne "FAT32") {
            "Formatted as $fs (Must be FAT32 for UEFI boot)"
        } elseif (-not $readyToStage) {
            "Insufficient free space ($freeMB MB free, need ~90 MB)"
        } elseif ($hasUnlocker) {
            "FAT32 Ready (Existing GPU Unlocker detected)"
        } else {
            "FAT32 Ready ($freeMB MB free)"
        }

        $drives.Add([PSCustomObject]@{
            DriveLetter      = "${letter}:"
            CleanLetter      = $letter
            Label            = $vol.FileSystemLabel
            DiskNumber       = if ($disk) { $disk.Number } else { -1 }
            DiskModel        = $model
            BusType          = $busType
            DriveType        = $vol.DriveType
            PartitionStyle   = $partStyle
            FileSystem       = $fs
            FileSystemDiagnostic = $fsDiagnostic
            SizeMB           = $sizeMB
            FreeMB           = $freeMB
            IsUsbOrRemovable = $isUsbOrRemovable
            HasUnlocker      = $hasUnlocker
            ReadyToStage     = $readyToStage
            StatusNote       = $statusNote
            DisplayText      = "${letter}: [$model] - $fs ($freeMB MB free / $sizeMB MB) - $statusNote"
        })
    }
    return $drives
}

function Test-StagedUsbIntegrity {
    param(
        [Parameter(Mandatory = $false)] [string]$DriveLetter = "",
        [Parameter(Mandatory = $false)] [string]$FolderPath = "",
        [string]$RepoRoot = $PSScriptRoot,
        $HardwareReport = $null
    )

    $checks = New-Object System.Collections.Generic.List[object]
    $allPassed = $true

    if ($FolderPath) {
        $root = $FolderPath
        if (-not (Test-Path $root)) {
            throw "Folder '$root' does not exist."
        }
        $checks.Add([PSCustomObject]@{ Item = "Package Directory"; Status = "PASS"; Detail = "Local staging folder: $root" })
    } else {
        $clean = $DriveLetter.Trim().TrimEnd(':').ToUpper()
        $root  = "${clean}:\"
        if (-not (Test-Path $root)) {
            throw "Drive $root is not accessible."
        }
        $vol = Get-Volume -DriveLetter $clean -ErrorAction Stop
        $fileSystem = Get-VolumeFileSystemName -Volume $vol
        if ($fileSystem -eq "FAT32") {
            $checks.Add([PSCustomObject]@{ Item = "USB File System"; Status = "PASS"; Detail = "FAT32 (Volume '$($vol.FileSystemLabel)')" })
        } else {
            $allPassed = $false
            $checks.Add([PSCustomObject]@{ Item = "USB File System"; Status = "FAIL"; Detail = "$fileSystem (FAT32 required; UNKNOWN means detection failed)" })
        }
    }

    # Verify EFI Loaders
    $efiList = @("EFI\BOOT\BOOTX64.EFI", "EFI\BOOT\UNLOCK-MANUAL.EFI", "EFI\BOOT\UNLOCK-AUTO.EFI", "EFI\BOOT\PROBE-READONLY.EFI")
    foreach ($rel in $efiList) {
        $p = Join-Path $root $rel
        if (Test-Path $p) {
            $bytes = [System.IO.File]::ReadAllBytes($p)
            $isMz = Test-EfiApplicationBytes -Bytes $bytes
            $hash = (Get-FileHash -Path $p -Algorithm SHA256).Hash.ToLower().Substring(0, 16)
            if ($isMz) {
                $checks.Add([PSCustomObject]@{ Item = $rel; Status = "PASS"; Detail = "$($bytes.Length) bytes | PE/COFF OK | SHA256 $hash..." })
            } else {
                $allPassed = $false
                $checks.Add([PSCustomObject]@{ Item = $rel; Status = "FAIL"; Detail = "Invalid PE/COFF header" })
            }
        } else {
            $allPassed = $false
            $checks.Add([PSCustomObject]@{ Item = $rel; Status = "FAIL"; Detail = "Missing on USB" })
        }
    }

    # Verify CONFIG.INI
    $cfgPath = Join-Path $root "RTX4090-PREP\CONFIG.INI"
    if (Test-Path $cfgPath) {
        $iniText = Get-Content $cfgPath -Raw
        $cfgRes = Test-ConfigIniCompatibility -IniText $iniText -HardwareReport $HardwareReport
        if ($cfgRes.IsValid) {
            $modeStr = $cfgRes.Parsed["mode"]
            $archStr = $cfgRes.Parsed["arch"]
            $boardStr = $cfgRes.Parsed["board_id"]
            $warnSuffix = if ($cfgRes.Warnings.Count -gt 0) { " (Warnings: $($cfgRes.Warnings -join '; '))" } else { "" }
            $checks.Add([PSCustomObject]@{
                Item   = "RTX4090-PREP\CONFIG.INI"
                Status = if ($cfgRes.Warnings.Count -gt 0) { "WARN" } else { "PASS" }
                Detail = "mode=$modeStr, arch=$archStr, board_id=$boardStr$warnSuffix"
            })
        } else {
            $allPassed = $false
            $checks.Add([PSCustomObject]@{
                Item   = "RTX4090-PREP\CONFIG.INI"
                Status = "FAIL"
                Detail = ($cfgRes.Errors -join "; ")
            })
        }
    } else {
        $allPassed = $false
        $checks.Add([PSCustomObject]@{ Item = "RTX4090-PREP\CONFIG.INI"; Status = "FAIL"; Detail = "Missing on USB" })
    }

    # Verify all 9 AD102 + GA102 firmware assets
    $manifestPath = Join-Path $RepoRoot "firmware-manifest.json"
    if (Test-Path $manifestPath) {
        $pins = Get-Content $manifestPath -Raw | ConvertFrom-Json
        foreach ($prop in $pins.PSObject.Properties) {
            $name = $prop.Name
            $expBytes = [int64]$prop.Value.bytes
            $expHash  = "$($prop.Value.sha256)".ToLower()
            $usbAsset = Join-Path $root "RTX4090-PREP\ASSETS\$name"
            if (-not (Test-Path $usbAsset)) {
                $allPassed = $false
                $checks.Add([PSCustomObject]@{ Item = "ASSETS\$name"; Status = "FAIL"; Detail = "Missing on USB" })
                continue
            }
            $len = (Get-Item $usbAsset).Length
            $actHash = (Get-FileHash -Path $usbAsset -Algorithm SHA256).Hash.ToLower()
            if ($len -eq $expBytes -and $actHash -eq $expHash) {
                $checks.Add([PSCustomObject]@{ Item = "ASSETS\$name"; Status = "PASS"; Detail = "$len bytes | SHA256 $($actHash.Substring(0,16))..." })
            } else {
                $allPassed = $false
                $checks.Add([PSCustomObject]@{ Item = "ASSETS\$name"; Status = "FAIL"; Detail = "Size/SHA256 mismatch ($len B, got $($actHash.Substring(0,16)))" })
            }
        }
    }

    if (-not (Test-Path $manifestPath)) {
        $allPassed = $false
        $checks.Add([PSCustomObject]@{ Item = "Firmware manifest"; Status = "FAIL"; Detail = "firmware-manifest.json missing" })
    }
    return [PSCustomObject]@{
        DriveLetter = "${clean}:"
        AllPassed   = $allPassed
        Checks      = $checks
    }
}
