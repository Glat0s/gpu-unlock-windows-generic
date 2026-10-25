/* SPDX-License-Identifier: MIT
 * Host unit & integration test suite for the Universal RTX 3000 (GA10x) & RTX 4000 (AD10x) UEFI Unlocker
 */
#include "../config.h"
#include "../checks.h"
#include "../port.h"
#include "../sha256.h"
#include "../selector_check.h"
#include "../vendor/gfw_eval.h"
#include "../vendor/layout_610.h"
#include "../vendor/prep_610.h"
#include "../vendor/vbios_610.h"
#include <IndustryStandard/Pci.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>

/* Stubs for host test linking */
VOID GuLog(const char *Format, ...) { (void)Format; }
VOID GuLogText(const char *Text) { (void)Text; }
VOID GuCopyFromIo(VOID *Destination, const VOID *Source, size_t Bytes) {
  memcpy(Destination, Source, Bytes);
}

static void test_defaults_and_ini_parser(void) {
  GuInit(NULL, NULL);
  /* Generic compile-time defaults (no hardware-specific IDs baked in) */
  assert(GuCfg.board_id == 0U);
  assert(GuCfg.subsystem_id == 0U);
  assert(GuCfg.chip_id == 0U);
  assert(GuCfg.arch == GU_ARCH_AUTO);
  assert(GuCfg.strict_board == FALSE);
  assert(GuCfg.strict_subsystem == FALSE);
  assert(GuCfg.strict_chip == FALSE);
  assert(GuCfg.bar0_base == 0ULL);
  assert(GuCfg.bar0_bytes == 0x1000000ULL);
  assert(GuCfg.esp_guid_valid == FALSE);

  /* Test tailored INI parsing */
  const char *tailored_ini =
    "mode = manual\n"
    "arch = ada\n"
    "board_id = 0x268410de\n"
    "subsystem_id = 0x100010de\n"
    "chip_id = 0x192000a1\n"
    "strict_board = 1\n"
    "strict_subsystem = 1\n"
    "bar0_base = 0x40000000\n"
    "windows_esp_guid = 11111111-2222-3333-4444-555555555555\n"
    "windows_esp_partition = 1\n"
    "windows_esp_start_lba = 2048\n"
    "windows_esp_size_lba = 204800\n";
  assert(GuConfigParseIni(tailored_ini, strlen(tailored_ini)) == TRUE);
  assert(GuCfg.board_id == 0x268410deU);
  assert(GuCfg.subsystem_id == 0x100010deU);
  assert(GuCfg.chip_id == 0x192000a1U);
  assert(GuCfg.strict_board == TRUE);
  assert(GuCfg.strict_subsystem == TRUE);
  assert(GuCfg.bar0_base == 0x40000000ULL);
  assert(GuCfg.esp_guid_valid == TRUE);
  assert(GuCfg.esp_partition == 1U);
  assert(GuCfg.esp_start_lba == 2048ULL);
  assert(GuCfg.esp_size_lba == 204800ULL);

  /* Test runtime INI override back to universal RTX 3000/4000 discovery */
  const char *ini =
    "# Test INI override\n"
    "mode = auto\n"
    "countdown = 7\n"
    "arch = auto\n"
    "board_id = any\n"
    "chip_id = any\n"
    "subsystem_id = any\n"
    "bar0_base = any\n"
    "windows_esp_guid = auto\n";
  assert(GuConfigParseIni(ini, strlen(ini)) == TRUE);
  assert(GuCfg.config_file_loaded == TRUE);
  assert(GuCfg.auto_boot == TRUE);
  assert(GuCfg.countdown_seconds == 7U);
  assert(GuCfg.arch == GU_ARCH_AUTO);
  assert(GuCfg.board_id == 0U);
  assert(GuCfg.strict_board == FALSE);
  assert(GuCfg.chip_id == 0U);
  assert(GuCfg.strict_chip == FALSE);
  assert(GuCfg.subsystem_id == 0U);
  assert(GuCfg.strict_subsystem == FALSE);
  assert(GuCfg.bar0_base == 0ULL);
  assert(GuCfg.strict_bar0 == FALSE);
  assert(GuCfg.esp_guid_valid == FALSE);
  assert(GuCfg.strict_esp == FALSE);

  /* Verify GPU catalog covers RTX 3000 (GA102..GA107) and RTX 4000 (AD102..AD107) */
  assert(GuIsSupportedBoardId(0x268410deU) == TRUE); /* RTX 4090 AD102 */
  assert(GuIsSupportedBoardId(0x270410deU) == TRUE); /* RTX 4080 AD103 */
  assert(GuIsSupportedBoardId(0x278210deU) == TRUE); /* RTX 4070 Ti AD104 */
  assert(GuIsSupportedBoardId(0x280510deU) == TRUE); /* RTX 4060 Ti 16GB AD106 */
  assert(GuIsSupportedBoardId(0x288210deU) == TRUE); /* RTX 4060 AD107 */
  assert(GuIsSupportedBoardId(0x220410deU) == TRUE); /* RTX 3090 GA102 */
  assert(GuIsSupportedBoardId(0x220610deU) == TRUE); /* RTX 3080 GA102 */
  assert(GuIsSupportedBoardId(0x241410deU) == TRUE); /* RTX 3060 Ti GA103 */
  assert(GuIsSupportedBoardId(0x248410deU) == TRUE); /* RTX 3070 GA104 */
  assert(GuIsSupportedBoardId(0x250410deU) == TRUE); /* RTX 3060 12GB GA106 */
  assert(GuIsSupportedBoardId(0x258210deU) == TRUE); /* RTX 3050 8GB GA107 */
  assert(GuIsValidChipForArch(0x192000a1U, GU_ARCH_ADA) == TRUE);
  assert(GuIsValidChipForArch(0x194000a1U, GU_ARCH_ADA) == TRUE);
  assert(GuIsValidChipForArch(0x172000a1U, GU_ARCH_AMPERE) == TRUE);
  assert(GuIsValidChipForArch(0x176000a1U, GU_ARCH_AMPERE) == TRUE);
  assert(GuSelectorsValidForArch(0, 0x00000001U, 0x88888888U, 8U, 0xffffffffU) == 1);
  assert(GuSelectorsValidForArch(1, 0xffffffffU, 0x88888888U, 8U, 0x00000000U) == 1);
}

