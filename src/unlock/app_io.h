/* SPDX-License-Identifier: GPL-2.0-only */
#pragma once
#include "port.h"
extern BOOLEAN GuScreenDetached;
EFI_STATUS GuIoOpen(EFI_HANDLE Image, EFI_SYSTEM_TABLE *St);
EFI_STATUS GuLoadAssets(VOID);
EFI_STATUS GuSavePromDump(const VOID *Data, UINTN Size);
VOID GuReleaseAssets(VOID);
EFI_STATUS GuIoClose(VOID);
BOOLEAN GuLogReady(VOID);
VOID GuConsole(const char *Text);
EFI_HANDLE GuBootVolumeHandle(VOID);
