/* SPDX-License-Identifier: GPL-2.0-only
 * RTX 4090 (AD102) Windows UEFI Unlocker - Tailored & Generic Application
 */
#include "app.h"
#include "app_io.h"
#include "compat/compat.h"
#include "checks.h"
#include "config.h"
#include "sha256.h"
#include "prom_profile.h"
#include "ownership.h"
#include "selector_check.h"
#include "vendor/unlock_610.h"
#include "vendor/vbios_610.h"
#include "vendor/gfw_eval.h"
#include <Protocol/GraphicsOutput.h>
#include <IndustryStandard/Acpi.h>
#include <Guid/GlobalVariable.h>

static EFI_GUID PciGuid=EFI_PCI_IO_PROTOCOL_GUID,GopGuid=EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID,
  PathGuid=EFI_DEVICE_PATH_PROTOCOL_GUID,GlobalGuid=EFI_GLOBAL_VARIABLE;
static EFI_SYSTEM_TABLE *Table;
static UINT32 InitialConfig[64];
static UINT32 InitialColdSs0,InitialColdSs1;
static BOOLEAN InitialColdValid;
static BOOLEAN SkipToWindows;
static const char *Stage;
static BOOLEAN ExpectDetached;
static GU_RELEASE_OWNER PendingOwner;
static struct {
  BOOLEAN valid;
  UINT32 mode;
  EFI_GRAPHICS_OUTPUT_MODE_INFORMATION info;
  UINT8 path_hash[32],remaining[4096];
  UINTN remaining_bytes;
} SavedDisplay;

static BOOLEAN DisplayRoute(EFI_DEVICE_PATH_PROTOCOL *Path,UINT8 Hash[32],UINT8 *Suffix,UINTN *SuffixBytes) {
  if(!Path)return FALSE;
  UINTN bytes=0;BOOLEAN end=FALSE;
  for(UINTN i=0;i<128 && bytes<=4092;i++) {
    EFI_DEVICE_PATH_PROTOCOL *n=(VOID*)((UINT8*)Path+bytes);
    UINTN len=n->Length[0]+((UINTN)n->Length[1]<<8);
    if(len<4 || len>4096-bytes)return FALSE;
    bytes+=len;
    if(n->Type==END_DEVICE_PATH_TYPE) {
      if(n->SubType!=END_ENTIRE_DEVICE_PATH_SUBTYPE || len!=4)return FALSE;
      end=TRUE;break;
    }
  }
  if(!end)return FALSE;
  EFI_DEVICE_PATH_PROTOCOL *remaining=Path;EFI_HANDLE parent=NULL;
  EFI_STATUS s=Gu.bs->LocateDevicePath(&PciGuid,&remaining,&parent);
  UINTN start=(UINTN)Path,at=(UINTN)remaining;
  if(EFI_ERROR(s) || parent!=Gu.handle || at<start || at-start>bytes-4)return FALSE;
  UINTN offset=0;
  while(offset<at-start) {
    EFI_DEVICE_PATH_PROTOCOL *n=(VOID*)((UINT8*)Path+offset);
    offset+=n->Length[0]+((UINTN)n->Length[1]<<8);
  }
  if(offset!=at-start)return FALSE;
  GuSha256(Path,bytes,Hash);
  if(Suffix && SuffixBytes){*SuffixBytes=bytes-offset;memcpy(Suffix,(UINT8*)Path+offset,*SuffixBytes);}
  return TRUE;
}

static BOOLEAN SameVideoInfo(const EFI_GRAPHICS_OUTPUT_MODE_INFORMATION *a,const EFI_GRAPHICS_OUTPUT_MODE_INFORMATION *b) {
  return a && b && a->Version==b->Version && a->HorizontalResolution==b->HorizontalResolution &&
    a->VerticalResolution==b->VerticalResolution && a->PixelFormat==b->PixelFormat &&
    a->PixelsPerScanLine==b->PixelsPerScanLine;
}

static EFI_STATUS Step(EFI_STATUS Status) {
  GuLog("CHECK stage=%s status=%#llx\n",Stage,(unsigned long long)Status);
  return !GuLogReady() && !EFI_ERROR(Status)?EFI_DEVICE_ERROR:Status;
}

static VOID ConfigLog(const UINT32 *Config) {
  for(UINTN i=0;i<64;i+=4)GuLog("config[%02x]=%08x %08x %08x %08x\n",
    (unsigned)(i*4),Config[i],Config[i+1],Config[i+2],Config[i+3]);
}

