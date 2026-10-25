/* SPDX-License-Identifier: MIT
 * Runtime hardware & boot profile (compiled defaults + \RTX4090-PREP\CONFIG.INI override)
 * Supports all NVIDIA GeForce RTX 3000 (Ampere GA10x) and RTX 4000 (Ada AD10x) GPUs.
 */
#pragma once
#include <Uefi.h>
#include "board_profile.h"
#include "gpu_catalog.h"

typedef struct {
  UINT32 board_id;
  UINT32 subsystem_id;
  UINT32 chip_id;
  UINT8  arch; /* GU_ARCH_ADA, GU_ARCH_AMPERE, or GU_ARCH_AUTO */
  INT32 pci_segment;
  INT32 pci_bus;
  INT32 pci_device;
  INT32 pci_function;
  UINT64 bar0_base;
  UINT64 bar0_bytes;
  BOOLEAN strict_board;
  BOOLEAN strict_subsystem;
  BOOLEAN strict_chip;
  BOOLEAN strict_bdf;
  BOOLEAN strict_bar0;
  BOOLEAN strict_esp;
  BOOLEAN allow_headless_handoff;
  BOOLEAN save_prom_dump;
  BOOLEAN auto_boot;
  UINT32 countdown_seconds;
  BOOLEAN esp_guid_valid;
  EFI_GUID esp_guid;
  UINT32 esp_partition;
  UINT64 esp_start_lba;
  UINT64 esp_size_lba;
  BOOLEAN config_file_loaded;
} GU_RUNTIME_CONFIG;

extern GU_RUNTIME_CONFIG GuCfg;

VOID GuConfigInitDefaults(VOID);
BOOLEAN GuConfigParseIni(const char *Text, UINTN Length);
int GuPortAutomaticBoot(void);
