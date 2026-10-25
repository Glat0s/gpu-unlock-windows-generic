# Quickstart

This is an experimental UEFI Tensor Core unlock port. All-card Windows compatibility has not been demonstrated. Read [README.md](README.md) and [REVIEW.md](REVIEW.md) first.

1. Install Python 3.14+ and Zig 0.14.1; set `ZIG_EXE` or extract Zig under `tools/zig-x86_64-windows-0.14.1`.
2. Run `python prepare_assets.py`, `python build.py`, then `python test.py`.
3. Run `powershell -NoProfile -ExecutionPolicy Bypass -File tests/Test-Application.ps1`.
4. Launch `Launch-UsbCreator.cmd`; review live discovery and the generated profile.
5. Select a FAT32 USB drive with at least 100 MB free. Creation overwrites the application's files and fallback boot loader on that USB.
6. Use manual or read-only probe mode for initial hardware evaluation. Boot through the motherboard UEFI boot menu. The unsigned loader requires Secure Boot disabled.
7. Build benchmarks with `benchmark/Build-Benchmark.ps1`; save a before report with `benchmark/Run-Benchmark.ps1 -SaveAsBaseline` and run again after reboot. Reports appear in `benchmark-reports/`.

A normal CLI inspection does not persist inventory or modify source headers. Optional `-SaveInventory`, `-UpdatePackageConfig` and `-WriteLocalHeader` explicitly persist local information. Release builds ignore the local header unless compiled with `GU_USE_LOCAL_BOARD`.