static void test_pci_config_and_capabilities(void) {
  GuInit(NULL, NULL);
  UINT32 cfg[64] = {0};
  cfg[2] = 0x030000a1U;
  for (UINTN i = 0; i < sizeof(GuGpuCatalog) / sizeof(GuGpuCatalog[0]); ++i) {
    cfg[0] = ((UINT32)GuGpuCatalog[i].device_id << 16) | GU_NVIDIA_VENDOR_ID;
    assert(GuTargetConfig(cfg, 0, 1, 0, 0));
    GuCfg.board_id = cfg[0]; GuCfg.strict_board = TRUE;
    GuCfg.arch = GuGpuCatalog[i].arch == GU_ARCH_ADA ? GU_ARCH_AMPERE : GU_ARCH_ADA;
    assert(!GuTargetConfig(cfg, 0, 1, 0, 0));
    GuCfg.arch = GU_ARCH_AUTO; GuCfg.strict_board = FALSE;
  }
  cfg[0] = 0xffff10deU;
  GuCfg.board_id = cfg[0]; GuCfg.strict_board = TRUE;
  assert(!GuTargetConfig(cfg, 0, 1, 0, 0));
  GuInit(NULL, NULL);
  cfg[0] = 0x268410deU;                  /* RTX 4090 (or any catalog GPU) */
  Gu.handle = (EFI_HANDLE)(UINTN)1;
  assert(GuTargetConfig(cfg, 0, 7, 0, 0)); /* first check before location is saved */
  Gu.target_board_id = cfg[0]; Gu.target_bus = 7;
  assert(GuTargetConfig(cfg, 0, 7, 0, 0));
  assert(!GuTargetConfig(cfg, 0, 8, 0, 0));
  GuInit(NULL, NULL);
  cfg[1] = (0x0010U << 16) | 0x0006U;    /* Status: CapList, Command: MEM + BME (left on by BIOS) */
  cfg[2] = 0x030000a1U;                  /* Display controller, rev A1 */
  cfg[3] = 0x00000000U;                  /* Header type 0 */
  cfg[4] = 0x40000000U;                  /* 16 MiB BAR0 */
  cfg[11] = 0x100010deU;                 /* Subsystem ID */
  cfg[0x34 / 4] = 0x60U;                 /* Capabilities pointer -> 0x60 */

  /* 0x60: Power Management Capability (ID 0x01, next 0x78, version 3, D0) */
  cfg[0x60 / 4] = (0x0003U << 16) | (0x78U << 8) | 0x01U;
  cfg[0x64 / 4] = 0x00000008U;           /* D0 */

  /* 0x78: PCI Express Capability (ID 0x10, next 0xb4, v2 endpoint) */
  cfg[0x78 / 4] = (0x0002U << 16) | (0xb4U << 8) | 0x10U;
  cfg[0x7c / 4] = (1U << 28);            /* FLR capable */
  cfg[0x80 / 4] = 0x00100000U;           /* DevCtl/DevSta: no active FLR */

  /* 0xb4: Vendor-specific capability (ID 0x09, next 0x00, len 0x14) */
  cfg[0xb4 / 4] = (0x0014U << 16) | (0x00U << 8) | 0x09U;

  GU_CAPS caps = {0};
  /* Generic default accepts any supported RTX 3000/4000 GPU */
  assert(GuCheckConfig(cfg, 0, 1, 0, 0, &caps) == TRUE);
  assert(caps.pm == 0x60);
  assert(caps.pcie == 0x78);
  assert(caps.pcie_version == 2);

  /* Also verify an RTX 3060 (GA106) and RTX 3090 (GA102) pass generic check */
  cfg[0] = 0x250410deU;
  assert(GuCheckConfig(cfg, 0, 1, 0, 0, &caps) == TRUE);
  cfg[0] = 0x220410deU;
  assert(GuCheckConfig(cfg, 0, 1, 0, 0, &caps) == TRUE);
  cfg[0] = 0x268410deU;

  /* Once Gu.owned is true, BME must be cleared (0) */
  Gu.owned = TRUE;
  assert(GuCheckConfig(cfg, 0, 1, 0, 0, &caps) == FALSE);
  cfg[1] &= ~0x4U; /* Clear BME */
  assert(GuCheckConfig(cfg, 0, 1, 0, 0, &caps) == TRUE);

  /* Wrong subsystem rejected when strict_subsystem=1, accepted when strict_subsystem=0 */
  GuCfg.subsystem_id = 0x100010deU;
  GuCfg.strict_subsystem = TRUE;
  cfg[11] = 0x200010deU;
  assert(GuCheckConfig(cfg, 0, 1, 0, 0, &caps) == FALSE);
  GuCfg.strict_subsystem = FALSE;
  assert(GuCheckConfig(cfg, 0, 1, 0, 0, &caps) == TRUE);
}

