/* SPDX-License-Identifier: GPL-2.0-only -- synthetic host fixtures, no hardware. */
#include "capture.h"
#include <IndustryStandard/Acpi.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int Mode,Allocations,MemReads,PromReads,Saves;
static EFI_PCI_IO_PROTOCOL Pci;
static UINT8 Rom[512];
static EFI_STATUS EFIAPI Alloc(EFI_MEMORY_TYPE Type,UINTN Size,VOID **Out) {
  (void)Type;*Out=malloc(Size);if(!*Out)return EFI_OUT_OF_RESOURCES;Allocations++;return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI Free(VOID *Value) {assert(Value);free(Value);Allocations--;return EFI_SUCCESS;}
static EFI_STATUS EFIAPI Config(EFI_PCI_IO_PROTOCOL *Self,EFI_PCI_IO_PROTOCOL_WIDTH Width,UINT32 Offset,UINTN Count,VOID *Buffer) {
  assert(Self==&Pci && Width==EfiPciIoWidthUint32 && Offset==0 && Count==64);
  UINT32 *p=Buffer;memset(p,0,256);p[0]=Mode==1?0x268510deU:0x268410deU;
  p[1]=Mode==4?0:3;p[2]=0x030000a1U;p[11]=Mode==2?0x13bb196eU:0x13ba196eU;
  if(Mode==10 && MemReads)p[1]^=1;
  return Mode==12?EFI_DEVICE_ERROR:EFI_SUCCESS;
}
static EFI_STATUS EFIAPI Location(EFI_PCI_IO_PROTOCOL *Self,UINTN *Segment,UINTN *Bus,UINTN *Device,UINTN *Function) {
  assert(Self==&Pci);*Segment=0;*Bus=Mode==3?2:1;*Device=*Function=0;return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI Bar(EFI_PCI_IO_PROTOCOL *Self,UINT8 Index,UINT64 *Supports,VOID **Resources) {
  (void)Supports;assert(Self==&Pci);if(Index)return EFI_UNSUPPORTED;
  UINT8 *raw=NULL;EFI_STATUS status=Alloc(EfiBootServicesData,sizeof(EFI_ACPI_ADDRESS_SPACE_DESCRIPTOR)+2,(VOID **)&raw);
  if(EFI_ERROR(status))return status;
  memset(raw,0,sizeof(EFI_ACPI_ADDRESS_SPACE_DESCRIPTOR)+2);
  EFI_ACPI_ADDRESS_SPACE_DESCRIPTOR *r=(VOID *)raw;
  r->Desc=ACPI_ADDRESS_SPACE_DESCRIPTOR;r->Len=sizeof(*r)-3;r->ResType=0;
  r->AddrRangeMin=0x80000000ULL;r->AddrLen=Mode==5?0x1000:0x1000000;
  raw[sizeof(*r)]=ACPI_END_TAG_DESCRIPTOR;*Resources=raw;return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI Memory(EFI_PCI_IO_PROTOCOL *Self,EFI_PCI_IO_PROTOCOL_WIDTH Width,UINT8 Index,UINT64 Offset,UINTN Count,VOID *Buffer) {
  assert(Self==&Pci && Width==EfiPciIoWidthUint32 && Index==0);MemReads++;
  if(Count==1){*(UINT32 *)Buffer=Offset==0?(Mode==6?0x193000a1U:0x192000a1U):0x1234;return EFI_SUCCESS;}
  assert(Count==1024 && Offset>=0x300000 && Offset+Count*4<=0x400000);PromReads++;
  if(Mode==9)return EFI_DEVICE_ERROR;
  memset(Buffer,0x5a,Count*4);return EFI_SUCCESS;
}
static EFI_STATUS Save(const CHAR16 *Name,const VOID *Data,UINTN Bytes,VOID *Context) {
  (void)Context;assert(Name && Data && Bytes);Saves++;
  if(Mode==11 && Name[0]=='P' && Name[1]=='R')return EFI_DEVICE_ERROR;
  return EFI_SUCCESS;
}
int main(void) {
  EFI_BOOT_SERVICES bs={.AllocatePool=Alloc,.FreePool=Free};
  for(Mode=0;Mode<=12;Mode++) {
    Allocations=MemReads=PromReads=Saves=0;memset(&Pci,0,sizeof(Pci));
    Pci.Pci.Read=Config;Pci.Mem.Read=Memory;Pci.GetLocation=Location;Pci.GetBarAttributes=Bar;
    /* All GPU write, DMA, attribute-change and reset interfaces remain NULL.
       Any accidental use crashes the native test rather than touching hardware. */
    Pci.RomImage=Mode==7?NULL:Rom;Pci.RomSize=Mode==8?17U*1024U*1024U:sizeof(Rom);
    EFI_STATUS status=GuReadOnlyCapture(&bs,&Pci,Save,NULL);
    if(Mode==0 || Mode==10)assert(status==EFI_SUCCESS);
    else assert(EFI_ERROR(status));
    assert(Allocations==0);
    if(Mode>=1 && Mode<=5)assert(MemReads==0);
    if(Mode==0 || Mode==10)assert(PromReads==256 && Saves==5);
    printf("read-only capture synthetic mode=%d result=%llx PASS\n",Mode,(unsigned long long)status);
  }
  assert(GuReadOnlyCapture(NULL,&Pci,Save,NULL)==EFI_INVALID_PARAMETER);
  return 0;
}
