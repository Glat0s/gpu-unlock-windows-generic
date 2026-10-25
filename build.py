# SPDX-License-Identifier: MIT
"""Build RTX 4090 UEFI Unlocker (Manual, Auto, and Read-Only Probe) and assemble usb-package/."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import struct
import subprocess

ROOT = Path(__file__).resolve().parent
SRC = ROOT / 'src'
UNLOCK = SRC / 'unlock'
PROBE = SRC / 'probe'
EDK2 = SRC / 'edk2/MdePkg/Include'
BUILD = ROOT / 'build'
os.environ.setdefault('ZIG_GLOBAL_CACHE_DIR', str(BUILD / 'zig-global-cache'))
os.environ.setdefault('ZIG_LOCAL_CACHE_DIR', str(BUILD / 'zig-local-cache'))
USB_PKG = ROOT / 'usb-package'

UNLOCK_SOURCES = [
    'app', 'app_io', 'config', 'ownership', 'format', 'runtime',
    'sha256', 'checks', 'port', 'compat',
    'vendor/unlock_610', 'vendor/prep_610', 'vendor/layout_610',
    'vendor/vbios_610', 'vendor/gfw_eval',
]

def zig_path(value=None):
    return value or os.environ.get('ZIG_EXE') or str(ROOT / 'tools/zig-x86_64-windows-0.14.1/zig.exe')

def compiler_flags():
    return [
        '-std=c11', '-fshort-wchar', '-Wall', '-Wextra', '-Werror',
        '-Wno-unused-parameter', '-D__KERNEL__', '-DGU_UEFI_PORT',
        '-I' + str(UNLOCK / 'compat'),
        '-I' + str(UNLOCK),
        '-I' + str(EDK2),
        '-I' + str(EDK2 / 'X64'),
    ]

def inspect_pe(data):
    u16 = lambda offset: struct.unpack_from('<H', data, offset)[0]
    u32 = lambda offset: struct.unpack_from('<I', data, offset)[0]
    pe = u32(60)
    opt = pe + 24
    if data[:2] != b'MZ' or data[pe:pe + 4] != b'PE\0\0':
        raise ValueError('Not PE/COFF')
    if (u16(pe + 4), u16(opt), u16(opt + 68)) != (0x8664, 0x20b, 10):
        raise ValueError('Not an AMD64 EFI application')
    if u16(opt + 70) & 0x140 != 0x140 or not u32(opt + 112 + 5 * 8 + 4):
        raise ValueError('Missing relocation/security characteristics')
    for directory in (1, 12, 13):
        if data[opt + 112 + directory * 8:opt + 120 + directory * 8] != b'\0' * 8:
            raise ValueError('Unexpected external DLL imports')
    entry = u32(opt + 16)
    start = opt + u16(pe + 20)
    entry_sections = [
        t for t in [start + 40 * i for i in range(u16(pe + 6))]
        if u32(t + 12) <= entry < u32(t + 12) + u32(t + 8) and u32(t + 36) & 0x20000000
    ]
    if len(entry_sections) != 1:
        raise ValueError('Entry point outside executable section')
    return {
        'machine': 'AMD64',
        'subsystem': 'EFI_APPLICATION',
        'relocations': True,
        'imports': False,
        'bytes': len(data),
        'sha256': hashlib.sha256(data).hexdigest(),
    }

def build_efi(zig, sources, extra_defines, out_path):
    out_path.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        zig, 'cc', '-target', 'x86_64-uefi',
        *compiler_flags(),
        *extra_defines,
        '-ffreestanding', '-fno-builtin', '-fno-stack-protector',
        '-mno-red-zone', '-Os', '-g0', '-nostdlib',
        *[str(s) for s in sources],
        '-o', str(out_path),
    ]
    subprocess.run(cmd, check=True)
    data = out_path.read_bytes()
    info = inspect_pe(data)
    info['artifact'] = str(out_path.relative_to(ROOT))
    return info

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--zig', help='Path to zig.exe')
    parser.add_argument('--default-mode', choices=['manual', 'auto'], default='manual',
                        help='Which EFI binary to copy as default EFI/BOOT/BOOTX64.EFI')
    args = parser.parse_args()

    zig = zig_path(args.zig)
    if not Path(zig).is_file():
        raise SystemExit(f'Zig compiler not found at {zig}')

    unlock_src_paths = [UNLOCK / (s + '.c') for s in UNLOCK_SOURCES]
    probe_src_paths = [
        PROBE / 'uefi_probe.c',
        PROBE / 'capture.c',
        UNLOCK / 'format.c',
        UNLOCK / 'runtime.c',
    ]

    manual_efi = BUILD / 'RTX4090-UNLOCK-MANUAL.EFI'
    auto_efi = BUILD / 'RTX4090-UNLOCK-AUTO.EFI'
    probe_efi = BUILD / 'RTX4090-PROBE-READONLY.EFI'

    manual_info = build_efi(zig, unlock_src_paths, ['-DGU_SOFT_UNLOCK_BUILD=1'], manual_efi)
    auto_info = build_efi(zig, unlock_src_paths, ['-DGU_SOFT_UNLOCK_BUILD=1', '-DGU_AUTO_BOOT_BUILD=1'], auto_efi)
    probe_info = build_efi(zig, probe_src_paths, ['-I' + str(PROBE)], probe_efi)

    # Assemble usb-package/
    efi_boot_dir = USB_PKG / 'EFI/BOOT'
    prep_dir = USB_PKG / 'RTX4090-PREP'
    assets_dir = prep_dir / 'ASSETS'
    probe_dir = USB_PKG / 'GPU-PROBE'

    for d in (efi_boot_dir, prep_dir, assets_dir, probe_dir):
        d.mkdir(parents=True, exist_ok=True)

    default_efi = auto_efi if args.default_mode == 'auto' else manual_efi
    shutil.copy2(default_efi, efi_boot_dir / 'BOOTX64.EFI')
    shutil.copy2(manual_efi, efi_boot_dir / 'UNLOCK-MANUAL.EFI')
    shutil.copy2(auto_efi, efi_boot_dir / 'UNLOCK-AUTO.EFI')
    shutil.copy2(probe_efi, efi_boot_dir / 'PROBE-READONLY.EFI')
    (probe_dir / 'ALLOW-READONLY.TAG').write_bytes(b'RTX4090-READONLY-CAPTURE-V1\n')

    # The checked-in manifest is authoritative; derived verification reports are not.
    pins = json.loads((ROOT / 'firmware-manifest.json').read_text(encoding='utf-8'))
    for name, spec in pins.items():
        data = (ROOT / 'assets' / name).read_bytes()
        if len(data) != spec['bytes'] or hashlib.sha256(data).hexdigest() != spec['sha256']:
            raise ValueError(f'Asset hash mismatch: {name}')
        (assets_dir / name).write_bytes(data)
    assets_staged = True

    instructions = """================================================================================