static void test_esp_device_path_matching(void) {
  GuInit(NULL, NULL);
  const char *esp_ini =
    "windows_esp_guid = 11111111-2222-3333-4444-555555555555\n"
    "windows_esp_partition = 1\n"
    "windows_esp_start_lba = 2048\n"
    "windows_esp_size_lba = 204800\n";
  assert(GuConfigParseIni(esp_ini, strlen(esp_ini)) == TRUE);

  struct {
    HARDDRIVE_DEVICE_PATH hd;
    EFI_DEVICE_PATH_PROTOCOL end;
  } __attribute__((packed)) path;
  memset(&path, 0, sizeof(path));
  path.hd.Header.Type = MEDIA_DEVICE_PATH;
  path.hd.Header.SubType = MEDIA_HARDDRIVE_DP;
  path.hd.Header.Length[0] = sizeof(HARDDRIVE_DEVICE_PATH);
  path.hd.Header.Length[1] = 0;
  path.hd.PartitionNumber = 1;
  path.hd.PartitionStart = 2048ULL;
  path.hd.PartitionSize = 204800ULL;
  memcpy(path.hd.Signature, &GuCfg.esp_guid, sizeof(EFI_GUID));
  path.hd.MBRType = MBR_TYPE_EFI_PARTITION_TABLE_HEADER;
  path.hd.SignatureType = SIGNATURE_TYPE_GUID;
  path.end.Type = END_DEVICE_PATH_TYPE;
  path.end.SubType = END_ENTIRE_DEVICE_PATH_SUBTYPE;
  path.end.Length[0] = 4;
  path.end.Length[1] = 0;

  assert(GuWindowsEspPath((const EFI_DEVICE_PATH_PROTOCOL *)&path, sizeof(path)) == TRUE);

  /* Different partition LBA: fails exact match, passes MatchAnyGpt fallback */
  path.hd.PartitionStart = 4096ULL;
  assert(GuWindowsEspPathEx((const EFI_DEVICE_PATH_PROTOCOL *)&path, sizeof(path), FALSE) == FALSE);
  assert(GuWindowsEspPathEx((const EFI_DEVICE_PATH_PROTOCOL *)&path, sizeof(path), TRUE) == TRUE);
}

