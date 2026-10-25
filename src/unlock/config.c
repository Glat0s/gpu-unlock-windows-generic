/* SPDX-License-Identifier: MIT
 * Freestanding parser for \RTX4090-PREP\CONFIG.INI on the USB volume.
 * Supports tailored single-board profiles and universal RTX 3000/4000 auto-discovery.
 */
#include "config.h"
#include "runtime.h"

GU_RUNTIME_CONFIG GuCfg;

static int HexDigit(char c) {
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  if (c >= 'A' && c <= 'F') return c - 'A' + 10;
  return -1;
}

static BOOLEAN IsSpace(char c) {
  return c == ' ' || c == '\t' || c == '\r' || c == '\n';
}

static char ToLower(char c) {
  return (c >= 'A' && c <= 'Z') ? (char)(c - 'A' + 'a') : c;
}

static BOOLEAN StrEqIgnoreCase(const char *a, UINTN a_len, const char *b) {
  UINTN i = 0;
  while (i < a_len && b[i]) {
    if (ToLower(a[i]) != ToLower(b[i])) return FALSE;
    i++;
  }
  return i == a_len && b[i] == 0;
}

static BOOLEAN ParseU64(const char *s, UINTN len, UINT64 *out) {
  if (!len || !out) return FALSE;
  UINTN i = 0;
  UINT64 base = 10, val = 0;
  if (len > 2 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) {
    base = 16;
    i = 2;
  }
  if (i >= len) return FALSE;
  for (; i < len; i++) {
    int d = HexDigit(s[i]);
    if (d < 0 || (UINT64)d >= base) return FALSE;
    val = val * base + (UINT64)d;
  }
  *out = val;
  return TRUE;
}

static BOOLEAN ParseGuid(const char *s, UINTN len, EFI_GUID *guid) {
  if (!s || !guid) return FALSE;
  if (len >= 2 && s[0] == '{' && s[len - 1] == '}') {
    s++;
    len -= 2;
  }
  /* Format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (36 chars) */
  if (len != 36 || s[8] != '-' || s[13] != '-' || s[18] != '-' || s[23] != '-')
    return FALSE;
  UINT32 d1 = 0;
  UINT16 d2 = 0, d3 = 0;
  UINT8 d4[8] = {0};
  for (UINTN i = 0; i < 8; i++) {
    int v = HexDigit(s[i]);
    if (v < 0) return FALSE;
    d1 = (d1 << 4) | (UINT32)v;
  }
  for (UINTN i = 9; i < 13; i++) {
    int v = HexDigit(s[i]);
    if (v < 0) return FALSE;
    d2 = (UINT16)((d2 << 4) | (UINT16)v);
  }
  for (UINTN i = 14; i < 18; i++) {
    int v = HexDigit(s[i]);
    if (v < 0) return FALSE;
    d3 = (UINT16)((d3 << 4) | (UINT16)v);
  }
  int h0 = HexDigit(s[19]), l0 = HexDigit(s[20]);
  int h1 = HexDigit(s[21]), l1 = HexDigit(s[22]);
  if (h0 < 0 || l0 < 0 || h1 < 0 || l1 < 0) return FALSE;
  d4[0] = (UINT8)((h0 << 4) | l0);
  d4[1] = (UINT8)((h1 << 4) | l1);
  for (UINTN i = 0; i < 6; i++) {
    int hi = HexDigit(s[24 + i * 2]);
    int lo = HexDigit(s[24 + i * 2 + 1]);
    if (hi < 0 || lo < 0) return FALSE;
    d4[2 + i] = (UINT8)((hi << 4) | lo);
  }
  guid->Data1 = d1;
  guid->Data2 = d2;
  guid->Data3 = d3;
  for (UINTN i = 0; i < 8; i++) guid->Data4[i] = d4[i];
  return TRUE;
}

