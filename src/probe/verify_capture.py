# SPDX-License-Identifier: MIT
"""Validate captured files offline; report evidence without arming any code."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys

PROJECT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(PROJECT))
from check_rom import inspect_rom

def verify(folder,exported):
    text=(folder/'CAPTURE.TXT').read_text(encoding='ascii')
    if len(text)>16384:raise ValueError('Oversized capture header')
    fields={}
    for line in text.splitlines():
        key,value=line.split('=',1)
        if key in fields:raise ValueError('Duplicate capture key: '+key)
        fields[key]=value
    if fields.get('format')!='RTX4090-READONLY-CAPTURE-V1':raise ValueError('Unknown capture format')
    number=lambda key:int(fields[key],0)
    for key,value in {'capture_complete':1,'final_status':0,'pci_unchanged':1,'gpu_writes':0,
                      'dma_mappings':0,'firmware_launches':0,'unlock_enabled':0,
                      'board_id':0x268410de,'subsystem':0x13ba196e,'segment':0,'bus':1,'device':0,'function':0,
                      'prom_bar_offset':0x300000,'prom_bytes':1048576}.items():
        if number(key)!=value:raise ValueError('Capture field rejected: '+key)
    before=(folder/'PCI-BEFORE.BIN').read_bytes();after=(folder/'PCI-AFTER.BIN').read_bytes()
    if len(before)!=256 or before!=after:raise ValueError('PCI snapshots differ or have invalid lengths')
    config=struct.unpack('<64I',before)
    if config[0]!=0x268410de or config[11]!=0x13ba196e or (config[1]&0xffff)!=number('command'):
        raise ValueError('PCI snapshot identity differs from capture header')
    if config[0xc8//4]!=number('config_c8'):raise ValueError('PCI C8 snapshot mismatch')
    prom=(folder/'PROM.BIN').read_bytes();efi=(folder/'EFI-ROM.BIN').read_bytes()
    if len(prom)!=1048576 or not 0<len(efi)<=16*1024*1024 or len(efi)!=number('rom_bytes'):
        raise ValueError('Invalid ROM capture length')
    rom=exported.read_bytes();inventory=inspect_rom(rom)
    if inventory['sha256']!='fea9e9e9e7de00afd7cbe621b0c0a9e37d6cad3c7efb08380d45dc4f08dbfe77':
        raise ValueError('Exported reference is not the pinned local PNY ROM')
    start=inventory['file_view_offset'];end=inventory['images'][-1]['offset']+inventory['images'][-1]['bytes']
    chain=rom[start:end];view=rom[start:start+inventory['file_view_bytes']]
    prom_at=prom.find(chain);efi_at=efi.find(chain)
    # PCI I/O may expose only the legacy and EFI images, omitting NVIDIA
    # extension images. Verify that exact bounded image prefix independently;
    # absence of the entire vendor chain in RomImage is not ROM corruption.
    prefix_bytes=0;prefix_images=0
    for entry in inventory['images']:
        if entry['offset']!=start+prefix_bytes or entry['code_type'] not in (0,3):break
        prefix_bytes+=entry['bytes'];prefix_images+=1
    efi_prefix_matches=(prefix_images==2 and len(efi)==prefix_bytes and efi==rom[start:start+prefix_bytes])
    register_names=('chip','vram_mib','gfw_plm','gfw_boot','gfw_cpuctl','wpr2_hi','feat_plm','ss0','ss1')
    if any(number(name+'_status') for name in register_names):raise ValueError('Register transport failure')
    regs={name:number(name) for name in register_names}
    candidates={'chip':regs['chip']==0x192000a1,'vram_nonzero':0<regs['vram_mib']<=65536,
                'memory_decode_enabled':bool(config[1]&2),'bus_master_off':not bool(config[1]&4),
                'wpr2_down':regs['wpr2_hi']!=0xffffffff and regs['wpr2_hi']>>4==0,
                'feature_permission_closed':regs['feat_plm']==0xffffff8f,
                'ss0_closed':not bool(regs['ss0']&0x88888888),'ss1_closed':regs['ss1']==7,
                'gfw_complete':regs['gfw_plm']!=0xffffffff and bool(regs['gfw_plm']&1) and
                    regs['gfw_boot']!=0xffffffff and (regs['gfw_boot']&255)==255 and
                    regs['gfw_cpuctl']!=0xffffffff and bool(regs['gfw_cpuctl']&0x10)}
    return {'capture_structure_valid':True,'active_rom_chain_matches_prom':prom_at>=0,
            'active_rom_chain_matches_efi_rom':efi_at>=0,'prom_chain_offset':prom_at,'efi_rom_chain_offset':efi_at,
            'efi_rom_matches_exact_legacy_efi_prefix':efi_prefix_matches,
            'legacy_efi_prefix_bytes':prefix_bytes,
            'ss1_override_enable_clear':not bool(regs['ss1']&8),
            'exported_chain_offset':start,'exported_chain_bytes':len(chain),
            'full_exported_file_view_in_prom_offset':prom.find(view),
            'cold_gate_candidates':candidates,'cold_gate_candidates_match':all(candidates.values()),
            'measured':{'bar0_base':number('bar0_base'),'bar0_bytes':number('bar0_bytes'),
                        'config_c8':number('config_c8'),'rom_bytes':len(efi),'registers':regs},
            'sha256':{name:hashlib.sha256((folder/name).read_bytes()).hexdigest() for name in
                      ('CAPTURE.TXT','PCI-BEFORE.BIN','PCI-AFTER.BIN','PROM.BIN','EFI-ROM.BIN')},
            'hardware_entry_enabled':False,'live_dma_mapping_validated':False,'unlock_run':False,
            'note':'Evidence only. Board-specific transaction fixtures and review remain required; this tool never updates or arms the port.'}

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture',type=Path)
    parser.add_argument('--rom',type=Path,default=PROJECT/'inputs/PNY-RTX4090.rom')
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    result=verify(args.capture.resolve(),args.rom.resolve())
    text=json.dumps(result,indent=2)+'\n'
    if args.output:args.output.write_text(text,encoding='utf-8')
    print(text,end='')