static BOOLEAN DisplayCheck(VOID) {
  EFI_HANDLE *handles=NULL;UINTN count=0,physical=0,matched=0;
  EFI_STATUS status=Gu.bs->LocateHandleBuffer(ByProtocol,&GopGuid,NULL,&count,&handles);
  if(status==EFI_NOT_FOUND) {
    GuLog("GOP LocateHandleBuffer: EFI_NOT_FOUND expect_detached=%u\n",ExpectDetached);
    return (ExpectDetached || GuCfg.allow_headless_handoff) && GuLogReady();
  }
  if(EFI_ERROR(status) || count>128 || (count && !handles)){if(handles)GuFree(handles);return FALSE;}
  for(UINTN i=0;i<count;i++) {
    EFI_GRAPHICS_OUTPUT_PROTOCOL *g=NULL;EFI_DEVICE_PATH_PROTOCOL *path=NULL;
    status=Gu.bs->HandleProtocol(handles[i],&GopGuid,(VOID **)&g);
    if(EFI_ERROR(status) || !g || !g->Mode){status=EFI_COMPROMISED_DATA;break;}
    GuLog("GOP[%zu] handle=%#llx mode=%u max=%u info_bytes=%zu framebuffer=%#llx bytes=%zu\n",
      (size_t)i,(unsigned long long)(UINTN)handles[i],g->Mode->Mode,g->Mode->MaxMode,
      (size_t)g->Mode->SizeOfInfo,(unsigned long long)g->Mode->FrameBufferBase,(size_t)g->Mode->FrameBufferSize);
    if(!g->Mode->FrameBufferBase && !g->Mode->FrameBufferSize)continue;
    physical++;
    status=Gu.bs->HandleProtocol(handles[i],&PathGuid,(VOID **)&path);
    if(EFI_ERROR(status) || !path)continue;
    EFI_DEVICE_PATH_PROTOCOL *remaining=path;
    EFI_HANDLE parent=NULL;
    EFI_STATUS loc_status=Gu.bs->LocateDevicePath(&PciGuid,&remaining,&parent);
    if(EFI_ERROR(loc_status) || parent!=Gu.handle) {
      /* GOP belongs to another display adapter (e.g. iGPU); ignore it. */
      status=EFI_SUCCESS;
      continue;
    }
    if(!g->Mode->Info || g->Mode->SizeOfInfo<sizeof(*g->Mode->Info) ||
       g->Mode->Mode>=g->Mode->MaxMode ||
       !g->Mode->FrameBufferSize || !g->Mode->Info->VerticalResolution ||
       !g->Mode->Info->HorizontalResolution || g->Mode->Info->PixelFormat>PixelBlueGreenRedReserved8BitPerColor ||
       g->Mode->Info->PixelsPerScanLine<g->Mode->Info->HorizontalResolution ||
       (UINT64)g->Mode->Info->PixelsPerScanLine*g->Mode->Info->VerticalResolution>g->Mode->FrameBufferSize/4) {
      status=EFI_COMPROMISED_DATA;break;
    }
    if(!Gu.started && !ExpectDetached) {
      UINT8 hash[32];
      if(!DisplayRoute(path,hash,SavedDisplay.valid?NULL:SavedDisplay.remaining,
        SavedDisplay.valid?NULL:&SavedDisplay.remaining_bytes)){status=EFI_UNSUPPORTED;break;}
      if(!SavedDisplay.valid) {
        SavedDisplay.mode=g->Mode->Mode;SavedDisplay.info=*g->Mode->Info;
        memcpy(SavedDisplay.path_hash,hash,32);SavedDisplay.valid=TRUE;
      } else if(matched==0 && (memcmp(hash,SavedDisplay.path_hash,32) || g->Mode->Mode!=SavedDisplay.mode ||
        !SameVideoInfo(g->Mode->Info,&SavedDisplay.info))) {
        status=EFI_NOT_READY;break;
      }
    }
    matched++;
  }
  GuFree(handles);
  GuLog("GOP physical=%zu target_matched=%zu expect_detached=%u status=%#llx\n",(size_t)physical,(size_t)matched,
    ExpectDetached,(unsigned long long)status);
  if(EFI_ERROR(status) || !GuLogReady())return FALSE;
  if(ExpectDetached)return matched==0;
  return matched>=1 || GuCfg.allow_headless_handoff;
}

#include "handoff.inc"

static EFI_STATUS ReadConfig(UINT32 *Config) {
  for(UINTN i=0;i<64;i++)if(EFI_ERROR(GuConfigRead(EfiPciIoWidthUint32,(UINT32)i*4,&Config[i]))) {
    GuLog("PCI config read failed: offset=%#x valid_bytes=%u; snapshot incomplete\n",(unsigned)(i*4),(unsigned)(i*4));
    return EFI_DEVICE_ERROR;
  }
  return EFI_SUCCESS;
}

static EFI_STATUS ClearFirmwareBmeIfSet(VOID) {
  if(!Gu.pci || !Gu.owned)return EFI_ACCESS_DENIED;
  UINT16 cmd=0,after=0;
  EFI_STATUS s=GuConfigRead(EfiPciIoWidthUint16,4,&cmd);
  if(EFI_ERROR(s) || cmd==0xffff)return EFI_DEVICE_ERROR;
  if(cmd & 4U) {
    GuLog("Clearing firmware/GOP Bus Master Enable before transaction (command=%#x)\n",cmd);
    if(Gu.pci->Attributes) {
      (void)Gu.pci->Attributes(Gu.pci,EfiPciIoAttributeOperationDisable,EFI_PCI_IO_ATTRIBUTE_BUS_MASTER,NULL);
    }
    UINT16 cleared=(UINT16)(cmd & ~4U);
    s=Gu.pci->Pci.Write(Gu.pci,EfiPciIoWidthUint16,4,1,&cleared);
    if(EFI_ERROR(s))return s;
    s=GuConfigRead(EfiPciIoWidthUint16,4,&after);
    if(EFI_ERROR(s) || (after & 4U))return EFI_DEVICE_ERROR;
    InitialConfig[1]=(InitialConfig[1] & ~0xffffU) | (UINT32)after;
    GuLog("Firmware/GOP Bus Master Enable cleared: command=%#x\n",after);
  }
  return EFI_SUCCESS;
}

