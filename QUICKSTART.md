# Quickstart

This is an experimental UEFI Tensor Core unlock port. All-card Windows compatibility has not been demonstrated. Read [README.md](README.md) and [REVIEW.md](REVIEW.md) first.

1. Download the portable Windows x64 ZIP from [Releases](https://github.com/Glat0s/gpu-unlock-windows-generic/releases/latest). Choose the asset with `portable` in its filename, not the automatic source archive.
2. Use Windows **Extract All** and keep the full folder together in a writable location. Windows 10/11 x64 and a compatible NVIDIA driver are required; developer tools are unnecessary for the portable release.
3. Optionally check the untouched extraction with `powershell -NoProfile -ExecutionPolicy Bypass -File .\Verify-Portable.ps1`.
4. Launch `Launch-UsbCreator.cmd`; review live discovery and the generated profile.
5. Select a FAT32 USB drive with at least 100 MB free. Creation overwrites the application's files and fallback boot loader on that USB.
6. Use manual or read-only probe mode for initial hardware evaluation. Boot through the motherboard UEFI boot menu. The unsigned loader requires Secure Boot disabled.
7. Save a before report with `benchmark/Run-Benchmark.ps1 -SaveAsBaseline` and run again after reboot, or use the GUI benchmark buttons. Reports appear in `benchmark-reports/`. The portable release includes the executables and runtime DLLs.

For a source checkout, follow **Build from source** in [README.md](README.md) before step 4. The GUI's Rebuild button requires Python and Zig; it is unnecessary for the portable release.

A normal CLI inspection does not persist inventory or modify source headers. Optional `-SaveInventory`, `-UpdatePackageConfig` and `-WriteLocalHeader` explicitly persist local information. Release builds ignore the local header unless compiled with `GU_USE_LOCAL_BOARD`.
