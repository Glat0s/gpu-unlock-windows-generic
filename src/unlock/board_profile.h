/* SPDX-License-Identifier: MIT
 * NVIDIA GeForce RTX 3000 (GA10x) & RTX 4000 (AD10x) Windows UEFI Unlocker
 * Generic Compile-Time Board Profile (Runtime overrides via \RTX4090-PREP\CONFIG.INI)
 */
#pragma once

#if defined(GU_USE_LOCAL_BOARD) && __has_include("local_board.h")
#include "local_board.h"
#endif

#ifndef GU_LOCAL_BOARD_CONFIGURED
#define GU_LOCAL_BOARD_CONFIGURED 0
#define GU_LOCAL_BOARD_ID 0U
#define GU_LOCAL_SUBSYSTEM_ID 0U
#define GU_LOCAL_CHIP_ID 0U
#define GU_LOCAL_PCI_SEGMENT 0U
#define GU_LOCAL_PCI_BUS 1U
#define GU_LOCAL_PCI_DEVICE 0U
#define GU_LOCAL_PCI_FUNCTION 0U
#define GU_LOCAL_BAR0_BASE 0ULL
#define GU_LOCAL_BAR0_BYTES 0x1000000ULL
#define GU_LOCAL_STRICT_SUBSYSTEM 0
#define GU_LOCAL_STRICT_BDF 0
#define GU_LOCAL_STRICT_BAR0 0
#define GU_LOCAL_STRICT_ESP 0
#define GU_LOCAL_ALLOW_HEADLESS_HANDOFF 1
#define GU_LOCAL_SAVE_PROM_DUMP 1
#define GU_PROFILE_WINDOWS_ESP_GUID {0,0,0,{0,0,0,0,0,0,0,0}}
#define GU_PROFILE_WINDOWS_ESP_GUID_STR "auto"
#define GU_PROFILE_WINDOWS_ESP_PARTITION 0U
#define GU_PROFILE_WINDOWS_ESP_START_LBA 0ULL
#define GU_PROFILE_WINDOWS_ESP_SIZE_LBA 0ULL
#endif

#define GU_PROFILE_READY 1
#define GU_PROFILE_BOARD_ID GU_LOCAL_BOARD_ID
#define GU_PROFILE_SUBSYSTEM GU_LOCAL_SUBSYSTEM_ID
#define GU_PROFILE_CHIP GU_LOCAL_CHIP_ID
#define GU_PROFILE_BAR0_BASE GU_LOCAL_BAR0_BASE
#define GU_PROFILE_BAR0_BYTES GU_LOCAL_BAR0_BYTES

#if defined(GU_SOFT_UNLOCK_BUILD) && GU_SOFT_UNLOCK_BUILD == 1
static inline int GuPortHardwareEnabled(void) { return 1; }
#else
static inline int GuPortHardwareEnabled(void) { return 0; }
#endif

static inline int GuPortCompileTimeAutoBoot(void) {
#if defined(GU_AUTO_BOOT_BUILD) && GU_AUTO_BOOT_BUILD == 1
  return GuPortHardwareEnabled();
#else
  return 0;
#endif
}