static EFI_STATUS ConfigCheck(BOOLEAN Save) {
  UINT32 config[64];GU_CAPS caps;UINTN segment,bus,device,function;
  EFI_STATUS status=Gu.pci->GetLocation(Gu.pci,&segment,&bus,&device,&function);
  GuLog("target location: status=%#llx\n",(unsigned long long)status);
  if(EFI_ERROR(status))return status;
  status=ReadConfig(config);if(EFI_ERROR(status))return status;
  BOOLEAN checked=GuCheckConfig(config,segment,bus,device,function,&caps);
  UINT32 bar0_reg = config[0x10/4] & ~0xfU;
  BOOLEAN bar0_ok = bar0_reg != 0 && (!GuCfg.strict_bar0 || !GuCfg.bar0_base || bar0_reg == (UINT32)GuCfg.bar0_base);
  BOOLEAN valid=checked && ((config[2]>>24)==0x03) && bar0_ok && !(config[(caps.pcie+8)/4]&0x00200000U);
  BOOLEAN same=Save || !memcmp(config,InitialConfig,sizeof(config));
  if(Save || !valid || !same)ConfigLog(config);
  GuLog("target BDF=%zu:%zu:%zu.%zu subsys=%#x bar0_reg=%#x checks=%u pm=%#x pcie=%#x msi=%#x msix=%#x\n",
    (size_t)segment,(size_t)bus,(size_t)device,(size_t)function,config[11],bar0_reg,checked,
    (unsigned)caps.pm,(unsigned)caps.pcie,(unsigned)caps.msi,(unsigned)caps.msix);
  if(!valid)return EFI_UNSUPPORTED;
  if(!same)return EFI_NOT_READY;
  if(Save) {
    const GU_GPU_MODEL_INFO *model = GuFindGpuModel((UINT16)(config[0] >> 16));
    memcpy(InitialConfig,config,sizeof(config));
    Gu.target_segment=segment;Gu.target_bus=bus;Gu.target_device=device;Gu.target_function=function;
    Gu.target_board_id=config[0];
    Gu.target_subsystem=config[11];
    if (model) {
      Gu.target_arch = model->arch;
      Gu.target_model_name = model->name;
      Gu.target_chip_family = model->chip_family;
    } else {
      Gu.target_arch = (GuCfg.arch == GU_ARCH_AMPERE) ? GU_ARCH_AMPERE : GU_ARCH_ADA;
      Gu.target_model_name = "NVIDIA GeForce RTX";
      Gu.target_chip_family = (Gu.target_arch == GU_ARCH_AMPERE) ? "GA10x" : "AD10x";
    }
    GuLog("Discovered GPU: %s (%s) [PCI %04x:%04x subsys %08x at %04x:%02x:%02x.%x BAR0 %#x]\n",
      Gu.target_model_name, Gu.target_chip_family,
      (unsigned)(config[0] & 0xffffU), (unsigned)(config[0] >> 16),
      config[11], (unsigned)segment, (unsigned)bus, (unsigned)device, (unsigned)function, bar0_reg);
  }
  Gu.pm_cap=caps.pm;Gu.pcie_cap=caps.pcie;Gu.pcie_version=caps.pcie_version;Gu.msi_cap=caps.msi;Gu.msix_cap=caps.msix;
  return EFI_SUCCESS;
}

static EFI_STATUS RestoreDecode(VOID) {
  UINT32 current[64];UINTN segment,bus,device,function;
  if(!Gu.pci || !Gu.owned || !Gu.armed || !Gu.display_ok || Gu.started || Gu.allocations ||
    Gu.dma_count || Gu.fault || Gu.retained)return EFI_ACCESS_DENIED;
  EFI_STATUS status=Gu.pci->GetLocation(Gu.pci,&segment,&bus,&device,&function);
  if(EFI_ERROR(status))return status;
  status=ReadConfig(current);if(EFI_ERROR(status))return status;
  GuLogText("config before decode restore (256 valid bytes):\n");ConfigLog(current);
  if(!GuTargetConfig(current,segment,bus,device,function))return EFI_UNSUPPORTED;
  UINT32 missing=InitialConfig[1]&~current[1]&3U;
  if(missing) {
    if(!Gu.pci->Attributes)return EFI_UNSUPPORTED;
    UINT64 needed=(missing&1?EFI_PCI_IO_ATTRIBUTE_IO:0)|(missing&2?EFI_PCI_IO_ATTRIBUTE_MEMORY:0);
    UINT64 supported=0;
    status=Gu.pci->Attributes(Gu.pci,EfiPciIoAttributeOperationSupported,0,&supported);
    if(EFI_ERROR(status))return status;
    if((supported&needed)!=needed)return EFI_UNSUPPORTED;
    GuLog("decode restore intent: saved_command=%#x current_command=%#x missing=%#x attributes=%#llx\n",
      InitialConfig[1]&0xffff,current[1]&0xffff,missing,(unsigned long long)needed);
    if(!GuLogReady() || Gu.fault)return EFI_DEVICE_ERROR;
    EFI_STATUS enabled=Gu.pci->Attributes(Gu.pci,EfiPciIoAttributeOperationEnable,needed,NULL);
    GuLog("decode enable status=%#llx\n",(unsigned long long)enabled);
    if(EFI_ERROR(enabled))return enabled;
  } else {
    GuLogText("decode restore not needed\n");
  }
  status=ClearFirmwareBmeIfSet();
  if(EFI_ERROR(status))return status;
  status=ReadConfig(InitialConfig);
  if(EFI_ERROR(status))return status;
  GuLogText("config after decode restore / BME clear (256 valid bytes):\n");ConfigLog(InitialConfig);
  return GuLogReady() && !Gu.fault ? EFI_SUCCESS : EFI_DEVICE_ERROR;
}

