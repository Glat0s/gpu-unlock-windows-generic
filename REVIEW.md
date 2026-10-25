# Review and release status

Reviewed 2026-10-25 against the requested generic release requirements. The source and package have been corrected, but **production readiness and successful unlock on all RTX 3000/4000 cards cannot be certified**. No physical preboot/reset/Windows handoff test was performed in this session. Upstream projects are architecture/board-specific research; their results do not validate this derivative on every board or laptop.

## Fixed

- FAT32 GUI startup crash: PowerShell unwraps a single returned object. The dropdown code now explicitly collects drive inventory into an array. The actual GUI refresh function is regression-tested with zero, one and three simulated drives.
- Restricted disk inspection now warns instead of terminating the GUI. Disk writes still require successful fresh volume/partition/disk inspection and reject system/boot disks.
- Removed the private hardware inventory, generated C header and saved local benchmark baselines. Generic builds ignore optional local headers unless `GU_USE_LOCAL_BOARD` is explicitly defined. Package builds always replace CONFIG.INI with generic settings.
- Fixed GPU enumeration: candidate handles are held locally until enumeration completes, so discovering the first GPU does not hide later candidates. Initial configuration checks no longer enforce an uninitialized saved BDF; subsequent checks enforce the captured target location.
- Strict board matching no longer bypasses catalog membership or architecture validation. Host tests exercise recognition and opposite-architecture rejection for every catalog entry.
- Firmware preparation now extracts both Ada and Ampere boot assets. Package builds verify all nine assets against the authoritative manifest and fail on missing/mismatched data. Verification no longer relies on a previously generated verification JSON or Python assertions.
- Compiler caches are local to the workspace, avoiding access failures in restricted user cache directories.
- USB/folder staging rechecks the destination before copying and rejects the application root and source package. Free-space validation accounts for a complete package copy.
- Package verification checks AMD64 PE32+ EFI application headers, rather than accepting any file starting with MZ. A missing firmware manifest fails verification.
- Benchmark subprocess failures, incomplete metrics, failed numerical validation and missing validators cannot produce a successful unlocked result. GUI and CLI full benchmarks propagate failure. Reports use invariant decimal TFLOPS/TOPS, timestamp filenames with subsecond precision, and compare only a baseline with matching recorded GPU/driver identity.
- Removed the hardcoded local Visual Studio installation path; discovery uses vswhere and standard locations. Unsupported-compiler overrides were removed.
- Added source repository exclusions, generic setup documentation and third-party licensing notices. Replaced the claim that catalog recognition guarantees all-card support.

## Verification completed

- `python prepare_assets.py`: all nine existing firmware assets match pinned sizes and SHA-256 hashes. Clean network download/extraction was not rerun.
- `python build.py`: manual, automatic and read-only probe loaders compile; PE/COFF architecture, subsystem, imports, relocations and entry points pass inspection.
- `python test.py`: C host/configuration tests and staged package/firmware verification pass.
- `tests/Test-Application.ps1`: zero/single/multiple-drive GUI refresh, malformed EFI rejection, folder guards, matching C/PowerShell catalogs (89 entries), generic profile, package hashes and PowerShell syntax checks pass. Deterministic subprocess fixtures verify de-DE reports, failed numerical validation, incomplete metrics and nonzero CUDA exit handling without accessing a GPU.
- `UsbCreatorGui.ps1 -SelfTest`: form, profile transitions and package checks pass. This environment denies Windows hardware/storage inspection and discovers no GPUs, so this does not constitute a live GPU or attached USB test.
- CLI generic folder staging under `build/staging-check` passes all 15 post-copy checks. No connected USB drive was modified.

## Remaining release gates

1. Establish a physical compatibility matrix: GPU chip, PCI/subsystem IDs, VBIOS, board firmware, driver and Windows versions; cold boot, unlock result, numeric accuracy, FLR, GOP recovery and Windows handoff. AD102/GA102-named payloads and shared architecture signatures do not independently demonstrate coverage of every GA10x/AD10x chip or OEM implementation.
2. Exercise actual FAT32 media, unplug/replug and disk reassignment under normal and elevated Windows permissions. The single-drive exception is covered by a simulated regression test; real device enumeration is permission-restricted here.
3. CUDA tools currently target device 0. On multi-GPU systems their results may describe a different GPU from the UEFI profile. The GUI reports a throughput heuristic; it does not directly read the unlock registers. Full end-to-end benchmark testing on real hardware remains necessary.
4. Test first-time firmware download/extraction and CUDA compilation in a clean Windows environment, and resolve redistribution requirements before shipping firmware binaries.
The unused `reference_repos/` folder has been removed. It is not required by builds or tests; compiler/cache/output directories remain excluded from Git.

A repository can be published as an experimental source release with these limitations. It must not be represented as a production-validated universal unlocker.
