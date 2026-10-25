# SPDX-License-Identifier: MIT
"""Fetch and generate the five hash-pinned NVIDIA 610.43.03 AD102 firmware assets."""
from pathlib import Path
import hashlib
import importlib.util
import json
import subprocess
import sys
import tarfile

ROOT = Path(__file__).resolve().parent
TOOLS = ROOT / 'src/firmware-tools'
OUT = ROOT / 'assets'
CACHE = ROOT / 'local/cache'

def load_module(name):
    spec = importlib.util.spec_from_file_location(name, TOOLS / (name + '.py'))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result

def verify_existing():
    pins = json.loads((ROOT / 'firmware-manifest.json').read_text(encoding='utf-8'))
    result = {}
    for name, pin in pins.items():
        if not isinstance(pin, dict) or 'sha256' not in pin:
            continue
        p = OUT / name
        if not p.is_file():
            return None
        data = p.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        if len(data) != pin['bytes'] or digest != pin['sha256']:
            return None
        result[name] = {'bytes': len(data), 'sha256': digest}
    return result

def main():
    existing = verify_existing()
    if existing:
        (ROOT / 'assets-verified.json').write_text(json.dumps(existing, indent=2) + '\n', encoding='utf-8')
        print('All 9 Ada + Ampere firmware assets already present and SHA-256 verified.')
        return
    if sys.version_info < (3, 14):
        raise SystemExit('Python 3.14+ is required for native tar.zst extraction.')
    subprocess.run([sys.executable, str(TOOLS / 'fetch_artifacts.py'), str(CACHE)], check=True)
    generator = load_module('generate_v67')
    def extract(package, name):
        with tarfile.open(package, 'r:*') as archive:
            return generator.read_member(archive, name)
    generator.extract_member = extract
    manifest = json.loads((TOOLS / 'artifacts-610.43.03.json').read_text(encoding='utf-8'))
    sources = manifest['source_artifacts']
    OUT.mkdir(exist_ok=True)
    sys.argv = ['generate_v67', str(CACHE / sources[2]['filename']), str(OUT)]
    if generator.main() != 0:
        raise SystemExit('Firmware generation failed')
    payload = load_module('ad102_payload').payload()
    (OUT / 'v67-ad102-610.43.03-four-plm.bin').write_bytes(payload)
    extracted = subprocess.run(
        [sys.executable, str(TOOLS / 'extract_boot_assets.py'),
         str(CACHE / sources[0]['filename']), str(OUT), '--arch', 'both',
         '--gsp', str(OUT / 'gsp_ga10x.bin')],
        check=True, capture_output=True, text=True
    )
    (OUT / 'extraction-report.json').write_text(extracted.stdout, encoding='utf-8')
    verified = verify_existing()
    if not verified:
        raise SystemExit('Asset verification failed after generation')
    (ROOT / 'assets-verified.json').write_text(json.dumps(verified, indent=2) + '\n', encoding='utf-8')
    print('Verified all 9 Ada + Ampere firmware assets.')

if __name__ == '__main__':
    main()
