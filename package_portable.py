# SPDX-License-Identifier: MIT
"""Build a clean Windows x64 release ZIP; run on a Windows build machine."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parent


def imports(path):
    """Read regular PE imports without requiring dumpbin or third-party modules."""
    data = path.read_bytes()
    pe = struct.unpack_from('<I', data, 60)[0]
    opt = pe + 24
    if data[pe:pe + 4] != b'PE\0\0' or struct.unpack_from('<H', data, opt)[0] != 0x20b:
        raise ValueError(f'Expected x64 PE: {path}')
    sections = opt + struct.unpack_from('<H', data, pe + 20)[0]

    def offset(rva):
        for i in range(struct.unpack_from('<H', data, pe + 6)[0]):
            size, va, raw_size, raw = struct.unpack_from('<IIII', data, sections + i * 40 + 8)
            if va <= rva < va + max(size, raw_size):
                return raw + rva - va
        raise ValueError(f'Invalid import RVA in {path}')

    rva = struct.unpack_from('<I', data, opt + 120)[0]
    if not rva:
        return []
    pos = offset(rva)
    result = []
    while any(data[pos:pos + 20]):
        name = offset(struct.unpack_from('<I', data, pos + 12)[0])
        result.append(data[name:data.index(b'\0', name)].decode('ascii'))
        pos += 20
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version', required=True, help='Release tag, e.g. v0.1.0')
    parser.add_argument('--cuda', type=Path, default=os.environ.get('CUDA_PATH'), required=not os.environ.get('CUDA_PATH'))
    args = parser.parse_args()
    if not args.version or any(c not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_' for c in args.version):
        parser.error('Version must contain only letters, digits, dots, hyphens or underscores')
    # Always rebuild. Never ship stale EFI files or a local machine profile.
    for script in ('prepare_assets.py', 'build.py', 'test.py'):
        subprocess.run([sys.executable, str(ROOT / script)], check=True, cwd=ROOT)
    subprocess.run(['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
                    str(ROOT / 'benchmark/Build-Benchmark.ps1')], check=True, cwd=ROOT)
    subprocess.run(['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
                    str(ROOT / 'tests/Test-Application.ps1')], check=True, cwd=ROOT)

    files = {}

    def add(path, name=None):
        files[name or path.relative_to(ROOT).as_posix()] = path

    # Include matching source and notices for the GPL components, excluding all ignored
    # inventories, private profiles, caches, logs, compilers and research downloads.
    tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
    for name in filter(None, tracked):
        if name.startswith(('.github/', '.agents/', '.codex/')):
            continue
        add(ROOT / name)
    for name in ('package_portable.py', 'Verify-Portable.ps1'):
        add(ROOT / name)
    for name in ('BOOTX64.EFI', 'UNLOCK-MANUAL.EFI', 'UNLOCK-AUTO.EFI', 'PROBE-READONLY.EFI'):
        add(ROOT / 'usb-package/EFI/BOOT' / name)
    for name in ('INSTRUCTIONS.txt', 'GPU-PROBE/ALLOW-READONLY.TAG',
                 'RTX4090-PREP/CONFIG.INI', 'RTX4090-PREP/CONFIG-GENERIC.INI'):
        add(ROOT / 'usb-package' / name)
    pins = json.loads((ROOT / 'firmware-manifest.json').read_text())
    for name, pin in pins.items():
        path = ROOT / 'usb-package/RTX4090-PREP/ASSETS' / name
        if path.stat().st_size != pin['bytes'] or hashlib.sha256(path.read_bytes()).hexdigest() != pin['sha256']:
            raise ValueError(f'Firmware mismatch: {name}')
        add(path)
    add(ROOT / 'assets/NVIDIA-LICENSE', 'LICENSES/NVIDIA-Firmware.txt')
    for name in ('EULA.txt', 'LICENSE'):
        add(args.cuda / name, 'LICENSES/CUDA-' + name)
    pending = [ROOT / 'benchmark' / name for name in ('mma_bench.exe', 'validate_gemm.exe')]
    # cuBLAS loads cuBLASLt dynamically; it is not necessarily in its import table.
    pending += list((args.cuda / 'bin').rglob('cublasLt64_*.dll'))
    if len(pending) != 3:
        raise ValueError('Expected exactly one CUDA cuBLASLt runtime')
    seen = set()
    while pending:
        path = pending.pop()
        if path.name.lower() in seen:
            continue
        seen.add(path.name.lower())
        add(path, 'benchmark/' + path.name)
        for name in imports(path):
            candidates = list((args.cuda / 'bin').rglob(name))
            if candidates:
                pending.append(candidates[0])
            elif name.lower().startswith(('vcruntime', 'msvcp', 'concrt')):
                raise ValueError(f'Unbundled MSVC runtime {name}: rebuild with /MT or supply redistributable DLLs')
            elif not (name.lower().startswith(('api-ms-', 'ext-ms-')) or
                      (Path(os.environ['SystemRoot']) / 'System32' / name).is_file()):
                raise ValueError(f'Unresolved DLL dependency {name} from {path}')

    output = ROOT / 'dist' / f'gpu-unlock-{args.version}-windows-x64-portable.zip'
    output.parent.mkdir(exist_ok=True)
    manifest = {name: hashlib.sha256(path.read_bytes()).hexdigest() for name, path in sorted(files.items())}
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for name, path in sorted(files.items()):
            archive.write(path, name)
        archive.writestr('portable-manifest.json', json.dumps(manifest, indent=2) + '\n')
    checksum = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix('.zip.sha256').write_text(f'{checksum}  {output.name}\n', encoding='ascii')
    print(f'Portable ZIP: {output} ({output.stat().st_size:,} bytes)')


if __name__ == '__main__':
    main()
