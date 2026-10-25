# SPDX-License-Identifier: MIT
"""Build/test a standalone read-only EFI probe. Does not arm or link the unlocker."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess

ROOT=Path(__file__).resolve().parent
PROJECT=ROOT.parent
SOURCE=PROJECT/'port/source'
UNLOCK=SOURCE/'unlock'
ZIG=Path(os.environ.get('ZIG_EXE',str(PROJECT/'tools/zig-x86_64-windows-0.14.1/zig.exe')))
OUT=PROJECT/'build/read-only-probe'
OUT.mkdir(parents=True,exist_ok=True)
includes=['-I'+str(ROOT),'-I'+str(UNLOCK),'-I'+str(SOURCE/'deps/edk2/MdePkg/Include'),'-I'+str(SOURCE/'deps/edk2/MdePkg/Include/X64')]
flags=['-std=c11','-fshort-wchar','-Wall','-Wextra','-Werror','-Wno-unused-parameter',*includes]
production=[ROOT/'capture.c',ROOT/'uefi_probe.c',UNLOCK/'format.c',UNLOCK/'runtime.c']
allowed={'Pci.Read','Mem.Read','GetLocation','GetBarAttributes','RomSize','RomImage'}
calls=set()
for path in production[:2]:
    text=path.read_text()
    fields=set(re.findall(r'(?:Pci|pci|target)->([A-Za-z]+(?:\.[A-Za-z]+)?)',text))
    assert fields<=allowed,(str(path),fields-allowed)
    calls|=fields
    for forbidden in ('SetVariable','ResetSystem','DisconnectController','ConnectController','SetWatchdogTimer','GuWrite','GuStarted','__asm','asm volatile'):
        assert forbidden not in text,(str(path),forbidden)
test=OUT/'test-capture-host.exe'
subprocess.run([str(ZIG),'cc','-target','x86_64-windows',*flags,str(ROOT/'test_capture.c'),str(ROOT/'capture.c'),str(UNLOCK/'format.c'),'-o',str(test)],check=True)
tested=subprocess.check_output([str(test)],text=True)
(OUT/'host-tests.txt').write_text(tested,encoding='utf-8')
assert tested.count('PASS')==13
wrapper=OUT/'test-uefi-wrapper-host.exe'
subprocess.run([str(ZIG),'cc','-target','x86_64-windows',*flags,str(ROOT/'test_uefi_probe.c'),str(ROOT/'capture.c'),str(UNLOCK/'format.c'),'-o',str(wrapper)],check=True)
wrapper_tested=subprocess.check_output([str(wrapper)],text=True)
assert wrapper_tested.count('PASS')==12
(OUT/'wrapper-host-tests.txt').write_text(wrapper_tested,encoding='utf-8')
efi=OUT/'RTX4090-READONLY-PROBE.EFI'
subprocess.run([str(ZIG),'cc','-target','x86_64-uefi',*flags,'-ffreestanding','-fno-builtin','-fno-stack-protector','-mno-red-zone','-Os','-g0','-nostdlib',*[str(path) for path in production],'-o',str(efi)],check=True)
data=efi.read_bytes()
u16=lambda offset:struct.unpack_from('<H',data,offset)[0]
u32=lambda offset:struct.unpack_from('<I',data,offset)[0]
pe=u32(60);opt=pe+24
assert data[:2]==b'MZ' and data[pe:pe+4]==b'PE\0\0'
assert (u16(pe+4),u16(opt),u16(opt+68))==(0x8664,0x20b,10)
assert u16(opt+70)&0x140==0x140 and u32(opt+112+5*8+4)
for directory in (1,12,13):assert data[opt+112+directory*8:opt+120+directory*8]==bytes(8)
package=OUT/'usb-package'
(package/'EFI/BOOT').mkdir(parents=True,exist_ok=True)
(package/'GPU-PROBE').mkdir(exist_ok=True)
shutil.copyfile(efi,package/'EFI/BOOT/BOOTX64.EFI')
(package/'GPU-PROBE/ALLOW-READONLY.TAG').write_bytes(b'RTX4090-READONLY-CAPTURE-V1\n')
report={'artifact':str(efi),'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data),
        'amd64_efi':True,'imports':False,'unlock_code_linked':False,'unlock_assets_embedded':False,
        'allowed_gpu_protocol_fields':sorted(calls),'gpu_writes':False,'dma_mapping':False,
        'boot_variables_written':False,'usb_only_file_output':True,'synthetic_capture_tests':13,'synthetic_wrapper_tests':12,
        'hardware_execution_tested':False,'source_sha256':{str(path.relative_to(PROJECT)):hashlib.sha256(path.read_bytes()).hexdigest() for path in production},
        'test_source_sha256':hashlib.sha256((ROOT/'test_capture.c').read_bytes()).hexdigest()}
(OUT/'build-result.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
(package/'GPU-PROBE/BUILD.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(tested,end='')
print(wrapper_tested,end='')
print(json.dumps({key:value for key,value in report.items() if 'sha256' not in key or key=='sha256'},indent=2))
