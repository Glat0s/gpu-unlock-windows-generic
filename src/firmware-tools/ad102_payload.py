#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""AD102 610.43.03 candidate: Four ordered PLM writes -> explicit mailbox marker -> cleanup.

This is a debug-plaintext-derived experimental port. The bounded interpreter
checks the selected post-DMA path under modeled successful I/O. It does not
model BROM, secure DMA, production/debug equivalence or physical hardware.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import re
import struct
from pathlib import Path

IMAGE_SHA = '7cdc788c0732c64d655349bda821e78a3ebb0155324a9f439cc1714ccd8a8a85'
BODY_SHA = '4389ebbf6a829ed3bbeed4d3898d82cc80f395d1e9be8ccbac191c38d3429d9b'
SIZE, DMEM_BASE, CANARY, MARKER = 0xfa00, 0x600, 0x19c, 0x67b00001
TARGETS = [(0x1fa7cc,0xfffff0ff),(0x9a0148,0xffffffff),(0x1fa7c4,0xffffffff),(0x823804,0xffffffff)]

def sha(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()

def payload() -> bytes:
    b=bytearray(struct.pack('<I',CANARY)*(SIZE//4))
    fields={0x1100:7,0xf948:TARGETS[0][1],0xf950:0x21b2,
            0xf960:TARGETS[0][0],0xf968:0x33fc,0xf974:0xffffffff,
            0xf97c:0x256f}
    # Three additional argument setup / BAR helper calls, then one marker.
    # Every offset is checked by the instruction interpreter below.
    for i,base in enumerate((0xf980,0xf9a4,0xf9c8),start=1):
        fields.update({base:0x7a02,base+4:TARGETS[i][0],base+12:0x33fc,
                       base+24:0xffffffff if i<3 else MARKER,base+32:0x256f})
    fields.update({0xf9ec:0x7a02,0xf9f8:0x31b5,0xf9fc:0x771e})
    for off,val in fields.items():struct.pack_into('<I',b,off,val)
    return bytes(b)

def decode_file(image: bytes, path: Path) -> dict[int,tuple[bytes,str]]:
    if sha(image)!=IMAGE_SHA or sha(image[0x100:])!=BODY_SHA:
        raise ValueError('AD102 debug plaintext hash mismatch')
    ins={}
    for line in path.read_text().splitlines():
        m=re.match(r'^([0-9a-f]{8}): ((?:[0-9a-f]{2} )+)\s*(?:[BC] +)?(.+?)\s*$',line)
        if not m or '[incomplete]' in line:continue
        pc=int(m[1],16); raw=bytes.fromhex(m[2]);asm=m[3].strip()
        if image[pc:pc+len(raw)]!=raw:raise ValueError(f'disassembly bytes differ at {pc:#x}')
        ins[pc]=(raw,asm)
    if len(ins)!=10383:raise ValueError(f'unexpected instruction count: {len(ins)}')
    required={0x21b2:'mov b32 $r10 $r0',0x33fc:'mov b32 $r11 $r10',
              0x256f:'add $sp -0x4',0x7a02:'mov $r9 $sp',
              0x31b5:'add $sp -0x4',0x771e:'mov $r14 0xf100',0x7781:'exit'}
    for pc,asm in required.items():
        if ins[pc][1]!=asm:raise ValueError(f'gadget mismatch: {pc:#x}')
    return ins

class Model:
    def __init__(self, ins, data, io_error_at=None, blocked_write=False):
        self.ins=ins;self.mem=bytearray(0x10000);self.mem[DMEM_BASE:]=data
        self.r=[CANARY]*16;self.sp=0xff30;self.pc=0x1deb
        self.eq=True;self.io={0x9100:0,0x1c000:0,0xf100:0}
        self.bar_writes=[];self.mailbox=[];self.io_writes=[];self.visited=set()
        self.steps=0;self.exited=False;self.io_error_at=io_error_at;self.blocked_write=blocked_write
        self.lowest_sp=self.sp;self.outside_selected_path=False
    def read32(self,a):
        if a<0 or a+4>len(self.mem) or a&3:raise ValueError(f'DMEM read out of range/alignment: {a:#x}')
        return struct.unpack_from('<I',self.mem,a)[0]
    def write32(self,a,v):
        if a<0 or a+4>len(self.mem) or a&3:raise ValueError(f'DMEM write out of range/alignment: {a:#x}')
        struct.pack_into('<I',self.mem,a,v&0xffffffff)
    def value(self,s):
        if s=='$sp':return self.sp
        if s.startswith('$r'):return self.r[int(s[2:])]
        return int(s,0)&0xffffffff
    def assign(self,s,v):
        v &= 0xffffffff
        if s=='$sp':self.sp=v;self.lowest_sp=min(self.sp,self.lowest_sp)
        else:self.r[int(s[2:])]=v
    def addr(self,s):
        # Addresses are register plus an optional positive immediate.
        return sum(self.value(x) for x in s.split('+'))
    def push(self,v):self.sp-=4;self.lowest_sp=min(self.sp,self.lowest_sp);self.write32(self.sp,v)
    def pop(self):v=self.read32(self.sp);self.sp+=4;return v
    def run(self,max_steps=100000):
        while not self.exited and self.steps<max_steps:
            if self.pc not in self.ins:raise ValueError(f'PC is not an instruction boundary: {self.pc:#x}')
            raw,asm=self.ins[self.pc];self.visited.add(self.pc);self.steps+=1
            pc,next_pc=self.pc,self.pc+len(raw)
            tok=asm.split();op=tok[0];args=tok[1:]
            if args and args[0] in ('b32','b8'):width=args.pop(0)
            else:width='b32'
            if op=='mov':self.assign(args[0],self.value(args[1]))
            elif op=='clear':self.assign(args[0],0)
            elif op=='add':self.assign(args[0],self.value(args[0])+self.value(args[1]) if len(args)==2 else self.value(args[1])+self.value(args[2]))
            elif op=='and':self.assign(args[0],self.value(args[0])&self.value(args[1]) if len(args)==2 else self.value(args[1])&self.value(args[2]))
            elif op=='or':self.assign(args[0],self.value(args[0])|self.value(args[1]) if len(args)==2 else self.value(args[1])|self.value(args[2]))
            elif op=='shr':self.assign(args[0],self.value(args[0])>>self.value(args[1]))
            elif op=='extr':
                lo,hi=map(lambda x:int(x,0),args[2].split(':'))
                self.assign(args[0],(self.value(args[1])>>lo)&((1<<(hi-lo+1))-1))
            elif op=='cmp':self.eq=self.value(args[0])==self.value(args[1])
            elif op=='ld':self.assign(args[0],self.read32(self.addr(args[1][2:-1])))
            elif op=='st':self.write32(self.addr(args[0][2:-1]),self.value(args[1]))
            elif op=='mpush':
                for i in range(int(args[0][2:])+1):self.push(self.r[i])
            elif op=='mpopaddret':
                for i in range(int(args[0][2:]),-1,-1):self.r[i]=self.pop()
                self.sp+=self.value(args[1]);next_pc=self.pop()
            elif op=='lcall':self.push(next_pc);next_pc=self.value(args[0])
            elif op=='ret':next_pc=self.pop()
            elif op=='lbra':next_pc=self.value(args[0])
            elif op=='bra':
                if len(args)==2:cond=self.eq if args[0]=='e' else not self.eq
                elif len(args)==4:
                    mask=0xff if width=='b8' else 0xffffffff
                    eq=(self.value(args[0])&mask)==(self.value(args[1])&mask)
                    cond=eq if args[2]=='e' else not eq
                else:raise ValueError(f'unsupported branch {asm}')
                if cond:next_pc=self.value(args[-1])
            elif op in ('iords','iord'):
                a=self.addr(args[1][2:-1]);v=self.io.get(a,0)
                if self.io_error_at==a:v=0x80000000 if a==0x9100 else 0xbadf5620
                self.assign(args[0],v)
            elif op in ('iowrs','iowr'):
                a=self.addr(args[0][2:-1]);v=self.value(args[1]);self.io_writes.append((a,v))
                if a==0x1c000:
                    if v!=0x800000f2:raise ValueError('unexpected BAR command')
                    pair=(self.io[0x1c100],self.io[0x1c200])
                    if pair not in TARGETS:raise ValueError('unexpected BAR write target/value')
                    if not self.blocked_write:self.bar_writes.append(pair)
                    self.io[a]=0
                else:self.io[a]=v
                if a==0x1000:self.mailbox.append(v)
            elif op=='exit':self.exited=True
            else:raise ValueError(f'unmodeled opcode at {pc:#x}: {asm}')
            self.pc=next_pc
        return self

def audit(image, disasm):
    ins=decode_file(image,disasm);cases=[]
    m=Model(ins,payload()).run()
    assert m.exited and m.bar_writes==TARGETS and m.mailbox==[MARKER]
    assert not any(m.mem) and not any(m.r)
    cases.append({'ordered_writes':[(hex(a),hex(v)) for a,v in m.bar_writes],
                  'steps':m.steps,'marker':hex(MARKER),'exit':m.exited,
                  'dmem_zero':not any(m.mem),'gpr_zero':not any(m.r),
                  'lowest_sp':hex(m.lowest_sp)})
    # Check data corruption is rejected before issuing the intended BAR write.
    bad=bytearray(payload());struct.pack_into('<I',bad,0x5f50-DMEM_BASE,0)
    m=Model(ins,bad).run(max_steps=2000)
    assert not m.bar_writes and m.mailbox==[0x47] and not m.exited
    m=Model(ins,payload(),io_error_at=0x9100).run(max_steps=2000)
    assert not m.bar_writes and MARKER not in m.mailbox
    # A marker may still be written when hardware ignores a BAR request.
    # This is why runtime PLM readback is mandatory in addition to the marker.
    m=Model(ins,payload(),blocked_write=True).run()
    assert m.exited and m.mailbox==[MARKER] and not m.bar_writes
    return {'scope':'Bounded selected post-DMA debug-code interpreter with modeled I/O; not hardware authentication or production verification',
            'plaintext_sha256':sha(image),'payload_bytes':SIZE,'payload_sha256':sha(payload()),
            'post_dma_assumptions':{'entire_signature_copied':True,'dmem_base':hex(DMEM_BASE),'pc':hex(0x1deb),'sp':hex(0xff30),'canary':hex(CANARY)},
            'success_cases':cases,'negative_cases':['canary corruption stops before BAR write','I/O error prevents normal marker','ignored BAR write can still yield marker; runtime readback required'],
            'limitations':['Debug/production code equality not established','No BROM/authentication/HS or DMA model','Inherited D[0x1700]=7 semantics not fully known','Cleanup-tail entry bypasses earlier stock crypto-state restoration; no stock-teardown equivalence claimed','Post-DMA path only; all physical outcomes remain unverified']}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('image',type=Path);p.add_argument('disasm',type=Path);p.add_argument('output',type=Path)
    a=p.parse_args();report=audit(a.image.read_bytes(),a.disasm)
    a.output.mkdir(parents=True,exist_ok=True)
    (a.output/'v67-ad102-610.43.03-four-plm.bin').write_bytes(payload())
    (a.output/'ad102-payload-audit.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
if __name__=='__main__':main()