NVIDIA GeForce RTX 3000 (GA10x) & RTX 4000 (AD10x) Windows 10/11 UEFI Unlocker
Pre-Boot FP16 / BF16 Tensor Core FMA (with FP32 Accumulate) Speed-Select Tool
================================================================================

1. EXPERIMENTAL GPU CATALOG (NOT A VALIDATED SUPPORT MATRIX)
-----------------
- NVIDIA GeForce RTX 4000 Series (Ada Lovelace: AD102, AD103, AD104, AD106, AD107)
  RTX 4090, RTX 4090 D, RTX 4080 SUPER, RTX 4080, RTX 4070 Ti SUPER,
  RTX 4070 Ti, RTX 4070 SUPER, RTX 4070, RTX 4060 Ti, RTX 4060, RTX 4050 (Desktop & Laptop)
- NVIDIA GeForce RTX 3000 Series (Ampere: GA102, GA103, GA104, GA106, GA107)
  RTX 3090 Ti, RTX 3090, RTX 3080 Ti, RTX 3080 (10G/12G), RTX 3070 Ti,
  RTX 3070, RTX 3060 Ti, RTX 3060, RTX 3050 (Desktop & Laptop)

2. HOW TO BOOT AND UNLOCK
-------------------------
1. Ensure "Secure Boot" is Disabled in your motherboard BIOS.
2. Perform a FULL COLD SHUTDOWN of Windows (`shutdown /s /f /t 0` or Hold Shift + Shut Down)
   then ensure a cold GPU power state. A Windows shutdown alone may not remove standby power.
