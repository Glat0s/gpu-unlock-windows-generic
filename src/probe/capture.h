/* SPDX-License-Identifier: GPL-2.0-only */
#pragma once
#include <Uefi.h>
#include <Protocol/PciIo.h>

typedef EFI_STATUS (*GU_CAPTURE_SAVE)(const CHAR16 *Name,const VOID *Data,UINTN Bytes,VOID *Context);
EFI_STATUS GuReadOnlyCapture(EFI_BOOT_SERVICES *Bs,EFI_PCI_IO_PROTOCOL *Pci,
                            GU_CAPTURE_SAVE Save,VOID *Context);
