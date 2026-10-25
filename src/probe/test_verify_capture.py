# SPDX-License-Identifier: MIT
"""Offline synthetic capture tests using the pinned exported reference ROM."""
import json
from pathlib import Path
import struct
import tempfile
import unittest
from verify_capture import PROJECT,verify
from check_rom import inspect_rom

class CaptureReviewTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.folder=Path(self.temp.name)
        self.rom=PROJECT/'inputs/PNY-RTX4090.rom'
        data=self.rom.read_bytes();meta=inspect_rom(data)
        start=meta['file_view_offset'];end=meta['images'][-1]['offset']+meta['images'][-1]['bytes']
        chain=data[start:end]
        (self.folder/'PROM.BIN').write_bytes(chain+b'\xff'*(1048576-len(chain)))
        (self.folder/'EFI-ROM.BIN').write_bytes(data)
        config=[0]*64;config[0]=0x268410de;config[1]=3;config[2]=0x030000a1;config[11]=0x13ba196e
        binary=struct.pack('<64I',*config)
        for name in ('PCI-BEFORE.BIN','PCI-AFTER.BIN'):(self.folder/name).write_bytes(binary)
        self.fields={'format':'RTX4090-READONLY-CAPTURE-V1','capture_complete':1,'final_status':0,'pci_unchanged':1,
                     'gpu_writes':0,'dma_mappings':0,'firmware_launches':0,'unlock_enabled':0,
                     'board_id':0x268410de,'subsystem':0x13ba196e,'segment':0,'bus':1,'device':0,'function':0,
                     'prom_bar_offset':0x300000,'prom_bytes':1048576,'command':3,'config_c8':0,
                     'rom_bytes':len(data),'bar0_base':0x80000000,'bar0_bytes':0x1000000,
                     'chip':0x192000a1,'vram_mib':0x5ff4,'gfw_plm':1,'gfw_boot':255,'gfw_cpuctl':16,
                     'wpr2_hi':0,'feat_plm':0xffffff8f,'ss0':0x77777777,'ss1':7}
        for name in ('chip','vram_mib','gfw_plm','gfw_boot','gfw_cpuctl','wpr2_hi','feat_plm','ss0','ss1'):
            self.fields[name+'_status']=0
        self.header()
    def tearDown(self):self.temp.cleanup()
    def header(self):
        (self.folder/'CAPTURE.TXT').write_text(''.join(str(k)+'='+str(v)+'\n' for k,v in self.fields.items()),encoding='ascii')
    def test_synthetic_mapping_never_arms(self):
        result=verify(self.folder,self.rom)
        self.assertTrue(result['active_rom_chain_matches_prom'])
        self.assertTrue(result['active_rom_chain_matches_efi_rom'])
        self.assertTrue(result['cold_gate_candidates_match'])
        self.assertFalse(result['hardware_entry_enabled'])
        self.assertFalse(result['live_dma_mapping_validated'])
    def test_incomplete_rejected(self):
        self.fields['capture_complete']=0;self.header()
        with self.assertRaises(ValueError):verify(self.folder,self.rom)
    def test_changed_pci_rejected(self):
        (self.folder/'PCI-AFTER.BIN').write_bytes(bytes(256))
        with self.assertRaises(ValueError):verify(self.folder,self.rom)
    def test_bad_rom_length_rejected(self):
        (self.folder/'PROM.BIN').write_bytes(bytes(8))
        with self.assertRaises(ValueError):verify(self.folder,self.rom)
    def test_wrong_rom_bytes_do_not_establish_mapping(self):
        data=bytearray((self.folder/'PROM.BIN').read_bytes());data[100]^=1
        (self.folder/'PROM.BIN').write_bytes(data)
        result=verify(self.folder,self.rom)
        self.assertFalse(result['active_rom_chain_matches_prom'])
        self.assertFalse(result['hardware_entry_enabled'])
    def test_warm_state_does_not_pass_cold_gate(self):
        self.fields['wpr2_hi']=0x100;self.header()
        result=verify(self.folder,self.rom)
        self.assertFalse(result['cold_gate_candidates_match'])
    def test_duplicate_header_rejected(self):
        with (self.folder/'CAPTURE.TXT').open('a') as stream:stream.write('capture_complete=1\n')
        with self.assertRaises(ValueError):verify(self.folder,self.rom)
    def test_exact_firmware_prefix_is_identified(self):
        data=self.rom.read_bytes();meta=inspect_rom(data)
        start=meta['file_view_offset'];size=sum(x['bytes'] for x in meta['images'][:2])
        (self.folder/'EFI-ROM.BIN').write_bytes(data[start:start+size])
        self.fields['rom_bytes']=size;self.header()
        result=verify(self.folder,self.rom)
        self.assertFalse(result['active_rom_chain_matches_efi_rom'])
        self.assertTrue(result['efi_rom_matches_exact_legacy_efi_prefix'])
        self.assertFalse(result['hardware_entry_enabled'])
    def test_changed_firmware_prefix_does_not_match(self):
        data=self.rom.read_bytes();meta=inspect_rom(data)
        start=meta['file_view_offset'];size=sum(x['bytes'] for x in meta['images'][:2])
        prefix=bytearray(data[start:start+size]);prefix[100]^=1
        (self.folder/'EFI-ROM.BIN').write_bytes(prefix)
        self.fields['rom_bytes']=size;self.header()
        self.assertFalse(verify(self.folder,self.rom)['efi_rom_matches_exact_legacy_efi_prefix'])
    def test_board_ss1_difference_does_not_relax_reference_gate(self):
        self.fields['ss1']=3;self.header()
        result=verify(self.folder,self.rom)
        self.assertTrue(result['ss1_override_enable_clear'])
        self.assertFalse(result['cold_gate_candidates_match'])
        self.assertFalse(result['hardware_entry_enabled'])

if __name__=='__main__':unittest.main(verbosity=2)