static void test_selectors_and_layout(void) {
  /* Cold selector acceptance across AD102, AD103, GA102, and GA106 */
  assert(Gu4090ColdSelectorsClosed(0x63703070U, 3U) == 1);
  assert(Gu4090ColdSelectorsClosed(0x55555556U, 2U) == 1); /* RTX 4090 AD102 */
  assert(Gu4090ColdSelectorsClosed(0x31322012U, 7U) == 1); /* RTX 4080 AD103 */
  assert(Gu4090ColdSelectorsClosed(0x50004016U, 6U) == 1); /* RTX 3090 GA102 */
  assert(Gu4090ColdSelectorsClosed(0x12210024U, 3U) == 1); /* RTX 3060 GA106 */
  assert(Gu4090ColdSelectorsClosed(0x88888888U, 8U) == 0);
  assert(Gu4090SelectorsValid(0xffffffffU, 0x88888888U, 8U, 0x00000000U) == 1);
  assert(Gu4090SelectorsValid(0xffffffffU, 0x88888888U, 8U, 0x00410080U) == 0);

  /* PMC_BOOT_0 validation across Ada (0x192..0x197) and Ampere (0xb72..0xb77 & 0x172..0x177) */
  assert(GuIsValidChipForArch(0x192000a1U, GU_ARCH_ADA) == TRUE);    /* AD102 RTX 4090 */
  assert(GuIsValidChipForArch(0x193000a1U, GU_ARCH_ADA) == TRUE);    /* AD103 RTX 4080 */
  assert(GuIsValidChipForArch(0xb72000a1U, GU_ARCH_AMPERE) == TRUE); /* GA102 RTX 3090 */
  assert(GuIsValidChipForArch(0xb76000a1U, GU_ARCH_AMPERE) == TRUE); /* GA106 RTX 3060 */
  assert(GuChipIdMatchesExpected(0xb72000a1U, 0x172000a1U) == TRUE);
  assert(GuChipIdMatchesExpected(0xb76000a1U, 0x176000a1U) == TRUE);

  struct gpu_unlock_layout_in in = {
    .usable_fb = 24ULL * 1024ULL * 1024ULL * 1024ULL,
    .vga_base = (24ULL * 1024ULL * 1024ULL * 1024ULL) - 0x4000000ULL,
    .mmu_lock_valid = false,
    .mmu_lock_low = 0ULL,
    .frts_size = 0x100000ULL,
    .boot_size = 36864ULL,
    .image_size = 84277400ULL,
    .nonwpr_size = 0x180000ULL,
    .heap_request = 0x8100000ULL,
  };
  struct gpu_unlock_layout_out out = {0};
  assert(gpu_unlock_layout(&in, &out) == 0);
  assert(out.frts_offset > 0 && out.wpr_end > out.frts_offset);
}

int main(void) {
  test_defaults_and_ini_parser();
  test_pci_config_and_capabilities();
  test_esp_device_path_matching();
  test_selectors_and_layout();
  printf("All host unit & configuration tests passed!\n");
  return 0;
}