VOID GuConfigInitDefaults(VOID) {
  static const EFI_GUID default_esp = GU_PROFILE_WINDOWS_ESP_GUID;
  static const EFI_GUID zero_guid = {0, 0, 0, {0, 0, 0, 0, 0, 0, 0, 0}};
  const GU_GPU_MODEL_INFO *model = (GU_LOCAL_BOARD_ID != 0)
    ? GuFindGpuModel((UINT16)(GU_LOCAL_BOARD_ID >> 16))
    : NULL;
  memset(&GuCfg, 0, sizeof(GuCfg));
  GuCfg.board_id = GU_LOCAL_BOARD_ID;
  GuCfg.subsystem_id = GU_LOCAL_SUBSYSTEM_ID;
  GuCfg.chip_id = GU_LOCAL_CHIP_ID;
  GuCfg.arch = model ? model->arch : ((GU_LOCAL_CHIP_ID != 0) ? GuDetectArchFromChip(GU_LOCAL_CHIP_ID, GU_ARCH_ADA) : GU_ARCH_AUTO);
  GuCfg.pci_segment = (INT32)GU_LOCAL_PCI_SEGMENT;
  GuCfg.pci_bus = (INT32)GU_LOCAL_PCI_BUS;
  GuCfg.pci_device = (INT32)GU_LOCAL_PCI_DEVICE;
  GuCfg.pci_function = (INT32)GU_LOCAL_PCI_FUNCTION;
  GuCfg.bar0_base = GU_LOCAL_BAR0_BASE;
  GuCfg.bar0_bytes = GU_LOCAL_BAR0_BYTES;
  GuCfg.strict_board = (GU_LOCAL_BOARD_ID != 0) ? TRUE : FALSE;
  GuCfg.strict_subsystem = GU_LOCAL_STRICT_SUBSYSTEM ? TRUE : FALSE;
  GuCfg.strict_chip = (GU_LOCAL_CHIP_ID != 0) ? TRUE : FALSE;
  GuCfg.strict_bdf = GU_LOCAL_STRICT_BDF ? TRUE : FALSE;
  GuCfg.strict_bar0 = GU_LOCAL_STRICT_BAR0 ? TRUE : FALSE;
  GuCfg.strict_esp = GU_LOCAL_STRICT_ESP ? TRUE : FALSE;
  GuCfg.allow_headless_handoff = GU_LOCAL_ALLOW_HEADLESS_HANDOFF ? TRUE : FALSE;
  GuCfg.save_prom_dump = GU_LOCAL_SAVE_PROM_DUMP ? TRUE : FALSE;
  GuCfg.auto_boot = GuPortCompileTimeAutoBoot() ? TRUE : FALSE;
  GuCfg.countdown_seconds = 5;
  GuCfg.esp_guid = default_esp;
  GuCfg.esp_guid_valid = memcmp(&default_esp, &zero_guid, sizeof(EFI_GUID)) != 0;
  GuCfg.esp_partition = GU_PROFILE_WINDOWS_ESP_PARTITION;
  GuCfg.esp_start_lba = GU_PROFILE_WINDOWS_ESP_START_LBA;
  GuCfg.esp_size_lba = GU_PROFILE_WINDOWS_ESP_SIZE_LBA;
  GuCfg.config_file_loaded = FALSE;
}

