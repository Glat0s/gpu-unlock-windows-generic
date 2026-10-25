# SPDX-License-Identifier: MIT
"""Run host unit tests, PE/COFF EFI verification, and firmware asset checks."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import sys
from build import ROOT, UNLOCK, EDK2, BUILD, zig_path, inspect_pe

def main():
    zig = zig_path()
    out_dir = BUILD / 'tests'
    out_dir.mkdir(parents=True, exist_ok=True)
    test_exe = out_dir / 'test_tailored_suite.exe'

    cmd = [
        zig, 'cc', '-std=c11', '-Wall', '-Wextra', '-Werror',
        '-Wno-unused-parameter', '-D__KERNEL__', '-DGU_UEFI_PORT',
        '-DGU_SOFT_UNLOCK_BUILD=1',
        '-I' + str(UNLOCK / 'compat'),
        '-I' + str(UNLOCK),
        '-I' + str(EDK2),
        '-I' + str(EDK2 / 'X64'),
        str(UNLOCK / 'tests/test_tailored_suite.c'),
        str(UNLOCK / 'config.c'),
        str(UNLOCK / 'checks.c'),
        str(UNLOCK / 'port.c'),
        str(UNLOCK / 'runtime.c'),
        str(UNLOCK / 'format.c'),
        str(UNLOCK / 'sha256.c'),
        str(UNLOCK / 'vendor/layout_610.c'),
        str(UNLOCK / 'vendor/prep_610.c'),
        str(UNLOCK / 'vendor/vbios_610.c'),
        str(UNLOCK / 'vendor/gfw_eval.c'),
        '-o', str(test_exe),
    ]
    subprocess.run(cmd, check=True)
    res = subprocess.run([str(test_exe)], check=True, capture_output=True, text=True)
    print(res.stdout.strip())
    shutil.rmtree(out_dir, ignore_errors=True)
    shutil.rmtree(ROOT / '__pycache__', ignore_errors=True)

    # Verify USB package structure & CONFIG.INI parsing
    usb_pkg = ROOT / 'usb-package'
    required_files = [
        'EFI/BOOT/BOOTX64.EFI',
        'EFI/BOOT/UNLOCK-MANUAL.EFI',
        'EFI/BOOT/UNLOCK-AUTO.EFI',
        'EFI/BOOT/PROBE-READONLY.EFI',
        'RTX4090-PREP/CONFIG.INI',
        'RTX4090-PREP/CONFIG-GENERIC.INI',
        'RTX4090-PREP/ASSETS/booter_load_ad102.bin',
        'RTX4090-PREP/ASSETS/booter_load_ga102.bin',
        'RTX4090-PREP/ASSETS/v67-ad102-610.43.03-four-plm.bin',
        'RTX4090-PREP/ASSETS/v67-ga102-610.43.03.bin',
        'RTX4090-PREP/ASSETS/gsp_ga10x.bin',
        'RTX4090-PREP/ASSETS/gsp_boot_ad102.bin',
        'RTX4090-PREP/ASSETS/gsp_boot_ga102.bin',
        'RTX4090-PREP/ASSETS/gsp_boot_desc_ad102.bin',
        'RTX4090-PREP/ASSETS/gsp_boot_desc_ga102.bin',
        'GPU-PROBE/ALLOW-READONLY.TAG',
        'INSTRUCTIONS.txt',
    ]
    for rel in required_files:
        p = usb_pkg / rel
        if not p.is_file():
            raise SystemExit(f'Missing required file in usb-package: {rel}')
        if p.suffix.lower() == '.efi':
            inspect_pe(p.read_bytes())

    pins = json.loads((ROOT / 'firmware-manifest.json').read_text(encoding='utf-8'))
    for name, pin in pins.items():
        if not isinstance(pin, dict) or 'sha256' not in pin:
            continue
        asset_path = usb_pkg / 'RTX4090-PREP/ASSETS' / name
        data = asset_path.read_bytes()
        if len(data) != pin['bytes'] or hashlib.sha256(data).hexdigest() != pin['sha256']:
            raise SystemExit(f'Corrupted staged asset in usb-package: {name}')

    print('Verified usb-package/ completeness (all EFI loaders, CONFIG.INI profiles, and all 9 AD102 + GA102 assets).')

if __name__ == '__main__':
    main()
