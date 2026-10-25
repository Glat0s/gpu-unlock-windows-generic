#Requires -Version 5.1
<#
.SYNOPSIS
    Compiles mma_bench.exe and validate_gemm.exe for RTX 4090 (sm_89) on Windows.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$BenchDir = $PSScriptRoot

# Locate nvcc.exe
$nvccCmd = Get-Command nvcc.exe -ErrorAction SilentlyContinue
if ($nvccCmd) {
    $nvcc = $nvccCmd.Source
} else {
    $cudaDirs = Get-ChildItem "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
    foreach ($d in $cudaDirs) {
        $cand = Join-Path $d.FullName "bin\nvcc.exe"
        if (Test-Path $cand) {
            $nvcc = $cand
            break
        }
    }
}
if (-not $nvcc) {
    throw "Could not find nvcc.exe. Install the NVIDIA CUDA Toolkit."
}

# Locate MSVC cl.exe if not already on PATH
$clCmd = Get-Command cl.exe -ErrorAction SilentlyContinue
$ccbinArgs = @()
if (-not $clCmd) {
    $vsRoots = @()
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path $vswhere) {
        $installations = @(& $vswhere -all -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath)
        $vsRoots += @($installations | ForEach-Object { Join-Path $_ 'VC\Tools\MSVC' })
    }
    $vsRoots += @(
        "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC",
        "C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Tools\MSVC",
        "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Tools\MSVC",
        "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC"
    )
    foreach ($root in $vsRoots) {
        if (Test-Path $root) {
            $verDir = Get-ChildItem $root -Directory | Sort-Object Name -Descending | Select-Object -First 1
            if ($verDir) {
                $clDir = Join-Path $verDir.FullName "bin\Hostx64\x64"
                if (Test-Path (Join-Path $clDir "cl.exe")) {
                    $ccbinArgs = @("-ccbin", $clDir)
                    break
                }
            }
        }
    }
}

Write-Host "Using nvcc: $nvcc" -ForegroundColor Cyan
Push-Location $BenchDir
try {
    Write-Host "Building mma_bench.exe (sm_86 Ampere + sm_89 Ada)..." -ForegroundColor Yellow
    & $nvcc -O3 -gencode arch=compute_86,code=sm_86 -gencode arch=compute_89,code=sm_89 @ccbinArgs -o "mma_bench.exe" "mma_bench.cu"
    if ($LASTEXITCODE -ne 0) { throw "Failed to build mma_bench.exe" }

    Write-Host "Building validate_gemm.exe (sm_86 Ampere + sm_89 Ada + cuBLAS)..." -ForegroundColor Yellow
    & $nvcc -O3 -gencode arch=compute_86,code=sm_86 -gencode arch=compute_89,code=sm_89 @ccbinArgs -lcublas -o "validate_gemm.exe" "validate_gemm.cu"
    if ($LASTEXITCODE -ne 0) { throw "Failed to build validate_gemm.exe" }

    Write-Host "Successfully built mma_bench.exe and validate_gemm.exe!" -ForegroundColor Green
} finally {
    Pop-Location
}