3. Power on the PC and select this UEFI USB drive from your BIOS Boot Menu.
4. In Manual Mode (default):
   - Press [U] to run the single-fire SEC2 PLM + SS0/SS1 unlock, perform PCIe FLR,
     reconnect UEFI GOP display, and chainload Windows Boot Manager (`bootmgfw.efi`).
   - Press [S] to skip the unlock and boot Windows normally.
   - Press [Esc] to return to BIOS.
5. In Automatic Mode (`mode = auto` in `\\RTX4090-PREP\\CONFIG.INI`):
   - Waits `countdown` seconds (default 5s; press [S] to skip or [Esc] to cancel), then
     automatically unlocks the GPU and boots Windows.

3. CUSTOMIZING WITHOUT RECOMPILING (\\RTX4090-PREP\\CONFIG.INI)
---------------------------------------------------------------
Edit `\\RTX4090-PREP\\CONFIG.INI` on this USB drive (or use `Launch-UsbCreator.cmd`):
- Change `mode = manual` to `mode = auto` for hands-free countdown boot.
- Set `board_id = any` and `arch = auto` for generic discovery mode for catalog
  RTX 3000 or RTX 4000 GPUs (hardware validation required), or use `Launch-UsbCreator.cmd` / `Tailor-MyHardware.ps1`
  to tailor `CONFIG.INI` for a specific GPU and Windows ESP partition.

4. LOGS & DIAGNOSTICS
---------------------
Each boot creates a new folder under `\\RTX4090-PREP\\RUN00` (or `AUTO0000`) containing:
- `REPORT.TXT` : Complete step-by-step preflight, FWSEC, SEC2, PLM, SS0/SS1, FLR, and handoff log.
- `PROM.BIN`   : 1 MiB backup of the GPU's live VBIOS PROM window (when `save_prom_dump = 1`).
"""
    (USB_PKG / 'INSTRUCTIONS.txt').write_text(instructions, encoding='utf-8')

    generic_ini = """# NVIDIA GeForce RTX 3000 (GA10x) & RTX 4000 (AD10x) UEFI Unlocker Configuration
# Universal Generic Profile - Dynamically discovers any supported RTX 3000/4000 GPU and Windows ESP

mode = manual
countdown = 5

# Target Architecture & GPU Identity (auto / any matches all supported RTX 3000 & 4000 GPUs):
arch = auto
board_id = any
subsystem_id = any
chip_id = any

# PCIe Location & BAR0 Hints:
pci_segment = any
pci_bus = any
pci_device = any
pci_function = any
bar0_base = any

# Validation Strictness Flags (1 = enforce exact match, 0 = allow dynamic discovery):
strict_board = 0
strict_subsystem = 0
strict_chip = 0
strict_bdf = 0
strict_bar0 = 0
strict_esp = 0

# Display Reconnect & Diagnostics:
allow_headless_handoff = 1
save_prom_dump = 1

# Target Windows 10/11 EFI System Partition (ESP):
windows_esp_guid = auto
windows_esp_partition = auto
windows_esp_start_lba = auto
windows_esp_size_lba = auto
"""
    (prep_dir / 'CONFIG-GENERIC.INI').write_text(generic_ini, encoding='utf-8')
    # Release packages must never retain a previous machine's tailored profile.
    (prep_dir / 'CONFIG.INI').write_text(generic_ini, encoding='utf-8')

    manifest = {
        'zig_version': subprocess.check_output([zig, 'version'], text=True).strip(),
        'default_bootx64_mode': args.default_mode,
        'assets_staged': assets_staged,
        'binaries': {
            'manual': manual_info,
            'auto': auto_info,
            'probe_readonly': probe_info,
        },
    }
    (BUILD / 'build-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(manifest, indent=2))

if __name__ == '__main__':
    main()
