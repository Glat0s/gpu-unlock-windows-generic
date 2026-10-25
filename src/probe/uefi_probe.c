/* SPDX-License-Identifier: GPL-2.0-only
 * Standalone removable-media diagnostic. Does not link the unlocker.
 */
#include "capture.h"
#include "runtime.h"
#include "../unlock/gpu_catalog.h"
#include <Protocol/LoadedImage.h>
#include <Protocol/SimpleFileSystem.h>
#include <Protocol/DevicePath.h>
#include <Guid/FileInfo.h>

static EFI_GUID LoadedGuid=EFI_LOADED_IMAGE_PROTOCOL_GUID,FsGuid=EFI_SIMPLE_FILE_SYSTEM_PROTOCOL_GUID,
  PathGuid=EFI_DEVICE_PATH_PROTOCOL_GUID,PciGuid=EFI_PCI_IO_PROTOCOL_GUID,InfoGuid=EFI_FILE_INFO_ID;
static const char Marker[]="RTX4090-READONLY-CAPTURE-V1\n";
static VOID Screen(EFI_SYSTEM_TABLE *St,CHAR16 *Text) {
  if(St && St->ConOut && St->ConOut->OutputString)St->ConOut->OutputString(St->ConOut,Text);
}
static BOOLEAN UsbDevice(EFI_BOOT_SERVICES *Bs,EFI_HANDLE Handle) {
  EFI_DEVICE_PATH_PROTOCOL *path=NULL;
  if(EFI_ERROR(Bs->HandleProtocol(Handle,&PathGuid,(VOID **)&path)) || !path)return FALSE;
  UINTN total=0;BOOLEAN usb=FALSE;
  for(UINTN node=0;node<64 && total+4<=4096;node++) {
    UINTN size=path->Length[0]+((UINTN)path->Length[1]<<8);
    if(size<4 || size>4096-total)return FALSE;
    if(path->Type==MESSAGING_DEVICE_PATH && path->SubType==MSG_USB_DP && size==sizeof(USB_DEVICE_PATH))usb=TRUE;
    if(path->Type==END_DEVICE_PATH_TYPE)return usb && size==4 && path->SubType==END_ENTIRE_DEVICE_PATH_SUBTYPE;
    total+=size;path=(VOID *)((UINT8 *)path+size);
  }
  return FALSE;
}
static EFI_STATUS Metadata(EFI_FILE_PROTOCOL *File,BOOLEAN Directory,UINTN Expected) {
  union {EFI_FILE_INFO Info;UINT8 Bytes[512];} data;
  UINTN bytes=sizeof(data);
  EFI_STATUS status=File->GetInfo(File,&InfoGuid,&bytes,&data);
  if(EFI_ERROR(status))return status;
  if(bytes<SIZE_OF_EFI_FILE_INFO || bytes>sizeof(data) || data.Info.Size>bytes ||
     data.Info.Size<SIZE_OF_EFI_FILE_INFO ||
     !!(data.Info.Attribute&EFI_FILE_DIRECTORY)!=!!Directory ||
     (!Directory && data.Info.FileSize!=Expected))return EFI_COMPROMISED_DATA;
  return EFI_SUCCESS;
}
static EFI_STATUS NewFile(const CHAR16 *Name,const VOID *Data,UINTN Bytes,VOID *Context) {
  EFI_FILE_PROTOCOL *folder=Context,*file=NULL;
  EFI_STATUS status=folder->Open(folder,&file,(CHAR16 *)Name,EFI_FILE_MODE_READ,0);
  if(!EFI_ERROR(status)){if(file)file->Close(file);return EFI_ALREADY_STARTED;}
  if(status!=EFI_NOT_FOUND)return status;
  status=folder->Open(folder,&file,(CHAR16 *)Name,EFI_FILE_MODE_CREATE|EFI_FILE_MODE_READ|EFI_FILE_MODE_WRITE,0);
  if(EFI_ERROR(status) || !file)return EFI_ERROR(status)?status:EFI_DEVICE_ERROR;
  UINTN written=Bytes;
  status=file->Write(file,&written,(VOID *)Data);
  if(!EFI_ERROR(status) && written!=Bytes)status=EFI_BAD_BUFFER_SIZE;
  if(!EFI_ERROR(status))status=file->Flush(file);
  EFI_STATUS closed=file->Close(file);
  return EFI_ERROR(status)?status:closed;
}
EFI_STATUS EFIAPI EfiMain(EFI_HANDLE Image,EFI_SYSTEM_TABLE *St) {
  if(!St || !St->BootServices)return EFI_INVALID_PARAMETER;
  EFI_BOOT_SERVICES *bs=St->BootServices;
  EFI_LOADED_IMAGE_PROTOCOL *loaded=NULL;EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *fs=NULL;
  EFI_FILE_PROTOCOL *root=NULL,*parent=NULL,*marker=NULL,*run=NULL;
  EFI_HANDLE *handles=NULL;EFI_PCI_IO_PROTOCOL *target=NULL;UINTN count=0,matches=0;
  Screen(St,L"RTX 3000/4000 (GA10x/AD10x) read-only diagnostic. NO UNLOCK.\r\nUSB files only; no GPU writes, DMA, reset or firmware payload.\r\n");
  EFI_STATUS status=bs->HandleProtocol(Image,&LoadedGuid,(VOID **)&loaded);
  if(EFI_ERROR(status) || !loaded || !UsbDevice(bs,loaded->DeviceHandle)){status=EFI_UNSUPPORTED;goto done;}
  status=bs->HandleProtocol(loaded->DeviceHandle,&FsGuid,(VOID **)&fs);
  if(EFI_ERROR(status) || !fs){status=EFI_UNSUPPORTED;goto done;}
  status=fs->OpenVolume(fs,&root);if(EFI_ERROR(status) || !root){status=EFI_DEVICE_ERROR;goto done;}
  status=root->Open(root,&parent,L"\\GPU-PROBE",EFI_FILE_MODE_READ|EFI_FILE_MODE_WRITE,0);
  if(EFI_ERROR(status) || !parent){status=EFI_NOT_FOUND;goto done;}
  status=Metadata(parent,TRUE,0);if(EFI_ERROR(status))goto done;
  status=parent->Open(parent,&marker,L"ALLOW-READONLY.TAG",EFI_FILE_MODE_READ,0);
  if(EFI_ERROR(status) || !marker){status=EFI_ACCESS_DENIED;goto done;}
  status=Metadata(marker,FALSE,sizeof(Marker)-1);if(EFI_ERROR(status))goto done;
  char bytes[sizeof(Marker)]={0};UINTN wanted=sizeof(Marker)-1;
  status=marker->Read(marker,&wanted,bytes);
  if(EFI_ERROR(status) || wanted!=sizeof(Marker)-1 || memcmp(bytes,Marker,wanted)) {status=EFI_ACCESS_DENIED;goto done;}
  status=marker->Close(marker);marker=NULL;if(EFI_ERROR(status))goto done;
  for(UINTN slot=0;slot<100;slot++) {
    CHAR16 name[]=L"CAP00";name[3]=(CHAR16)('0'+slot/10);name[4]=(CHAR16)('0'+slot%10);
    EFI_FILE_PROTOCOL *existing=NULL;
    status=parent->Open(parent,&existing,name,EFI_FILE_MODE_READ,0);
    if(!EFI_ERROR(status)) {
      if(!existing){status=EFI_DEVICE_ERROR;goto done;}
      status=existing->Close(existing);if(EFI_ERROR(status))goto done;
      continue;
    }
    if(status!=EFI_NOT_FOUND)goto done;
    status=parent->Open(parent,&run,name,EFI_FILE_MODE_READ|EFI_FILE_MODE_WRITE|EFI_FILE_MODE_CREATE,EFI_FILE_DIRECTORY);
    if(EFI_ERROR(status) || !run){status=EFI_DEVICE_ERROR;goto done;}
    status=Metadata(run,TRUE,0);if(EFI_ERROR(status))goto done;
    Screen(St,L"Saving to \\GPU-PROBE\\");Screen(St,name);Screen(St,L"\\\r\n");
    break;
  }
  if(!run){status=EFI_VOLUME_FULL;goto done;}
  status=bs->LocateHandleBuffer(ByProtocol,&PciGuid,NULL,&count,&handles);
  if(EFI_ERROR(status) || count>512 || (count && !handles)){status=EFI_DEVICE_ERROR;goto done;}
  for(UINTN index=0;index<count;index++) {
    EFI_PCI_IO_PROTOCOL *pci=NULL;UINT32 config[64];
    status=bs->HandleProtocol(handles[index],&PciGuid,(VOID **)&pci);
    if(EFI_ERROR(status) || !pci){status=EFI_DEVICE_ERROR;goto done;}
    status=pci->Pci.Read(pci,EfiPciIoWidthUint32,0,64,config);
    if(EFI_ERROR(status))goto done;
    if(GuIsSupportedBoardId(config[0]) && (config[2]>>24)==0x03){matches++;target=pci;}
  }
  if(matches!=1 || !target){status=EFI_UNSUPPORTED;goto done;}
  status=GuReadOnlyCapture(bs,target,NewFile,run);
done:
  if(handles)bs->FreePool(handles);
  EFI_FILE_PROTOCOL **files[]={&marker,&run,&parent,&root};
  for(UINTN index=0;index<sizeof(files)/sizeof(files[0]);index++)if(*files[index]) {
    EFI_FILE_PROTOCOL *file=*files[index];*files[index]=NULL;
    EFI_STATUS closed=file->Close(file);if(!EFI_ERROR(status))status=closed;
  }
  if(EFI_ERROR(status))Screen(St,L"Diagnostic incomplete or rejected. Preserve any CAPxx files. No unlock ran.\r\n");
  else Screen(St,L"Capture saved and files closed. No unlock ran.\r\nRemove USB, then boot Windows normally.\r\n");
  Screen(St,L"Returning to firmware in 15 seconds.\r\n");
  bs->Stall(15000000);
  return status;
}