static VOID ApplyKeyValue(const char *k, UINTN k_len, const char *v, UINTN v_len) {
  UINT64 num = 0;
  BOOLEAN is_any = StrEqIgnoreCase(v, v_len, "any") || StrEqIgnoreCase(v, v_len, "auto");
  if (StrEqIgnoreCase(k, k_len, "mode")) {
    if (StrEqIgnoreCase(v, v_len, "auto") || StrEqIgnoreCase(v, v_len, "automatic"))
      GuCfg.auto_boot = TRUE;
    else if (StrEqIgnoreCase(v, v_len, "manual"))
      GuCfg.auto_boot = FALSE;
  } else if (StrEqIgnoreCase(k, k_len, "countdown") || StrEqIgnoreCase(k, k_len, "countdown_sec")) {
    if (ParseU64(v, v_len, &num) && num >= 1 && num <= 60)
      GuCfg.countdown_seconds = (UINT32)num;
  } else if (StrEqIgnoreCase(k, k_len, "arch") || StrEqIgnoreCase(k, k_len, "series")) {
    if (is_any) {
      GuCfg.arch = GU_ARCH_AUTO;
    } else if (StrEqIgnoreCase(v, v_len, "ada") || StrEqIgnoreCase(v, v_len, "ad10x") ||
               StrEqIgnoreCase(v, v_len, "ad102") || StrEqIgnoreCase(v, v_len, "4000") ||
               StrEqIgnoreCase(v, v_len, "rtx4000")) {
      GuCfg.arch = GU_ARCH_ADA;
    } else if (StrEqIgnoreCase(v, v_len, "ampere") || StrEqIgnoreCase(v, v_len, "ga10x") ||
               StrEqIgnoreCase(v, v_len, "ga102") || StrEqIgnoreCase(v, v_len, "3000") ||
               StrEqIgnoreCase(v, v_len, "rtx3000")) {
      GuCfg.arch = GU_ARCH_AMPERE;
    }
  } else if (StrEqIgnoreCase(k, k_len, "board_id")) {
    if (is_any) {
      GuCfg.board_id = 0;
      GuCfg.strict_board = FALSE;
    } else if (ParseU64(v, v_len, &num)) {
      GuCfg.board_id = (UINT32)num;
      GuCfg.strict_board = (num != 0);
      if (num != 0) {
        const GU_GPU_MODEL_INFO *m = GuFindGpuModel((UINT16)(num >> 16));
        if (m) GuCfg.arch = m->arch;
      }
    }
  } else if (StrEqIgnoreCase(k, k_len, "subsystem_id")) {
    if (is_any) {
      GuCfg.subsystem_id = 0;
      GuCfg.strict_subsystem = FALSE;
    } else if (ParseU64(v, v_len, &num)) {
      GuCfg.subsystem_id = (UINT32)num;
    }
  } else if (StrEqIgnoreCase(k, k_len, "chip_id")) {
    if (is_any) {
      GuCfg.chip_id = 0;
      GuCfg.strict_chip = FALSE;
    } else if (ParseU64(v, v_len, &num)) {
      GuCfg.chip_id = (UINT32)num;
      GuCfg.strict_chip = (num != 0);
    }
  } else if (StrEqIgnoreCase(k, k_len, "pci_segment")) {
    if (is_any) GuCfg.pci_segment = -1;
    else if (ParseU64(v, v_len, &num)) GuCfg.pci_segment = (INT32)num;
  } else if (StrEqIgnoreCase(k, k_len, "pci_bus")) {
    if (is_any) GuCfg.pci_bus = -1;
    else if (ParseU64(v, v_len, &num)) GuCfg.pci_bus = (INT32)num;
  } else if (StrEqIgnoreCase(k, k_len, "pci_device")) {
    if (is_any) GuCfg.pci_device = -1;
    else if (ParseU64(v, v_len, &num)) GuCfg.pci_device = (INT32)num;
  } else if (StrEqIgnoreCase(k, k_len, "pci_function")) {
    if (is_any) GuCfg.pci_function = -1;
    else if (ParseU64(v, v_len, &num)) GuCfg.pci_function = (INT32)num;
  } else if (StrEqIgnoreCase(k, k_len, "bar0_base")) {
    if (is_any) {
      GuCfg.bar0_base = 0;
      GuCfg.strict_bar0 = FALSE;
    } else if (ParseU64(v, v_len, &num)) {
      GuCfg.bar0_base = num;
    }
  } else if (StrEqIgnoreCase(k, k_len, "bar0_bytes")) {
    if (ParseU64(v, v_len, &num) && num > 0) {
      GuCfg.bar0_bytes = num;
    }
  } else if (StrEqIgnoreCase(k, k_len, "strict_board")) {
    if (ParseU64(v, v_len, &num)) GuCfg.strict_board = num != 0;
  } else if (StrEqIgnoreCase(k, k_len, "strict_subsystem")) {
    if (ParseU64(v, v_len, &num)) GuCfg.strict_subsystem = num != 0;
  } else if (StrEqIgnoreCase(k, k_len, "strict_chip")) {
    if (ParseU64(v, v_len, &num)) GuCfg.strict_chip = num != 0;
  } else if (StrEqIgnoreCase(k, k_len, "strict_bdf")) {
    if (ParseU64(v, v_len, &num)) GuCfg.strict_bdf = num != 0;
  } else if (StrEqIgnoreCase(k, k_len, "strict_bar0")) {
    if (ParseU64(v, v_len, &num)) GuCfg.strict_bar0 = num != 0;
  } else if (StrEqIgnoreCase(k, k_len, "strict_esp")) {
    if (ParseU64(v, v_len, &num)) GuCfg.strict_esp = num != 0;
  } else if (StrEqIgnoreCase(k, k_len, "allow_headless_handoff")) {
    if (ParseU64(v, v_len, &num)) GuCfg.allow_headless_handoff = num != 0;
  } else if (StrEqIgnoreCase(k, k_len, "save_prom_dump")) {
    if (ParseU64(v, v_len, &num)) GuCfg.save_prom_dump = num != 0;
  } else if (StrEqIgnoreCase(k, k_len, "windows_esp_guid") || StrEqIgnoreCase(k, k_len, "esp_guid")) {
    EFI_GUID parsed;
    if (is_any) {
      GuCfg.esp_guid_valid = FALSE;
      GuCfg.strict_esp = FALSE;
    } else if (ParseGuid(v, v_len, &parsed)) {
      GuCfg.esp_guid = parsed;
      GuCfg.esp_guid_valid = TRUE;
    }
  } else if (StrEqIgnoreCase(k, k_len, "windows_esp_partition") || StrEqIgnoreCase(k, k_len, "esp_part")) {
    if (is_any) GuCfg.esp_partition = 0;
    else if (ParseU64(v, v_len, &num)) GuCfg.esp_partition = (UINT32)num;
  } else if (StrEqIgnoreCase(k, k_len, "windows_esp_start_lba") || StrEqIgnoreCase(k, k_len, "esp_start_lba")) {
    if (is_any) GuCfg.esp_start_lba = 0;
    else if (ParseU64(v, v_len, &num)) GuCfg.esp_start_lba = num;
  } else if (StrEqIgnoreCase(k, k_len, "windows_esp_size_lba") || StrEqIgnoreCase(k, k_len, "esp_size_lba")) {
    if (is_any) GuCfg.esp_size_lba = 0;
    else if (ParseU64(v, v_len, &num)) GuCfg.esp_size_lba = num;
  }
}

