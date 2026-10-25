/* SPDX-License-Identifier: GPL-2.0-only */
#include "app_io.h"
#include "compat/compat.h"
#include "config.h"
#include "format.h"
#include "sha256.h"
#include <Protocol/LoadedImage.h>
#include <Protocol/SimpleFileSystem.h>
#include <Guid/FileInfo.h>
static EFI_GUID LoadedGuid=EFI_LOADED_IMAGE_PROTOCOL_GUID,PathGuid=EFI_DEVICE_PATH_PROTOCOL_GUID,
  FsGuid=EFI_SIMPLE_FILE_SYSTEM_PROTOCOL_GUID,InfoGuid=EFI_FILE_INFO_ID;
static EFI_SYSTEM_TABLE *Table;
static EFI_HANDLE BootDeviceHandle;
static EFI_FILE_PROTOCOL *Root,*Parent,*Run,*Report;
static BOOLEAN LogFault;
BOOLEAN GuScreenDetached;
typedef struct {const char *name;CHAR16 *file;UINTN size;const char *hash;} ASSET_SPEC;
static const ASSET_SPEC SpecsAda[]={
 {"gpu-unlock/610.43.03/booter_load_ad102.bin",L"ASSETS\\booter_load_ad102.bin",57672,"6ee05b20e1dc244c08c052f36ef28469b8d09f4955d1fe33e48a179e11a7fd49"},
 {"gpu-unlock/610.43.03/v67-ad102-610.43.03-four-plm.bin",L"ASSETS\\v67-ad102-610.43.03-four-plm.bin",64000,"44c36b2d6b3424e53e18f3e55db85c833655de071ce66ce42749588a4a7dc8cb"},
 {"gpu-unlock/610.43.03/gsp_ga10x.bin",L"ASSETS\\gsp_ga10x.bin",84277400,"572373620a37418f24dc16b5031c39338778c3257e48e8408de9a57291b24f3a"},
 {"gpu-unlock/610.43.03/gsp_boot_ad102.bin",L"ASSETS\\gsp_boot_ad102.bin",36864,"45d6335a8185d6ff13e8d1484cea73f68d3d13aa1c19dc080ed1c3482dd5bac0"},
 {"gpu-unlock/610.43.03/gsp_boot_desc_ad102.bin",L"ASSETS\\gsp_boot_desc_ad102.bin",84,"83f8f3f1f5f9496e0ea8fc7103c2beb64d0b6de2f5ffe725f13514de5a95fa42"}
};
static const ASSET_SPEC SpecsAmpere[]={
 {"gpu-unlock/610.43.03/booter_load_ga102.bin",L"ASSETS\\booter_load_ga102.bin",61256,"056cbc064a888f80717726c54d7f64fcd68044d123870c95a74f37f4975dcaa4"},
 {"gpu-unlock/610.43.03/v67-ga102-610.43.03.bin",L"ASSETS\\v67-ga102-610.43.03.bin",64000,"2a0aa1f86d0b6afff5214d641d87d46dc98ef06ed908ff05d0ddbad5ffb7e197"},
 {"gpu-unlock/610.43.03/gsp_ga10x.bin",L"ASSETS\\gsp_ga10x.bin",84277400,"572373620a37418f24dc16b5031c39338778c3257e48e8408de9a57291b24f3a"},
 {"gpu-unlock/610.43.03/gsp_boot_ga102.bin",L"ASSETS\\gsp_boot_ga102.bin",24576,"3df651acb174fd5f5561a1996965b192f50c5d763168446ed0d4ead19d895768"},
 {"gpu-unlock/610.43.03/gsp_boot_desc_ga102.bin",L"ASSETS\\gsp_boot_desc_ga102.bin",84,"cc5a3fc1f4c47f2fe107b1b68f0176d8a448e6dec84b575e5560ccef5262bf15"}
};

EFI_HANDLE GuBootVolumeHandle(VOID) { return BootDeviceHandle; }

