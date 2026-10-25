/* SPDX-License-Identifier: GPL-2.0-only */
#include "ownership.h"
#include "app_io.h"
#include "runtime.h"
#include <Protocol/LoadedImage.h>
#include <Protocol/GraphicsOutput.h>
#include "sha256.h"
static EFI_GUID PciGuid=EFI_PCI_IO_PROTOCOL_GUID,
  PathGuid=EFI_DEVICE_PATH_PROTOCOL_GUID,GopGuid=EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID,
  BindingGuid=EFI_DRIVER_BINDING_PROTOCOL_GUID,LoadedGuid=EFI_LOADED_IMAGE_PROTOCOL_GUID;
typedef struct {EFI_GUID protocol;EFI_OPEN_PROTOCOL_INFORMATION_ENTRY entry;} OWNER_RECORD;
#define MAX_RECORDS 64
static BOOLEAN Passive(UINT32 A) {
  return A==EFI_OPEN_PROTOCOL_BY_HANDLE_PROTOCOL || A==EFI_OPEN_PROTOCOL_GET_PROTOCOL || A==EFI_OPEN_PROTOCOL_TEST_PROTOCOL;
}
/* Caller holds TPL_NOTIFY through the snapshot and, for Claim, acquisition. */
static EFI_STATUS Snapshot(OWNER_RECORD *Records,UINTN *Count) {
  EFI_GUID **protocols=NULL;UINTN protocol_count=0;BOOLEAN pci=FALSE;*Count=0;
  if(!Gu.bs->ProtocolsPerHandle)return EFI_UNSUPPORTED;
  EFI_STATUS status=Gu.bs->ProtocolsPerHandle(Gu.handle,&protocols,&protocol_count);
  if(!EFI_ERROR(status) && (!protocols || !protocol_count || protocol_count>64))status=EFI_COMPROMISED_DATA;
  for(UINTN i=0;!EFI_ERROR(status) && i<protocol_count;i++) {
    EFI_OPEN_PROTOCOL_INFORMATION_ENTRY *entries=NULL;UINTN count=0;
    if(!protocols[i]){status=EFI_COMPROMISED_DATA;break;}
    if(!memcmp(protocols[i],&PciGuid,sizeof(PciGuid)))pci=TRUE;
    status=Gu.bs->OpenProtocolInformation(Gu.handle,protocols[i],&entries,&count);
    if(!EFI_ERROR(status) && (count>MAX_RECORDS-*Count || (count && !entries)))status=EFI_COMPROMISED_DATA;
    if(!EFI_ERROR(status))for(UINTN j=0;j<count;j++) {
      Records[*Count].protocol=*protocols[i];Records[*Count].entry=entries[j];(*Count)++;
    }
    if(entries && EFI_ERROR(Gu.bs->FreePool(entries)))status=EFI_DEVICE_ERROR;
  }
  if(protocols && EFI_ERROR(Gu.bs->FreePool(protocols)))status=EFI_DEVICE_ERROR;
  return !EFI_ERROR(status) && !pci?EFI_NOT_FOUND:status;
}
static VOID LogRecords(const OWNER_RECORD *Records,UINTN Count,EFI_STATUS Status) {
  GuLog("ownership: records=%zu exclusive=%u status=%#llx\n",(size_t)Count,Gu.owned,(unsigned long long)Status);
  for(UINTN i=0;i<Count;i++) {
    const EFI_OPEN_PROTOCOL_INFORMATION_ENTRY *e=&Records[i].entry;
    GuLog("owner[%u] protocol=%08x attributes=%#x count=%u agent=%#llx controller=%#llx\n",
      (unsigned)i,Records[i].protocol.Data1,e->Attributes,e->OpenCount,
      (unsigned long long)(UINTN)e->AgentHandle,(unsigned long long)(UINTN)e->ControllerHandle);
  }
}
EFI_STATUS GuClaimController(VOID) {
  OWNER_RECORD records[MAX_RECORDS];UINTN count=0;
  EFI_TPL old=Gu.bs->RaiseTPL(TPL_NOTIFY);
  EFI_STATUS status=Snapshot(records,&count);
  if(!EFI_ERROR(status))for(UINTN i=0;i<count;i++)if(!Passive(records[i].entry.Attributes))status=EFI_ACCESS_DENIED;
  if(!EFI_ERROR(status)) {
    EFI_PCI_IO_PROTOCOL *pci=NULL;
    status=Gu.bs->OpenProtocol(Gu.handle,&PciGuid,(VOID **)&pci,Gu.image,NULL,EFI_OPEN_PROTOCOL_EXCLUSIVE);
    if(!EFI_ERROR(status)){Gu.owned=TRUE;if(pci!=Gu.pci)status=EFI_COMPROMISED_DATA;}
  }
  Gu.bs->RestoreTPL(old);LogRecords(records,count,status);return status;
}
static BOOLEAN ConsoleHandle(EFI_SYSTEM_TABLE *Table,EFI_HANDLE Handle) {
  return Handle && (Handle==Table->ConsoleOutHandle || Handle==Table->ConsoleInHandle || Handle==Table->StandardErrorHandle);
}
static EFI_STATUS DisplayChild(const OWNER_RECORD *Record,GU_RELEASE_OWNER *Owner) {
  const EFI_OPEN_PROTOCOL_INFORMATION_ENTRY *e=&Record->entry;
  if(e->Attributes!=EFI_OPEN_PROTOCOL_BY_CHILD_CONTROLLER || e->AgentHandle!=Owner->agent ||
     e->OpenCount<1 || !e->ControllerHandle || e->ControllerHandle==Gu.handle ||
     e->ControllerHandle==Gu.image || Owner->child_count>=GU_MAX_DISPLAY_CHILDREN)
    return EFI_ACCESS_DENIED;
  EFI_GRAPHICS_OUTPUT_PROTOCOL *gop=NULL;EFI_DEVICE_PATH_PROTOCOL *path=NULL;
  EFI_STATUS gop_status=Gu.bs->HandleProtocol(e->ControllerHandle,&GopGuid,(VOID **)&gop);
  UINT64 fb_base=0;UINTN fb_size=0;
  if(!EFI_ERROR(gop_status) && gop && gop->Mode) {
    EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE *m=gop->Mode;
    fb_base=m->FrameBufferBase;
    fb_size=m->FrameBufferSize;
  }
  EFI_STATUS status=Gu.bs->HandleProtocol(e->ControllerHandle,&PathGuid,(VOID **)&path);
  UINT8 path_hash[32]={0};
  if(!EFI_ERROR(status) && path && Gu.bs->LocateDevicePath) {
    UINTN bytes=0;BOOLEAN end=FALSE;
    for(UINTN i=0;i<128 && bytes<=4092;i++) {
      EFI_DEVICE_PATH_PROTOCOL *node=(VOID *)((UINT8 *)path+bytes);
      UINTN length=node->Length[0]+((UINTN)node->Length[1]<<8);
      if(length<4 || length>4096-bytes)return EFI_COMPROMISED_DATA;
      bytes+=length;
      if(node->Type==END_DEVICE_PATH_TYPE) {
        if(node->SubType!=END_ENTIRE_DEVICE_PATH_SUBTYPE || length!=4)return EFI_UNSUPPORTED;
        end=TRUE;break;
      }
    }
    if(!end)return EFI_COMPROMISED_DATA;
    EFI_DEVICE_PATH_PROTOCOL *remaining=path;EFI_HANDLE parent=NULL;
    status=Gu.bs->LocateDevicePath(&PciGuid,&remaining,&parent);
    if(EFI_ERROR(status) || parent!=Gu.handle)return EFI_ACCESS_DENIED;
    GuSha256(path,bytes,path_hash);
  }
  for(UINTN i=0;i<Owner->child_count;i++)
    if(Owner->children[i].handle==e->ControllerHandle &&
       !memcmp(&Owner->children[i].protocol,&Record->protocol,sizeof(EFI_GUID)))return EFI_COMPROMISED_DATA;
  GU_DISPLAY_CHILD *child=&Owner->children[Owner->child_count++];
  child->handle=e->ControllerHandle;child->protocol=Record->protocol;child->gop=gop;
  child->framebuffer=fb_base;child->framebuffer_size=fb_size;
  memcpy(child->path_sha256,path_hash,32);
  return EFI_SUCCESS;
}
EFI_STATUS GuFindReleaseOwner(EFI_SYSTEM_TABLE *Table,GU_RELEASE_OWNER *Owner,BOOLEAN Log) {
  OWNER_RECORD records[MAX_RECORDS];UINTN count=0,drivers=0;memset(Owner,0,sizeof(*Owner));
  if(!Gu.bs->DisconnectController || Gu.owned)return EFI_UNSUPPORTED;
  EFI_TPL old=Gu.bs->RaiseTPL(TPL_NOTIFY);
  EFI_STATUS status=Snapshot(records,&count);
  Gu.bs->RestoreTPL(old);if(Log)LogRecords(records,count,status);
  if(EFI_ERROR(status))return status;
  for(UINTN i=0;i<count;i++) {
    const EFI_OPEN_PROTOCOL_INFORMATION_ENTRY *e=&records[i].entry;
    if(!memcmp(&records[i].protocol,&PciGuid,sizeof(PciGuid)) && e->Attributes==EFI_OPEN_PROTOCOL_BY_DRIVER) {
      if(!e->AgentHandle || e->ControllerHandle!=Gu.handle || e->OpenCount<1)return EFI_ACCESS_DENIED;
      Owner->agent=e->AgentHandle;drivers++;
    }
  }
  if(drivers!=1 || Owner->agent==Gu.image || Owner->agent==Gu.handle || ConsoleHandle(Table,Owner->agent))return EFI_ACCESS_DENIED;
  for(UINTN i=0;i<count;i++) {
    const EFI_OPEN_PROTOCOL_INFORMATION_ENTRY *e=&records[i].entry;
    if(Passive(e->Attributes))continue;
    if(e->Attributes==EFI_OPEN_PROTOCOL_BY_CHILD_CONTROLLER) {
      status=DisplayChild(&records[i],Owner);
      if(Log)GuLog("display child: record=%u handle=%#llx agent=%#llx status=%#llx\n",
        (unsigned)i,(unsigned long long)(UINTN)e->ControllerHandle,
        (unsigned long long)(UINTN)e->AgentHandle,(unsigned long long)status);
      if(EFI_ERROR(status))return status;
      continue;
    }
    if(e->Attributes!=EFI_OPEN_PROTOCOL_BY_DRIVER || e->AgentHandle!=Owner->agent ||
       e->ControllerHandle!=Gu.handle || e->OpenCount<1) {
      if(Log)GuLog("release refused: different owner or unsupported open at record %u\n",(unsigned)i);
      return EFI_ACCESS_DENIED;
    }
  }
  EFI_DRIVER_BINDING_PROTOCOL *binding=NULL;EFI_LOADED_IMAGE_PROTOCOL *image=NULL;
  status=Gu.bs->HandleProtocol(Owner->agent,&BindingGuid,(VOID **)&binding);
  if(EFI_ERROR(status) || !binding || binding->DriverBindingHandle!=Owner->agent || !binding->Stop ||
    !binding->ImageHandle || binding->ImageHandle==Gu.image)return EFI_UNSUPPORTED;
  status=Gu.bs->HandleProtocol(binding->ImageHandle,&LoadedGuid,(VOID **)&image);
  if(EFI_ERROR(status) || !image)return EFI_UNSUPPORTED;
  if(Log)GuLog("release candidate: agent=%#llx image=%#llx source=%#llx base=%#llx bytes=%llu version=%#x code_type=%u children=%zu\n",
    (unsigned long long)(UINTN)Owner->agent,(unsigned long long)(UINTN)binding->ImageHandle,
    (unsigned long long)(UINTN)image->DeviceHandle,(unsigned long long)(UINTN)image->ImageBase,
    (unsigned long long)image->ImageSize,binding->Version,(unsigned)image->ImageCodeType,(size_t)Owner->child_count);
  if(!image->ImageBase || !image->ImageSize || image->ImageSize>64U*1024U*1024U || image->ImageCodeType!=EfiBootServicesCode)return EFI_UNSUPPORTED;
  Owner->image=binding->ImageHandle;Owner->base=image->ImageBase;Owner->size=image->ImageSize;
  Owner->version=binding->Version;Owner->stop=binding->Stop;return EFI_SUCCESS;
}
BOOLEAN GuSameReleaseOwner(const GU_RELEASE_OWNER *A,const GU_RELEASE_OWNER *B) {
  if(A->agent!=B->agent || A->image!=B->image || A->base!=B->base || A->size!=B->size ||
    A->version!=B->version || A->stop!=B->stop || A->child_count!=B->child_count)return FALSE;
  for(UINTN i=0;i<A->child_count;i++) {
    BOOLEAN match=FALSE;
    for(UINTN j=0;j<B->child_count;j++)
      if(!memcmp(&A->children[i],&B->children[j],sizeof(GU_DISPLAY_CHILD)))match=TRUE;
    if(!match)return FALSE;
  }
  return TRUE;
}
EFI_STATUS GuVerifyRecoveryOwner(const GU_RELEASE_OWNER *Expected) {
  OWNER_RECORD records[MAX_RECORDS];UINTN count=0,drivers=0;
  EFI_TPL old=Gu.bs->RaiseTPL(TPL_NOTIFY);
  EFI_STATUS status=Snapshot(records,&count);Gu.bs->RestoreTPL(old);
  LogRecords(records,count,status);
  if(EFI_ERROR(status) || !Expected || !Expected->agent)return EFI_ACCESS_DENIED;
  for(UINTN i=0;i<count;i++) {
    const EFI_OPEN_PROTOCOL_INFORMATION_ENTRY *e=&records[i].entry;
    if(Passive(e->Attributes))continue;
    if(e->AgentHandle!=Expected->agent || e->OpenCount<1)return EFI_ACCESS_DENIED;
    if(e->Attributes==EFI_OPEN_PROTOCOL_BY_DRIVER) {
      if(e->ControllerHandle!=Gu.handle)return EFI_ACCESS_DENIED;
      if(!memcmp(&records[i].protocol,&PciGuid,sizeof(PciGuid)))drivers++;
    } else if(e->Attributes!=EFI_OPEN_PROTOCOL_BY_CHILD_CONTROLLER ||
      !e->ControllerHandle || e->ControllerHandle==Gu.handle || e->ControllerHandle==Gu.image)
      return EFI_ACCESS_DENIED;
  }
  EFI_DRIVER_BINDING_PROTOCOL *binding=NULL;EFI_LOADED_IMAGE_PROTOCOL *image=NULL;
  if(drivers!=1)return EFI_ACCESS_DENIED;
  status=Gu.bs->HandleProtocol(Expected->agent,&BindingGuid,(VOID**)&binding);
  if(EFI_ERROR(status) || !binding || binding->DriverBindingHandle!=Expected->agent ||
    binding->ImageHandle!=Expected->image || binding->Version!=Expected->version || binding->Stop!=Expected->stop)
    return EFI_COMPROMISED_DATA;
  status=Gu.bs->HandleProtocol(Expected->image,&LoadedGuid,(VOID**)&image);
  if(EFI_ERROR(status) || !image || image->ImageBase!=Expected->base || image->ImageSize!=Expected->size ||
    image->ImageCodeType!=EfiBootServicesCode)return EFI_COMPROMISED_DATA;
  GuLogText("GOP recovery: original driver binding verified\n");
  return GuLogReady()?EFI_SUCCESS:EFI_DEVICE_ERROR;
}
EFI_STATUS GuRefreshTargetPci(VOID) {
  EFI_PCI_IO_PROTOCOL *fresh=NULL;UINTN segment,bus,device,function;UINT32 config[64]={0};
  Gu.pci=NULL;
  EFI_STATUS status=Gu.bs->HandleProtocol(Gu.handle,&PciGuid,(VOID **)&fresh);
  if(EFI_ERROR(status) || !fresh || !fresh->GetLocation || !fresh->Pci.Read || !fresh->Pci.Write)return EFI_NOT_FOUND;
  status=fresh->GetLocation(fresh,&segment,&bus,&device,&function);if(EFI_ERROR(status))return status;
  const UINT32 offsets[]={0,8,12,44};
  for(UINTN i=0;i<4;i++) {
    status=fresh->Pci.Read(fresh,EfiPciIoWidthUint32,offsets[i],1,&config[offsets[i]/4]);if(EFI_ERROR(status))return status;
  }
  if(!GuTargetConfig(config,segment,bus,device,function))return EFI_UNSUPPORTED;
  Gu.pci=fresh;return EFI_SUCCESS;
}