BOOLEAN GuConfigParseIni(const char *Text, UINTN Length) {
  if (!Text || Length > 65536) return FALSE;
  UINTN pos = 0;
  while (pos < Length) {
    UINTN line_start = pos;
    while (pos < Length && Text[pos] != '\n' && Text[pos] != '\r') pos++;
    UINTN line_end = pos;
    while (pos < Length && (Text[pos] == '\n' || Text[pos] == '\r')) pos++;

    /* Strip comments (# or ;) */
    UINTN clean_end = line_start;
    while (clean_end < line_end && Text[clean_end] != '#' && Text[clean_end] != ';')
      clean_end++;

    /* Trim leading whitespace */
    UINTN s = line_start;
    while (s < clean_end && IsSpace(Text[s])) s++;
    if (s >= clean_end) continue;

    /* Find '=' */
    UINTN eq = s;
    while (eq < clean_end && Text[eq] != '=') eq++;
    if (eq >= clean_end) continue;

    UINTN k_end = eq;
    while (k_end > s && IsSpace(Text[k_end - 1])) k_end--;

    UINTN v_start = eq + 1;
    while (v_start < clean_end && IsSpace(Text[v_start])) v_start++;
    UINTN v_end = clean_end;
    while (v_end > v_start && IsSpace(Text[v_end - 1])) v_end--;

    if (k_end > s && v_end > v_start) {
      ApplyKeyValue(Text + s, k_end - s, Text + v_start, v_end - v_start);
    }
  }
  GuCfg.config_file_loaded = TRUE;
  return TRUE;
}

int GuPortAutomaticBoot(void) {
  if (!GuPortHardwareEnabled()) return 0;
  return GuCfg.auto_boot ? 1 : 0;
}
