/* SPDX-License-Identifier: GPL-2.0-only
 * Diagnostic only. No PCI/MMIO writes, DMA mapping, resets or firmware loading.
 */
#include "capture.h"
#include "format.h"
#include "runtime.h"
#include "../unlock/gpu_catalog.h"
#include <IndustryStandard/Acpi.h>
#include <stdarg.h>
#include <stdint.h>

#define PROM_OFFSET 0x300000U
#define PROM_BYTES 1048576U
typedef struct {const char *Name;UINT32 Offset;} REGISTER;
static const REGISTER Registers[]={
  {"chip",0},{"vram_mib",0x1183a4},{"gfw_plm",0x118128},
  {"gfw_boot",0x118234},{"gfw_cpuctl",0x110100},
  {"wpr2_lo",0x1fa824},{"wpr2_hi",0x1fa828},
  {"wpr_cfg_plm",0x1fa7cc},{"fbpa_plm",0x9a0148},{"wpr_plm",0x1fa7c4},
  {"feat_plm",0x823804},{"effective_rates",0x823818},
  {"ss0",0x82381c},{"ss1",0x823820},
  {"sec2_cpuctl",0x840100},{"sec2_reset_plm_raw",0x8403c4},
  {"source_enable_candidate_raw",0x823b00},{"vga_base_raw",0x100c10}
};
static BOOLEAN Append(char *Text,UINTN *Used,const char *Format,...) {
  va_list args;va_start(args,Format);
  size_t size=GuFormatV(Text+*Used,16384-*Used,Format,args);va_end(args);
  if(size>=16384-*Used)return FALSE;
  *Used+=size;return TRUE;
}
EFI_STATUS GuReadOnlyCapture(EFI_BOOT_SERVICES *Bs,EFI_PCI_IO_PROTOCOL *Pci,
                            GU_CAPTURE_SAVE Save,VOID *Context) {
  if(!Bs || !Pci || !Save || !Bs->AllocatePool || !Bs->FreePool ||
     !Pci->Pci.Read || !Pci->Mem.Read || !Pci->GetLocation || !Pci->GetBarAttributes)
    return EFI_INVALID_PARAMETER;
  UINT32 before[64],after[64];UINTN segment,bus,device,function;
  EFI_STATUS status=Pci->Pci.Read(Pci,EfiPciIoWidthUint32,0,64,before);
  if(EFI_ERROR(status))return status;
  status=Pci->GetLocation(Pci,&segment,&bus,&device,&function);
  if(EFI_ERROR(status))return status;
  if(!GuIsSupportedBoardId(before[0]) ||
     (before[2]>>24)!=0x03U)return EFI_UNSUPPORTED;
  status=Save(L"PCI-BEFORE.BIN",before,sizeof(before),Context);
  if(EFI_ERROR(status))return status;
  char *text=NULL;
  status=Bs->AllocatePool(EfiBootServicesData,16384,(VOID **)&text);
  if(EFI_ERROR(status) || !text)return EFI_OUT_OF_RESOURCES;
  UINTN used=0;UINT8 *prom=NULL;UINT64 bar_bytes=0;BOOLEAN complete=FALSE;
  if(!Append(text,&used,"format=RTX4090-READONLY-CAPTURE-V1\nboard_id=%#x\nsubsystem=%#x\nsegment=%zu\nbus=%zu\ndevice=%zu\nfunction=%zu\ncommand=%#x\nconfig_c8=%#x\nrom_bytes=%llu\nprom_bar_offset=%#x\nprom_bytes=%u\ngpu_writes=0\ndma_mappings=0\nfirmware_launches=0\n",
      before[0],before[0x2c/4],(size_t)segment,(size_t)bus,(size_t)device,(size_t)function,
      before[1]&0xffff,before[0xc8/4],(unsigned long long)Pci->RomSize,PROM_OFFSET,PROM_BYTES))
    {status=EFI_BAD_BUFFER_SIZE;goto done;}
  for(UINT8 bar=0;bar<6;bar++) {
    EFI_ACPI_ADDRESS_SPACE_DESCRIPTOR *r=NULL;
    EFI_STATUS query=Pci->GetBarAttributes(Pci,bar,NULL,(VOID **)&r);
    BOOLEAN valid=!EFI_ERROR(query) && r && r->Desc==ACPI_ADDRESS_SPACE_DESCRIPTOR &&
      r->Len==sizeof(*r)-3 && ((UINT8 *)(r+1))[0]==ACPI_END_TAG_DESCRIPTOR;
    if(!Append(text,&used,"bar%u_status=%#llx\nbar%u_descriptor_valid=%u\n",(unsigned)bar,
        (unsigned long long)query,(unsigned)bar,(unsigned)valid))status=EFI_BAD_BUFFER_SIZE;
    if(valid) {
      if(!Append(text,&used,"bar%u_base=%#llx\nbar%u_bytes=%#llx\nbar%u_type=%u\nbar%u_granularity=%llu\nbar%u_max=%#llx\nbar%u_translation=%#llx\n",
         (unsigned)bar,(unsigned long long)r->AddrRangeMin,(unsigned)bar,(unsigned long long)r->AddrLen,
         (unsigned)bar,(unsigned)r->ResType,(unsigned)bar,(unsigned long long)r->AddrSpaceGranularity,
         (unsigned)bar,(unsigned long long)r->AddrRangeMax,(unsigned)bar,(unsigned long long)r->AddrTranslationOffset))status=EFI_BAD_BUFFER_SIZE;
      if(bar==0 && r->ResType==0 && !r->AddrTranslationOffset && r->AddrRangeMin &&
         r->AddrLen && r->AddrRangeMin<=UINT64_MAX-r->AddrLen)bar_bytes=r->AddrLen;
    }
    if(r)Bs->FreePool(r);
    if(EFI_ERROR(status))goto done;
  }
  /* Never enable memory decoding: absent access stays a diagnostic failure. */
  if(!(before[1]&2U) || bar_bytes<0x9a014cU || bar_bytes>0x10000000ULL) {
    status=EFI_NOT_READY;goto done;
  }
  for(UINTN index=0;index<sizeof(Registers)/sizeof(Registers[0]);index++) {
    UINT32 value=0;
    status=Pci->Mem.Read(Pci,EfiPciIoWidthUint32,0,Registers[index].Offset,1,&value);
    if(!Append(text,&used,"%s_offset=%#x\n%s_status=%#llx\n%s=%#x\n",Registers[index].Name,
       Registers[index].Offset,Registers[index].Name,(unsigned long long)status,Registers[index].Name,value))
      {status=EFI_BAD_BUFFER_SIZE;goto done;}
    if(EFI_ERROR(status))goto done;
    if(index==0 && !GuIsValidChipForArch(value, GU_ARCH_AUTO)){status=EFI_UNSUPPORTED;goto done;}
  }
  if(Pci->RomImage && Pci->RomSize && Pci->RomSize<=16U*1024U*1024U) {
    status=Save(L"EFI-ROM.BIN",Pci->RomImage,(UINTN)Pci->RomSize,Context);
    if(EFI_ERROR(status))goto done;
  }
  status=Bs->AllocatePool(EfiBootServicesData,PROM_BYTES,(VOID **)&prom);
  if(EFI_ERROR(status) || !prom){status=EFI_OUT_OF_RESOURCES;goto done;}
  for(UINTN offset=0;offset<PROM_BYTES;offset+=4096) {
    status=Pci->Mem.Read(Pci,EfiPciIoWidthUint32,0,PROM_OFFSET+offset,1024,prom+offset);
    if(EFI_ERROR(status))goto done;
  }
  status=Save(L"PROM.BIN",prom,PROM_BYTES,Context);
  if(EFI_ERROR(status))goto done;
  status=Pci->Pci.Read(Pci,EfiPciIoWidthUint32,0,64,after);
  if(EFI_ERROR(status))goto done;
  status=Save(L"PCI-AFTER.BIN",after,sizeof(after),Context);
  if(EFI_ERROR(status))goto done;
  complete=TRUE;
  if(!Append(text,&used,"pci_unchanged=%u\n",(unsigned)(memcmp(before,after,sizeof(before))==0)))status=EFI_BAD_BUFFER_SIZE;
done:
  if(prom)Bs->FreePool(prom);
  if(!Append(text,&used,"capture_complete=%u\nfinal_status=%#llx\nunlock_enabled=0\n",(unsigned)complete,(unsigned long long)status))
    status=EFI_BAD_BUFFER_SIZE;
  EFI_STATUS written=Save(L"CAPTURE.TXT",text,used,Context);
  Bs->FreePool(text);
  return EFI_ERROR(status)?status:written;
}