static VOID LogError(VOID){LogFault=TRUE;if(Gu.armed)Gu.fault=TRUE;}
VOID GuConsole(const char *Text) {
  if(GuScreenDetached)return;
  if(!Table || !Table->ConOut || !Table->ConOut->OutputString){LogError();return;}
  while(*Text) {
    CHAR16 line[128];UINTN n=0;
    while(*Text && n<126){if(*Text=='\n')line[n++]='\r';line[n++]=(UINT8)*Text++;}
    line[n]=0;if(EFI_ERROR(Table->ConOut->OutputString(Table->ConOut,line))){LogError();return;}
  }
}
VOID GuLogText(const char *Text) {
  GuConsole(Text);
  if(!Report || LogFault){LogError();return;}
  UINTN expected=strlen(Text),written=expected;
  EFI_STATUS status=Report->Write(Report,&written,(VOID *)Text);
  if(EFI_ERROR(status) || written!=expected || EFI_ERROR(Report->Flush(Report)))LogError();
}
VOID GuLog(const char *Format,...) {
  char text[1024];va_list args;va_start(args,Format);
  size_t n=GuFormatV(text,sizeof(text),Format,args);va_end(args);
  if(n>=sizeof(text)){LogError();GuConsole("Log format or length error.\n");return;}
  GuLogText(text);
}
BOOLEAN GuLogReady(VOID){return Report && !LogFault;}

static BOOLEAN ValidBootPath(EFI_HANDLE Handle, BOOLEAN *IsUsbOut) {
  EFI_DEVICE_PATH_PROTOCOL *path=NULL;
  if (IsUsbOut) *IsUsbOut = FALSE;
  if(EFI_ERROR(Table->BootServices->HandleProtocol(Handle,&PathGuid,(VOID **)&path)) || !path)return FALSE;
  UINTN total=0;BOOLEAN usb=FALSE;
  for(UINTN nodes=0;nodes<64 && total+4<=4096;nodes++) {
    UINTN n=path->Length[0]+((UINTN)path->Length[1]<<8);
    if(n<4 || n>4096-total)return FALSE;
    if(path->Type==MESSAGING_DEVICE_PATH &&
      ((path->SubType==MSG_USB_DP && n==sizeof(USB_DEVICE_PATH)) ||
       (path->SubType==MSG_SD_DP && n==sizeof(SD_DEVICE_PATH))))usb=TRUE;
    if(path->Type==END_DEVICE_PATH_TYPE) {
      if (IsUsbOut) *IsUsbOut = usb;
      return n==4 && path->SubType==END_ENTIRE_DEVICE_PATH_SUBTYPE;
    }
    total+=n;path=(VOID *)((UINT8 *)path+n);
  }
  return FALSE;
}

static EFI_STATUS Metadata(EFI_FILE_PROTOCOL *File,BOOLEAN Directory,UINTN Expected) {
  union {EFI_FILE_INFO info;UINT8 bytes[512];} data;UINTN n=sizeof(data);
  EFI_STATUS status=File->GetInfo(File,&InfoGuid,&n,&data);
  if(EFI_ERROR(status))return status;
  if(n<SIZE_OF_EFI_FILE_INFO || n>sizeof(data) || data.info.Size>n || data.info.Size<SIZE_OF_EFI_FILE_INFO ||
    !!(data.info.Attribute&EFI_FILE_DIRECTORY)!=!!Directory ||
    (!Directory && Expected && data.info.FileSize!=Expected))return EFI_COMPROMISED_DATA;
  return EFI_SUCCESS;
}

static VOID TryLoadConfigIni(VOID) {
  EFI_FILE_PROTOCOL *cfg=NULL;
  if (!Parent) return;
  EFI_STATUS s = Parent->Open(Parent, &cfg, L"CONFIG.INI", EFI_FILE_MODE_READ, 0);
  if (EFI_ERROR(s) || !cfg) return;
  union {EFI_FILE_INFO info;UINT8 bytes[512];} data;UINTN n=sizeof(data);
  s = cfg->GetInfo(cfg, &InfoGuid, &n, &data);
  if (!EFI_ERROR(s) && n >= SIZE_OF_EFI_FILE_INFO &&
      !(data.info.Attribute & EFI_FILE_DIRECTORY) &&
      data.info.FileSize > 0 && data.info.FileSize <= 32768) {
    UINTN size = (UINTN)data.info.FileSize;
    char *buf = GuAlloc(size + 1);
    if (buf) {
      UINTN read_bytes = size;
      if (!EFI_ERROR(cfg->Read(cfg, &read_bytes, buf)) && read_bytes == size) {
        buf[size] = 0;
        GuConfigParseIni(buf, size);
      }
      GuFree(buf);
    }
  }
  cfg->Close(cfg);
}