static EFI_STATUS FindTarget(VOID) {
  EFI_HANDLE *handles=NULL;UINTN count=0,found=0,preferred_found=0;
  EFI_HANDLE candidate_handle=NULL;EFI_PCI_IO_PROTOCOL *candidate_pci=NULL;
  EFI_HANDLE preferred_handle=NULL;EFI_PCI_IO_PROTOCOL *preferred_pci=NULL;
  EFI_STATUS status=Gu.bs->LocateHandleBuffer(ByProtocol,&PciGuid,NULL,&count,&handles);
  GuLog("PCI enumeration: status=%#llx handles=%zu\n",(unsigned long long)status,(size_t)count);
  if(EFI_ERROR(status) || !handles || !count || count>512){if(handles)GuFree(handles);return EFI_NOT_FOUND;}
  for(UINTN i=0;i<count;i++) {
    EFI_PCI_IO_PROTOCOL *pci=NULL;UINT32 config[16]={0};UINTN seg=0,bus=0,dev=0,func=0;
    status=Gu.bs->HandleProtocol(handles[i],&PciGuid,(VOID **)&pci);
    if(!EFI_ERROR(status) && pci)status=pci->Pci.Read(pci,EfiPciIoWidthUint32,0,16,config);
    if(!EFI_ERROR(status) && pci)status=pci->GetLocation(pci,&seg,&bus,&dev,&func);
    if(EFI_ERROR(status) || !pci){GuLog("PCI scan failed: index=%zu status=%#llx\n",(size_t)i,(unsigned long long)status);status=EFI_DEVICE_ERROR;break;}
    if(GuTargetConfig(config,seg,bus,dev,func)) {
      found++;
      candidate_handle=handles[i];candidate_pci=pci;
      if(GuCfg.pci_bus>=0 && seg==(UINTN)GuCfg.pci_segment && bus==(UINTN)GuCfg.pci_bus &&
         dev==(UINTN)GuCfg.pci_device && func==(UINTN)GuCfg.pci_function) {
        preferred_found++;preferred_handle=handles[i];preferred_pci=pci;
      }
    }
  }
  GuFree(handles);
  if(!EFI_ERROR(status) && found>1 && preferred_found==1) {
    candidate_handle=preferred_handle;candidate_pci=preferred_pci;found=1;
  }
  GuLog("PCI target matches=%zu preferred=%zu status=%#llx\n",(size_t)found,(size_t)preferred_found,(unsigned long long)status);
  if(EFI_ERROR(status) || found!=1)return EFI_UNSUPPORTED;
  Gu.handle=candidate_handle;Gu.pci=candidate_pci;
  return ConfigCheck(TRUE);
}

static EFI_STATUS BarCheck(VOID) {
  EFI_ACPI_ADDRESS_SPACE_DESCRIPTOR *r=NULL;
  EFI_STATUS status=Gu.pci->GetBarAttributes(Gu.pci,0,NULL,(VOID **)&r);
  GuLog("bar0 query: status=%#llx\n",(unsigned long long)status);
  if(!EFI_ERROR(status)) {
    if(r && r->Desc==ACPI_ADDRESS_SPACE_DESCRIPTOR && r->Len==sizeof(*r)-3)
      GuLog("bar0 descriptor: type=%u granularity=%llu min=%#llx max=%#llx length=%#llx translation=%#llx\n",
        (unsigned)r->ResType,(unsigned long long)r->AddrSpaceGranularity,(unsigned long long)r->AddrRangeMin,
        (unsigned long long)r->AddrRangeMax,(unsigned long long)r->AddrLen,(unsigned long long)r->AddrTranslationOffset);
    if(!r || r->Desc!=ACPI_ADDRESS_SPACE_DESCRIPTOR || r->Len!=sizeof(*r)-3 || r->ResType!=0 ||
      !r->AddrRangeMin || (r->AddrRangeMin & 0xffffffULL)!=0 ||
      r->AddrLen!=GU_PROFILE_BAR0_BYTES || r->AddrTranslationOffset ||
      (GuCfg.strict_bar0 && GuCfg.bar0_base && r->AddrRangeMin!=GuCfg.bar0_base) ||
      ((UINT8 *)(r+1))[0]!=ACPI_END_TAG_DESCRIPTOR)status=EFI_UNSUPPORTED;
    else {
      Gu.bar_base=r->AddrRangeMin;Gu.bar_size=r->AddrLen;
    }
  }
  if(r)GuFree(r);return status;
}

