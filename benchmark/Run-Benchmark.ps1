#Requires -Version 5.1
<#
.SYNOPSIS
    Runs the NVIDIA GeForce RTX 3000 (GA10x) & RTX 4000 (AD10x) numerical GEMM validation
    and Tensor Core instruction issue-rate benchmark, detects whether the FP16/BF16 Tensor Core
    FMA (with FP32 accumulate) speed-select unlock is active, compares Before vs. After,
    and saves a human-readable timestamped report in benchmark-reports\.
.PARAMETER SaveAsBaseline
    If set, marks the timestamped report in benchmark-reports\ as a *-BASELINE.txt report
    for Before vs. After comparisons.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$SaveAsBaseline
)

$ErrorActionPreference = "Stop"
$BenchDir = $PSScriptRoot
$RepoRoot = Split-Path -Parent $BenchDir
. (Join-Path $RepoRoot "HardwareDiscovery.ps1")

$MmaExe = Join-Path $BenchDir "mma_bench.exe"
$ValExe = Join-Path $BenchDir "validate_gemm.exe"

if (-not (Test-Path $MmaExe) -or -not (Test-Path $ValExe)) {
    Write-Host "Benchmark binaries not found; compiling now..." -ForegroundColor Yellow
    & (Join-Path $BenchDir "Build-Benchmark.ps1")
}

Write-Host "Running CUDA Numerical Validation (validate_gemm.exe) + Sustained Tensor Core Benchmark (mma_bench.exe 20000 3)..." -ForegroundColor Cyan
$res = Get-GpuLiveUnlockStatus -RepoRoot $RepoRoot -Iterations 20000 -Repetitions 3 -RunValidation -SaveReport -SaveAsBaseline:$SaveAsBaseline

if ($res.ReportFilePath -and (Test-Path $res.ReportFilePath)) {
    $reportText = Get-Content -Path $res.ReportFilePath -Raw
    Write-Host ""
    Write-Host $reportText
    Write-Host "Saved human-readable benchmark report to: $($res.ReportFilePath)" -ForegroundColor Green
} else {
    throw "Benchmark execution failed: $($res.SummaryText)"
}

if (-not $res.Available -or -not $res.ValidationPass -or $res.State -eq "ERROR") {
    throw "Benchmark or numerical validation failed: $($res.ValidationLog)"
}