EFI_STATUS GuIoOpen(EFI_HANDLE Image,EFI_SYSTEM_TABLE *St) {
  Table=St;Root=Parent=Run=Report=NULL;BootDeviceHandle=NULL;LogFault=FALSE;memset(GuAssets,0,sizeof(GuAssets));
  EFI_LOADED_IMAGE_PROTOCOL *loaded=NULL;EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *fs=NULL;
  BOOLEAN is_usb=FALSE;
  EFI_STATUS status=Table->BootServices->HandleProtocol(Image,&LoadedGuid,(VOID **)&loaded);
  if(EFI_ERROR(status) || !loaded || !ValidBootPath(loaded->DeviceHandle, &is_usb))return EFI_UNSUPPORTED;
  BootDeviceHandle=loaded->DeviceHandle;
  status=Table->BootServices->HandleProtocol(loaded->DeviceHandle,&FsGuid,(VOID **)&fs);
  if(EFI_ERROR(status) || !fs)return EFI_UNSUPPORTED;
  status=fs->OpenVolume(fs,&Root);if(EFI_ERROR(status) || !Root)return EFI_DEVICE_ERROR;
  status=Root->Open(Root,&Parent,L"\\RTX4090-PREP",EFI_FILE_MODE_READ|EFI_FILE_MODE_WRITE,0);
  if(EFI_ERROR(status) || !Parent)return EFI_NOT_FOUND;
  status=Metadata(Parent,TRUE,0);if(EFI_ERROR(status))return status;
  TryLoadConfigIni();
  for(UINTN slot=0;slot<(GuPortAutomaticBoot()?10000U:100U);slot++) {
    CHAR16 name[]=L"AUTO0000";
    if(GuPortAutomaticBoot()) {
      UINTN digits=slot;
      for(UINTN p=8;p>4;){name[--p]=(CHAR16)('0'+digits%10);digits/=10;}
    } else {name[0]='R';name[1]='U';name[2]='N';name[3]=(CHAR16)('0'+slot/10);name[4]=(CHAR16)('0'+slot%10);name[5]=0;}
    EFI_FILE_PROTOCOL *existing=NULL;
    status=Parent->Open(Parent,&existing,name,EFI_FILE_MODE_READ,0);
    if(!EFI_ERROR(status)) {
      if(!existing || EFI_ERROR(existing->Close(existing)))return EFI_DEVICE_ERROR;continue;
    }
    if(status!=EFI_NOT_FOUND)return status;
    status=Parent->Open(Parent,&Run,name,EFI_FILE_MODE_READ|EFI_FILE_MODE_WRITE|EFI_FILE_MODE_CREATE,EFI_FILE_DIRECTORY);
    if(EFI_ERROR(status) || !Run)return EFI_DEVICE_ERROR;
    status=Metadata(Run,TRUE,0);if(EFI_ERROR(status))return status;
    status=Run->Open(Run,&existing,L"REPORT.TXT",EFI_FILE_MODE_READ,0);
    if(!EFI_ERROR(status)){if(existing)existing->Close(existing);return EFI_ALREADY_STARTED;}
    if(status!=EFI_NOT_FOUND)return status;
    status=Run->Open(Run,&Report,L"REPORT.TXT",EFI_FILE_MODE_READ|EFI_FILE_MODE_WRITE|EFI_FILE_MODE_CREATE,0);
    if(EFI_ERROR(status) || !Report)return EFI_DEVICE_ERROR;
    GuLog("RTX 3000/4000 (GA10x/AD10x) UEFI Unlocker: enabled=%u automatic=%u countdown=%us usb_path=%u config_ini=%u\n",
      GuPortHardwareEnabled(),GuPortAutomaticBoot(),(unsigned)GuCfg.countdown_seconds,(unsigned)is_usb,(unsigned)GuCfg.config_file_loaded);
    GuLog("Profile: board=%#x(strict=%u) subsys=%#x(strict=%u) chip=%#x(strict=%u) arch=%u bar0=%#llx(strict=%u) strict_bdf=%u strict_esp=%u headless_ok=%u\n",
      GuCfg.board_id,(unsigned)GuCfg.strict_board,GuCfg.subsystem_id,(unsigned)GuCfg.strict_subsystem,
      GuCfg.chip_id,(unsigned)GuCfg.strict_chip,(unsigned)GuCfg.arch,
      (unsigned long long)GuCfg.bar0_base,(unsigned)GuCfg.strict_bar0,
      (unsigned)GuCfg.strict_bdf,(unsigned)GuCfg.strict_esp,(unsigned)GuCfg.allow_headless_handoff);
    return GuLogReady()?EFI_SUCCESS:EFI_DEVICE_ERROR;
  }
  return EFI_VOLUME_FULL;
}
EFI_STATUS GuSavePromDump(const VOID *Data,UINTN Size) {
  if(!Run || !Data || Size!=1048576)return EFI_INVALID_PARAMETER;
  EFI_FILE_PROTOCOL *file=NULL;
  EFI_STATUS status=Run->Open(Run,&file,L"PROM.BIN",EFI_FILE_MODE_READ,0);
  if(!EFI_ERROR(status)) {
    if(file)file->Close(file);
    return EFI_ALREADY_STARTED;
  }
  if(status!=EFI_NOT_FOUND)return status;
  status=Run->Open(Run,&file,L"PROM.BIN",EFI_FILE_MODE_READ|EFI_FILE_MODE_WRITE|EFI_FILE_MODE_CREATE,0);
  if(EFI_ERROR(status) || !file)return EFI_ERROR(status)?status:EFI_DEVICE_ERROR;
  UINTN written=Size;
  status=file->Write(file,&written,(VOID *)Data);
  if(!EFI_ERROR(status) && written!=Size)status=EFI_BAD_BUFFER_SIZE;
  if(!EFI_ERROR(status))status=file->Flush(file);
  EFI_STATUS closed=file->Close(file);
  return EFI_ERROR(status)?status:closed;
}
EFI_STATUS GuLoadAssets(VOID) {
  const ASSET_SPEC *active_specs = (GU_BOARD_ARCH == GU_ARCH_AMPERE) ? SpecsAmpere : SpecsAda;
  GuLog("Loading firmware asset profile: %s\n", (GU_BOARD_ARCH == GU_ARCH_AMPERE) ? "Ampere GA10x (RTX 3000 Series)" : "Ada AD10x (RTX 4000 Series)");
  for(UINTN i=0;i<5;i++) {
    EFI_FILE_PROTOCOL *file=NULL;const ASSET_SPEC *spec=&active_specs[i];
    EFI_STATUS status=Parent->Open(Parent,&file,spec->file,EFI_FILE_MODE_READ,0);
    if(EFI_ERROR(status) || !file)return EFI_NOT_FOUND;
    status=Metadata(file,FALSE,spec->size);
    UINT8 *data=NULL;
    if(!EFI_ERROR(status)) {
      data=GuAlloc(spec->size);if(!data)status=EFI_OUT_OF_RESOURCES;
    }
    for(UINTN done=0;!EFI_ERROR(status) && done<spec->size;) {
      UINTN n=spec->size-done;if(n>1048576)n=1048576;UINTN want=n;
      status=file->Read(file,&n,data+done);
      if(!EFI_ERROR(status) && n!=want)status=EFI_END_OF_FILE;done+=n;
    }
    EFI_STATUS closed=file->Close(file);if(!EFI_ERROR(status))status=closed;
    if(!EFI_ERROR(status) && !GuHashMatches(data,spec->size,spec->hash))status=EFI_CRC_ERROR;
    if(EFI_ERROR(status)){GuFree(data);return status;}
    GuAssets[i].name=spec->name;GuAssets[i].firmware.data=data;GuAssets[i].firmware.size=spec->size;
    GuLog("asset verified: %s bytes=%zu sha256=%s\n",spec->name,(size_t)spec->size,spec->hash);
    if(!GuLogReady())return EFI_DEVICE_ERROR;
  }
  return EFI_SUCCESS;
}
VOID GuReleaseAssets(VOID) {
  if(!GuSafeToReturn())return;
  for(UINTN i=0;i<5;i++){GuFree((VOID *)GuAssets[i].firmware.data);memset(&GuAssets[i],0,sizeof(GuAssets[i]));}
}
EFI_STATUS GuIoClose(VOID) {
  EFI_FILE_PROTOCOL **files[]={&Report,&Run,&Parent,&Root};EFI_STATUS result=EFI_SUCCESS;
  if(!GuSafeToReturn())return EFI_ACCESS_DENIED;
  for(UINTN i=0;i<4;i++)if(*files[i]) {
    EFI_FILE_PROTOCOL *file=*files[i];*files[i]=NULL;
    EFI_STATUS status=file->Close(file);
    if(EFI_ERROR(status))return status;
  }
  return result;
}