static EFI_STATUS ColdCheck(VOID) {
  UINT32 chip=GuRead32(0);
  BOOLEAN chip_ok = FALSE;
  if (Gu.target_chip_id != 0) {
    chip_ok = GuChipIdMatchesExpected(chip, Gu.target_chip_id);
  } else if (GuCfg.strict_chip && GuCfg.chip_id != 0) {
    chip_ok = GuChipIdMatchesExpected(chip, GuCfg.chip_id);
  } else {
    chip_ok = GuIsValidChipForArch(chip, Gu.target_arch);
  }
  GuLog("chip: actual=%#x configured=%#x strict_chip=%u arch=%s valid=%u\n",
    chip, GuCfg.chip_id, (unsigned)GuCfg.strict_chip,
    (Gu.target_arch == GU_ARCH_AMPERE) ? "GA10x" : "AD10x", (unsigned)chip_ok);
  if(!chip_ok)return EFI_UNSUPPORTED;
  Gu.target_chip_id = chip;
  Gu.target_arch = GuDetectArchFromChip(chip, Gu.target_arch);
  struct gpu_unlock_gfw_sample s={0};
  int gfw_ret=-EAGAIN;
  for(UINTN wait=0;wait<200;wait++) {
    s.config_ok=true;
    s.plm=GuRead32(GU_GFW_PLM_OFFSET);
    s.boot=GuRead32(GU_GFW_BOOT_OFFSET);
    s.cpuctl=GuRead32(GU_GFW_CPUCTL_OFFSET);
    gfw_ret=gpu_unlock_gfw_assess(&s);
    if(gfw_ret!=-EAGAIN)break;
    GuStall(10000);
  }
  UINT32 hi=GuRead32(0x1fa828),plm=GuRead32(GU_FEAT_PLM_OFFSET),ss0=GuRead32(GU_FEAT_SS0_OFFSET),ss1=GuRead32(GU_FEAT_SS1_OFFSET);
  UINT32 effective=GuRead32(0x823818);
  GuLog("cold state: chip=%#x plm=%#x gfw=%#x/%#x/%#x WPR2_HI=%#x SS0=%#x SS1=%#x effective=%#x\n",
    chip,plm,s.plm,s.boot,s.cpuctl,hi,ss0,ss1,effective);
  UINT32 wpr_cfg=GuRead32(0x1fa7cc),fbpa=GuRead32(0x9a0148),wpr=GuRead32(0x1fa7c4);
  GuLog("cold PLMs: WPR_CFG=%#x FBPA=%#x WPR=%#x FEAT=%#x\n",wpr_cfg,fbpa,wpr,plm);
  UINT32 vram=GuRead32(0x1183a4);
  GuLog("VRAM register=%#x (%u MiB)\n",vram,vram);
  BOOLEAN effective_ok = (Gu.target_arch == GU_ARCH_AMPERE) ||
    (effective!=0xffffffffU && (effective&0xffff0000U)!=0xbadf0000U);
  if(Gu.fault || gfw_ret || hi==0xffffffffU || (hi>>4)!=0 ||
     plm==0xffffffffU || (plm&0xffff0000U)==0xbadf0000U ||
     !effective_ok ||
     !Gu4090ColdSelectorsClosed(ss0,ss1) ||
     vram==0 || vram>65536U)return EFI_NOT_READY;
  if(InitialColdValid && (ss0!=InitialColdSs0 || ss1!=InitialColdSs1)) {
    GuLog("cold selectors changed within attempt: initial=%#x/%#x actual=%#x/%#x\n",
      InitialColdSs0,InitialColdSs1,ss0,ss1);
    return EFI_NOT_READY;
  }
  InitialColdSs0=ss0;InitialColdSs1=ss1;InitialColdValid=TRUE;
  return Gu.fault?EFI_DEVICE_ERROR:EFI_SUCCESS;
}

static VOID LogHash(const char *Name,const VOID *Data,UINTN Bytes) {
  static const char digits[]="0123456789abcdef";
  UINT8 digest[32];char hex[65];GuSha256(Data,Bytes,digest);
  for(UINTN i=0;i<32;i++){hex[2*i]=digits[digest[i]>>4];hex[2*i+1]=digits[digest[i]&15];}
  hex[64]=0;GuLog("%s bytes=%zu SHA256=%s\n",Name,(size_t)Bytes,hex);
}

static EFI_STATUS PromCheck(VOID) {
  VOID *prom=GuAlloc(GU_PROM_MAX_BYTES);if(!prom)return EFI_OUT_OF_RESOURCES;
  GuCopyFromIo(prom,(VOID *)(UINTN)(Gu.bar_base+GU_PROM_BAR_OFFSET),GU_PROM_MAX_BYTES);
  if(Gu.fault){GuFree(prom);return EFI_DEVICE_ERROR;}
  LogHash("live PROM (1 MiB)",prom,GU_PROM_MAX_BYTES);
  if(GuCfg.save_prom_dump) {
    EFI_STATUS saved=GuSavePromDump(prom,GU_PROM_MAX_BYTES);
    GuLog("PROM.BIN backup save status=%#llx\n",(unsigned long long)saved);
  }
  struct gpu_unlock_fwsec fw={0};
  u32 dmem_transfer=0;
  int fw_ret=gpu_unlock_vbios_fwsec(prom,GU_PROM_MAX_BYTES,&fw);
  int dm_ret=fw_ret?fw_ret:gpu_unlock_fwsec_dmem_transfer(&fw,&dmem_transfer);
  GuLog("PROM FWSEC parse: fw_ret=%d dm_ret=%d image_size=%#x imem=%#x dmem=%#x transfer=%#x ucode_id=%u sig_count=%u versions=%#x\n",
    fw_ret,dm_ret,fw.image_size,fw.imem_size,fw.dmem_size,dmem_transfer,fw.ucode_id,fw.sig_count,fw.sig_versions);
  GuFree(prom);
  if(fw_ret || dm_ret || fw.engine_mask!=0x400 || !fw.sig_count)return EFI_CRC_ERROR;
  return Gu.fault?EFI_DEVICE_ERROR:EFI_SUCCESS;
}

