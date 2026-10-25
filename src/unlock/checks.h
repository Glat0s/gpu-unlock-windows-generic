/* SPDX-License-Identifier: GPL-2.0-only */
#pragma once

#include "port.h"

typedef struct {
  UINT16 pm, pcie, msi, msix;
  UINT8 pcie_version;
} GU_CAPS;

/* Config is a complete, CPU-owned 256-byte snapshot. Out is cleared on failure. */
BOOLEAN GuCheckConfig(const UINT32 Config[64], UINTN Segment, UINTN Bus,
                      UINTN Device, UINTN Function, GU_CAPS *Out);

int GuDisplayPath(const EFI_DEVICE_PATH_PROTOCOL *Path, UINTN MaxBytes);
/* Exact configured GPT ESP match (or any GPT partition if MatchAnyGpt is TRUE). */
BOOLEAN GuWindowsEspPathEx(const EFI_DEVICE_PATH_PROTOCOL *Path, UINTN MaxBytes, BOOLEAN MatchAnyGpt);
BOOLEAN GuWindowsEspPath(const EFI_DEVICE_PATH_PROTOCOL *Path, UINTN MaxBytes);
