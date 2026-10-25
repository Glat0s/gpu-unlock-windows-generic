# Windows Tensor Core benchmarks

Build `mma_bench.exe` and `validate_gemm.exe` using `Build-Benchmark.ps1` with the CUDA Toolkit and supported MSVC x64 tools. Both Ampere sm_86 and Ada sm_89 code are compiled.

Run `Run-Benchmark.ps1 -SaveAsBaseline` before the unlock, and `Run-Benchmark.ps1` after reboot. Timestamped reports are stored in the application `benchmark-reports/` directory with TFLOPS, TOPS, repetitions and numerical validation results. Failed numerical validation makes the CLI fail.

Both programs currently use CUDA device 0. The issue-rate ratio is a heuristic for the unlock state and is sensitive to clocks and other workloads. It is not a gaming or inference benchmark. Compare the same GPU, driver, power and clock policies, and workload conditions.

`validate_gemm.cu` compares seeded FP16/BF16 GEMM against a CPU reference with square, rectangular and non-tile-aligned shapes. Passing these cases does not establish accuracy for every application.

The optional `tensor_modes_issue.cu` and `tensor_modes_driver_runner.py` are separate research utilities; the Windows GUI uses `mma_bench.exe` and `validate_gemm.exe`.