static EFI_STATUS Arm(VOID) {
  SkipToWindows=FALSE;
  if(!Table->ConIn || !Table->ConIn->Reset || !Table->ConIn->ReadKeyStroke)return EFI_UNSUPPORTED;
  EFI_STATUS status=Table->ConIn->Reset(Table->ConIn,FALSE);if(EFI_ERROR(status))return status;
  if(GuPortAutomaticBoot()) {
    GuLog("READY: %s (%s) preflight passed & Windows Boot Manager preloaded.\n",
      Gu.target_model_name, Gu.target_chip_family);
    GuLog("Automatic unlock in %u seconds. Press S to skip to Windows, or Esc to return to BIOS.\n",
      (unsigned)GuCfg.countdown_seconds);
  } else {
    GuLog("READY: %s (%s) preflight passed & Windows Boot Manager preloaded.\n",
      Gu.target_model_name, Gu.target_chip_family);
    GuLogText("  Press [U] to UNLOCK full-rate FP16/BF16 Tensor Cores and boot Windows 11.\n");
    GuLogText("  Press [S] to SKIP unlock and boot Windows 11 normally (locked).\n");
    GuLogText("  Press [Esc] (or wait 30s) to cancel and return to UEFI BIOS.\n");
  }
  if(!GuLogReady())return EFI_DEVICE_ERROR;
  UINTN ticks = GuPortAutomaticBoot() ? (GuCfg.countdown_seconds * 10U) : 300U;
  for(UINTN i=0;i<ticks;i++) {
    EFI_INPUT_KEY key;status=Table->ConIn->ReadKeyStroke(Table->ConIn,&key);
    if(!EFI_ERROR(status)) {
      if(key.ScanCode==0x17 || key.UnicodeChar==27)return EFI_ABORTED;
      if(key.UnicodeChar=='s' || key.UnicodeChar=='S' || key.UnicodeChar=='w' || key.UnicodeChar=='W') {
        SkipToWindows=TRUE;
        return EFI_ABORTED;
      }
      if(!GuPortAutomaticBoot() && (key.UnicodeChar=='u' || key.UnicodeChar=='U'))return EFI_SUCCESS;
    } else if(status!=EFI_NOT_READY)return status;
    GuStall(100000);
  }
  return GuPortAutomaticBoot()?EFI_SUCCESS:EFI_TIMEOUT;
}

static VOID PausePreflightFailure(VOID) {
  if(GuScreenDetached || Gu.started || !Table->ConIn || !Table->ConIn->ReadKeyStroke)return;
  if(Table->ConIn->Reset)Table->ConIn->Reset(Table->ConIn,FALSE);
  GuConsole("Preflight stopped before unlock. See the FINAL stage above and REPORT.TXT.\n");
  GuConsole("Press [S] to boot Windows normally, or [Enter]/[Esc] to return to firmware (60s timeout).\n");
  for(UINTN i=0;i<600;i++) {
    EFI_INPUT_KEY key;EFI_STATUS s=Table->ConIn->ReadKeyStroke(Table->ConIn,&key);
    if(!EFI_ERROR(s)) {
      if(key.UnicodeChar=='s' || key.UnicodeChar=='S' || key.UnicodeChar=='w' || key.UnicodeChar=='W') {
        if(WindowsImage){SkipToWindows=TRUE;break;}
      }
      if(key.ScanCode==0x17 || key.UnicodeChar==27 || key.UnicodeChar=='\r')break;
    }
    if(EFI_ERROR(s) && s!=EFI_NOT_READY)break;
    Gu.bs->Stall(100000);
  }
}

static VOID Halt(VOID) {
  Gu.retained=TRUE;
  GuLogText("STOP: cleanup cannot be proven. Resources remain reserved.\nPOWER OFF using the physical power button; do not continue to Windows.\n");
  for(;;)Gu.bs->Stall(1000000);
}

static VOID LogContainment(VOID) {
  GuLog("BME containment: attribute_status=%#llx hardware_status=%#llx command=%#x cached=%#llx pending=%u\n",
    (unsigned long long)Gu.master_attribute_status,(unsigned long long)Gu.master_hardware_status,
    Gu.master_last_command,(unsigned long long)Gu.master_last_attributes,Gu.master_attributes_pending);
}

