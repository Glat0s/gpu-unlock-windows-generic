/* SPDX-License-Identifier: GPL-2.0-only
 * UEFI PCI/MMIO/DMA platform abstraction for RTX 3000 (GA10x) & RTX 4000 (AD10x)
 */
#pragma once
#include <Uefi.h>
#include <Protocol/PciIo.h>
#include <Protocol/DevicePath.h>
#include <stddef.h>

#include "board_profile.h"
#include "config.h"

#define GU_BOARD_ID (Gu.target_board_id ? Gu.target_board_id : GuCfg.board_id)
#define GU_BOARD_SUBSYSTEM (Gu.target_subsystem ? Gu.target_subsystem : GuCfg.subsystem_id)
#define GU_BOARD_CHIP (Gu.target_chip_id ? Gu.target_chip_id : GuCfg.chip_id)
#define GU_BOARD_ARCH (Gu.target_board_id ? Gu.target_arch : GuCfg.arch)

typedef struct GU_DMA GU_DMA;
struct GU_DMA {
  GU_DMA *next;
  VOID *cpu, *mapping;
  UINT64 dma;
  UINTN bytes, pages;
  BOOLEAN mapped;
};
typedef struct {
  EFI_BOOT_SERVICES *bs;
  EFI_PCI_IO_PROTOCOL *pci;
  EFI_HANDLE image, handle;
  UINTN target_segment, target_bus, target_device, target_function;
  UINT32 target_board_id, target_subsystem, target_chip_id;
  UINT8 target_arch;
  const char *target_model_name;
  const char *target_chip_family;
  UINT64 bar_base, bar_size, ticks;
  UINT16 pm_cap, pcie_cap, msi_cap, msix_cap;
  UINT32 saved_config[64];
  UINT16 saved_devctl, saved_devctl2;
  UINT8 pcie_version;
  BOOLEAN fault, retained, started, quiesced, armed, owned, display_ok, saved;
  BOOLEAN master_attributes_pending;
  UINT64 master_original_attributes;
  UINT16 master_original_command;
  EFI_PCI_IO_PROTOCOL *master_pci;
  EFI_STATUS master_attribute_status, master_hardware_status;
  UINT64 master_last_attributes;
  UINT16 master_last_command;
  UINT32 flrs, mmio_writes, dma_count;
  GU_DMA *allocations;
  BOOLEAN (*display_check)(VOID);
} GU_PLATFORM;
extern GU_PLATFORM Gu;

VOID GuInit(EFI_BOOT_SERVICES *Bs, EFI_PCI_IO_PROTOCOL *Pci);
BOOLEAN GuTargetConfig(const UINT32 *Config, UINTN Segment, UINTN Bus, UINTN Device, UINTN Function);
BOOLEAN GuSafeToReturn(VOID);
EFI_STATUS GuDmaAllocate(UINTN Bytes, VOID **Cpu, UINT64 *Dma);
EFI_STATUS GuDmaFree(VOID *Cpu, UINT64 Dma);
UINT32 GuRead32(UINT32 Offset);
VOID GuWrite32(UINT32 Offset, UINT32 Value);
EFI_STATUS GuSavePci(VOID);
EFI_STATUS GuRestorePci(VOID);
EFI_STATUS GuFlr(VOID);
EFI_STATUS GuClearMaster(VOID);
EFI_STATUS GuEnableMaster(VOID);
EFI_STATUS GuConfigRead(EFI_PCI_IO_PROTOCOL_WIDTH Width, UINT32 Offset, VOID *Value);
EFI_STATUS GuConfigWrite(EFI_PCI_IO_PROTOCOL_WIDTH Width, UINT32 Offset, VOID *Value);
VOID GuStarted(VOID);
VOID GuQuiesced(VOID);
VOID GuLog(const char *Format, ...);
VOID GuLogText(const char *Text);
VOID GuCopyFromIo(VOID *Destination, const VOID *Source, size_t Bytes);
VOID *GuAlloc(size_t Bytes);
VOID GuFree(VOID *Memory);
VOID GuStall(UINTN Microseconds);
