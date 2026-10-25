/* SPDX-License-Identifier: GPL-2.0-only -- fake EFI services, no hardware. */
#define main CaptureFixtureMain
#include "test_capture.c"
#undef main
#include "uefi_probe.c"

static int Fault,Writes,Closes,Waits;
static EFI_FILE_PROTOCOL RootFile,ParentFile,MarkerFile,RunFile,DataFile;
static EFI_LOADED_IMAGE_PROTOCOL Loaded;
static EFI_SIMPLE_FILE_SYSTEM_PROTOCOL Fs;
static UINT8 DevicePath[sizeof(USB_DEVICE_PATH)+4];
static EFI_HANDLE DiskHandle=(EFI_HANDLE)(UINTN)0x20,PciHandle=(EFI_HANDLE)(UINTN)0x30;

static EFI_STATUS EFIAPI CloseFile(EFI_FILE_PROTOCOL *Self) {(void)Self;Closes++;return Fault==9?EFI_DEVICE_ERROR:EFI_SUCCESS;}
static EFI_STATUS EFIAPI FlushFile(EFI_FILE_PROTOCOL *Self) {(void)Self;return EFI_SUCCESS;}
static EFI_STATUS EFIAPI ReadFile(EFI_FILE_PROTOCOL *Self,UINTN *Size,VOID *Buffer) {
  assert(Self==&MarkerFile && *Size==sizeof(Marker)-1);
  memcpy(Buffer,Marker,*Size);
  if(Fault==3)((char *)Buffer)[0]='X';
  if(Fault==8)(*Size)--;
  return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI WriteFile(EFI_FILE_PROTOCOL *Self,UINTN *Size,VOID *Buffer) {
  assert(Self==&DataFile && *Size && Buffer);Writes++;
  if(Fault==4)return EFI_DEVICE_ERROR;
  if(Fault==10)(*Size)--;
  return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI GetInfo(EFI_FILE_PROTOCOL *Self,EFI_GUID *Guid,UINTN *Size,VOID *Buffer) {
  assert(!memcmp(Guid,&InfoGuid,sizeof(*Guid)) && *Size>=sizeof(EFI_FILE_INFO));
  EFI_FILE_INFO *info=Buffer;memset(info,0,sizeof(*info));info->Size=sizeof(*info);
  info->Attribute=Self==&MarkerFile?0:EFI_FILE_DIRECTORY;
  info->FileSize=Self==&MarkerFile?sizeof(Marker)-1:0;*Size=sizeof(*info);return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI OpenFile(EFI_FILE_PROTOCOL *Self,EFI_FILE_PROTOCOL **New,CHAR16 *Name,UINT64 ModeBits,UINT64 Attributes) {
  (void)Attributes;*New=NULL;
  if(Self==&RootFile){if(Fault==5)return EFI_NOT_FOUND;assert(Name[0]=='\\');*New=&ParentFile;return EFI_SUCCESS;}
  if(Self==&ParentFile && Name[0]=='A'){if(Fault==2)return EFI_NOT_FOUND;*New=&MarkerFile;return EFI_SUCCESS;}
  if(Self==&ParentFile && Name[0]=='C') {
    if(ModeBits&EFI_FILE_MODE_CREATE){*New=&RunFile;return EFI_SUCCESS;}
    if(Fault==11){*New=&RunFile;return EFI_SUCCESS;}
    return EFI_NOT_FOUND;
  }
  assert(Self==&RunFile);
  if(ModeBits&EFI_FILE_MODE_CREATE){*New=&DataFile;return EFI_SUCCESS;}
  return EFI_NOT_FOUND;
}
static EFI_STATUS EFIAPI OpenVolume(EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *Self,EFI_FILE_PROTOCOL **RootOut) {
  assert(Self==&Fs);*RootOut=&RootFile;return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI Handle(EFI_HANDLE Value,EFI_GUID *Guid,VOID **Out) {
  if(!memcmp(Guid,&LoadedGuid,sizeof(*Guid))){Loaded.DeviceHandle=DiskHandle;*Out=&Loaded;return EFI_SUCCESS;}
  if(!memcmp(Guid,&PathGuid,sizeof(*Guid))){assert(Value==DiskHandle);*Out=DevicePath;return EFI_SUCCESS;}
  if(!memcmp(Guid,&FsGuid,sizeof(*Guid))){assert(Value==DiskHandle);*Out=&Fs;return EFI_SUCCESS;}
  assert(!memcmp(Guid,&PciGuid,sizeof(*Guid)) && Value==PciHandle);*Out=&Pci;return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI Handles(EFI_LOCATE_SEARCH_TYPE Type,EFI_GUID *Guid,VOID *Key,UINTN *Count,EFI_HANDLE **Out) {
  (void)Type;(void)Guid;(void)Key;*Count=Fault==6?2:1;
  EFI_STATUS status=Alloc(EfiBootServicesData,*Count*sizeof(**Out),(VOID **)Out);
  if(EFI_ERROR(status))return status;
  for(UINTN i=0;i<*Count;i++)(*Out)[i]=PciHandle;
  return EFI_SUCCESS;
}
static EFI_STATUS EFIAPI Wait(UINTN Microseconds) {assert(Microseconds==15000000);Waits++;return EFI_SUCCESS;}
int main(void) {
  for(Fault=0;Fault<=11;Fault++) {
    Mode=Fault==7?1:0;Allocations=MemReads=PromReads=Writes=Closes=Waits=0;
    memset(&Pci,0,sizeof(Pci));Pci.Pci.Read=Config;Pci.Mem.Read=Memory;
    Pci.GetLocation=Location;Pci.GetBarAttributes=Bar;Pci.RomImage=Rom;Pci.RomSize=sizeof(Rom);
    EFI_FILE_PROTOCOL *files[]={&RootFile,&ParentFile,&MarkerFile,&RunFile,&DataFile};
    for(UINTN i=0;i<5;i++) {
      memset(files[i],0,sizeof(*files[i]));files[i]->Open=OpenFile;files[i]->Close=CloseFile;
      files[i]->Read=ReadFile;files[i]->Write=WriteFile;files[i]->Flush=FlushFile;files[i]->GetInfo=GetInfo;
    }
    memset(DevicePath,0,sizeof(DevicePath));
    DevicePath[0]=MESSAGING_DEVICE_PATH;DevicePath[1]=Fault==1?MSG_SATA_DP:MSG_USB_DP;DevicePath[2]=sizeof(USB_DEVICE_PATH);
    DevicePath[sizeof(USB_DEVICE_PATH)]=END_DEVICE_PATH_TYPE;
    DevicePath[sizeof(USB_DEVICE_PATH)+1]=END_ENTIRE_DEVICE_PATH_SUBTYPE;DevicePath[sizeof(USB_DEVICE_PATH)+2]=4;
    Fs.OpenVolume=OpenVolume;
    EFI_BOOT_SERVICES bs={.HandleProtocol=Handle,.LocateHandleBuffer=Handles,.AllocatePool=Alloc,.FreePool=Free,.Stall=Wait};
    EFI_SYSTEM_TABLE st={.BootServices=&bs};
    EFI_STATUS status=EfiMain((EFI_HANDLE)(UINTN)0x10,&st);
    if(!Fault)assert(status==EFI_SUCCESS && Writes==5 && PromReads==256);
    else assert(EFI_ERROR(status));
    if(Fault==1 || Fault==2 || Fault==3 || Fault==5 || Fault==6 || Fault==7 || Fault==8 || Fault==9 || Fault==11)
      assert(!Writes && !MemReads);
    assert(Allocations==0 && Waits==1);
    printf("USB-only EFI wrapper synthetic fault=%d result=%llx PASS\n",Fault,(unsigned long long)status);
  }
  return 0;
}