static VOID ReleaseHalt(EFI_STATUS Status,BOOLEAN Attempted) {
  EFI_TPL old=Gu.bs->RaiseTPL(TPL_NOTIFY);
  EFI_STATUS refreshed=GuRefreshTargetPci();
  EFI_STATUS contained=EFI_ERROR(refreshed)?refreshed:GuClearMaster();
  Gu.bs->RestoreTPL(old);
  LogContainment();
  GuLog("FINAL status=%#llx stage=%s attempted=%u driver_release=1 clean=0 containment=%#llx pci_available=%u\n",
    (unsigned long long)Status,Stage,Attempted,(unsigned long long)contained,(unsigned)(Gu.pci!=NULL));
  Halt();
}

EFI_STATUS EFIAPI EfiMain(EFI_HANDLE Image,EFI_SYSTEM_TABLE *St) {
  if(!GuPortHardwareEnabled())return EFI_ACCESS_DENIED;
  if(!St || !St->BootServices || !St->RuntimeServices)return EFI_INVALID_PARAMETER;
  WindowsImage=NULL;WindowsVolume=NULL;WindowsDevicePath=NULL;GuScreenDetached=FALSE;ExpectDetached=FALSE;SkipToWindows=FALSE;
  Table=St;GuInit(St->BootServices,NULL);Gu.image=Image;Gu.display_check=DisplayCheck;
  InitialColdValid=FALSE;InitialColdSs0=InitialColdSs1=0;
  memset(&PendingOwner,0,sizeof(PendingOwner));
  memset(&SavedDisplay,0,sizeof(SavedDisplay));
  Stage="usb-log";EFI_STATUS status=GuIoOpen(Image,St);BOOLEAN attempted=FALSE,release_attempted=FALSE;
  if(EFI_ERROR(status))goto finish;
  UINT8 secure=0xff;UINTN bytes=1;
  Stage="secure-boot";
  status=St->RuntimeServices->GetVariable(L"SecureBoot",&GlobalGuid,NULL,&bytes,&secure);
  if(EFI_ERROR(status) || bytes!=1 || secure){status=EFI_SECURITY_VIOLATION;goto finish;}
  status=Step(status);if(EFI_ERROR(status))goto finish;
  Stage="watchdog";status=Step(Gu.bs->SetWatchdogTimer(0,0,0,NULL));if(EFI_ERROR(status))goto finish;
  Stage="target";status=Step(FindTarget());if(EFI_ERROR(status))goto finish;
  Stage="display";Gu.display_ok=DisplayCheck();status=Step(Gu.display_ok?EFI_SUCCESS:EFI_UNSUPPORTED);if(EFI_ERROR(status))goto finish;
  Stage="ownership";status=GuClaimController();
  if(status==EFI_ACCESS_DENIED) {
    status=GuFindReleaseOwner(St,&PendingOwner,TRUE);
    if(!EFI_ERROR(status))GuLogText(GuPortAutomaticBoot()?"Exclusive ownership deferred until countdown and explicit driver release.\n":
      "Exclusive ownership deferred until manual U and explicit driver release.\n");
  } else if(!EFI_ERROR(status)) {
    status=ClearFirmwareBmeIfSet();
  }
  status=Step(status);if(EFI_ERROR(status))goto finish;
  Stage="config-recheck";status=Step(ConfigCheck(FALSE));if(EFI_ERROR(status))goto finish;
  Stage="bar0";status=Step(BarCheck());if(EFI_ERROR(status))goto finish;
  Stage="cold-state";status=Step(ColdCheck());if(EFI_ERROR(status))goto finish;
  Stage="prom";status=Step(PromCheck());if(EFI_ERROR(status))goto finish;
  Stage="assets";status=Step(GuLoadAssets());if(EFI_ERROR(status))goto finish;
  Stage="windows-preload";status=Step(PreloadWindows());if(EFI_ERROR(status))goto finish;
  Stage="arming";status=Step(Arm());if(EFI_ERROR(status))goto finish;
  Stage="armed-config";status=Step(ConfigCheck(FALSE));if(EFI_ERROR(status))goto finish;
  Stage="armed-display";Gu.display_ok=DisplayCheck();status=Step(Gu.display_ok?EFI_SUCCESS:EFI_UNSUPPORTED);if(EFI_ERROR(status))goto finish;
  Stage="armed-cold-state";status=Step(ColdCheck());if(EFI_ERROR(status))goto finish;
  if(PendingOwner.agent) {
    GU_RELEASE_OWNER current;
    Stage="owner-recheck";
    GuLogText(GuPortAutomaticBoot()?"Automatic countdown completed: release RTX firmware driver once, then revalidate.\n":
      "Manual U confirmed: release RTX firmware driver once, then revalidate.\n");
    if(!GuLogReady()){status=EFI_DEVICE_ERROR;goto finish;}
    status=GuFindReleaseOwner(St,&current,FALSE);
    if(!EFI_ERROR(status) && !GuSameReleaseOwner(&PendingOwner,&current))status=EFI_ABORTED;
    if(EFI_ERROR(status)){status=Step(status);goto finish;}
    EFI_PCI_IO_PROTOCOL *prior=Gu.pci;
    Stage="driver-release";release_attempted=TRUE;Gu.armed=TRUE;Gu.pci=NULL;
    GuScreenDetached=TRUE;ExpectDetached=TRUE;
    EFI_STATUS released=Gu.bs->DisconnectController(Gu.handle,current.agent,NULL);
    EFI_TPL refresh_tpl=Gu.bs->RaiseTPL(TPL_NOTIFY);
    EFI_STATUS refreshed=GuRefreshTargetPci();
    Gu.bs->RestoreTPL(refresh_tpl);
    GuLog("driver release: status=%#llx refresh=%#llx same_pci=%u\n",
      (unsigned long long)released,(unsigned long long)refreshed,(unsigned)(Gu.pci==prior));
    status=Step(EFI_ERROR(released)?released:EFI_ERROR(refreshed)?refreshed:Gu.pci!=prior?EFI_COMPROMISED_DATA:EFI_SUCCESS);
    if(EFI_ERROR(status))goto finish;
    Stage="ownership-after-release";status=Step(GuClaimController());if(EFI_ERROR(status))goto finish;
    Stage="display-after-release";Gu.display_ok=DisplayCheck();status=Step(Gu.display_ok?EFI_SUCCESS:EFI_UNSUPPORTED);if(EFI_ERROR(status))goto finish;
    Stage="decode-after-release";status=Step(RestoreDecode());if(EFI_ERROR(status))goto finish;
    Stage="config-after-release";status=Step(ConfigCheck(FALSE));if(EFI_ERROR(status))goto finish;
    Stage="bar0-after-release";status=Step(BarCheck());if(EFI_ERROR(status))goto finish;
    Stage="cold-after-release";status=Step(ColdCheck());if(EFI_ERROR(status))goto finish;
  }
  GuLogText("ARMED: one transaction is starting. Do not reset or remove the USB.\n");
  if(!GuLogReady()){status=EFI_DEVICE_ERROR;goto finish;}
  Stage="transaction";Gu.armed=TRUE;attempted=TRUE;
  UINT64 mask=0xffffffffULL;
  struct pci_dev device={.dev={.dma_mask=&mask,.coherent_dma_mask=0xffffffffULL},.pm_cap=Gu.pm_cap,.refs=1};
  struct gpu_unlock_610_shared shared={0};
  int result=gpu_unlock_610_load_shared(&device,&shared);
  if(!result)result=gpu_unlock_610_unlock(&device,&shared);
  EFI_STATUS contained=GuClearMaster();
  LogContainment();
  GuLog("transaction result=%d containment=%#llx started=%u quiesced=%u fault=%u retained=%u maps=%u FLR=%u\n",
    result,(unsigned long long)contained,Gu.started,Gu.quiesced,Gu.fault,Gu.retained,Gu.dma_count,Gu.flrs);
  if(EFI_ERROR(contained) || !GuSafeToReturn() || Gu.allocations || (Gu.started && result))Halt();
  gpu_unlock_610_release_shared(&shared);Gu.armed=FALSE;
  status=result?EFI_DEVICE_ERROR:EFI_SUCCESS;
finish:
  if(!EFI_ERROR(status) && attempted) {
    Stage="post-unlock-handoff";status=RestoreDisplayForWindows(&PendingOwner);
  }
  if(release_attempted && (EFI_ERROR(status) || Gu.fault))ReleaseHalt(status,attempted);
  if(attempted && !GuSafeToReturn())Halt();
  if(GuLogReady())GuLog("FINAL status=%#llx stage=%s attempted=%u driver_release=%u clean=%u skip_to_windows=%u\n",
    (unsigned long long)status,Stage,attempted,release_attempted,GuSafeToReturn(),SkipToWindows);
  else GuConsole("Preflight or logging failed; no new attempt will start.\n");
  if(!GuLogReady()){status=EFI_DEVICE_ERROR;if(release_attempted)ReleaseHalt(status,attempted);if(Gu.started)Halt();}
  if(attempted && !GuSafeToReturn())Halt();
  EFI_STATUS closed=GuIoClose();
  if(EFI_ERROR(closed)){if(release_attempted)ReleaseHalt(closed,attempted);if(Gu.started)Halt();status=closed;}
  if(Gu.owned) {
    closed=Gu.bs->CloseProtocol(Gu.handle,&PciGuid,Image,NULL);
    if(EFI_ERROR(closed)){if(release_attempted)ReleaseHalt(closed,attempted);if(Gu.started)Halt();status=closed;}else Gu.owned=FALSE;
  }
  GuReleaseAssets();
  if(!EFI_ERROR(status) && attempted) {
    GuLog("%s (%s) unlocked & verified after FLR. Starting Windows 11...\n",
      Gu.target_model_name, Gu.target_chip_family);
    UINTN exit_bytes=0;CHAR16 *data=NULL;
    status=Gu.bs->StartImage(WindowsImage,&exit_bytes,&data);
    if(data)GuFree(data);
    GuScreenDetached=TRUE;Halt();
  }
  if(EFI_ERROR(status) && status!=EFI_ABORTED && status!=EFI_TIMEOUT && !release_attempted)PausePreflightFailure();
  if(SkipToWindows && WindowsImage && !release_attempted && !attempted) {
    GuConsole("Skipping unlock and booting Windows 11 normally...\n");
    UINTN exit_bytes=0;CHAR16 *data=NULL;
    status=Gu.bs->StartImage(WindowsImage,&exit_bytes,&data);
    if(data)GuFree(data);
  }
  GuConsole("Attempt cancelled or rejected. Returning without another attempt.\n");
  if(WindowsImage)Gu.bs->UnloadImage(WindowsImage);
  GuFree(WindowsDevicePath);WindowsDevicePath=NULL;
  return status;
}
