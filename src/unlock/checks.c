/* SPDX-License-Identifier: GPL-2.0-only */
#include "checks.h"
#include "runtime.h"
#include <IndustryStandard/Pci.h>

#define GU_CONFIG_BYTES 256U
#define GU_CAP_START 0x40U
#define GU_CAP_LAST 0xfcU
#define GU_CAP_LIMIT ((GU_CONFIG_BYTES - GU_CAP_START) / 4U)
#define GU_MSIX_ID 0x11U

static UINT8 ConfigByte(const UINT32 Config[64], UINTN Offset) {
  return (UINT8)(Config[Offset / 4U] >> ((Offset & 3U) * 8U));
}

static UINT16 ConfigWord(const UINT32 Config[64], UINTN Offset) {
  return (UINT16)(ConfigByte(Config, Offset) |
                  ((UINT16)ConfigByte(Config, Offset + 1U) << 8U));
}

BOOLEAN GuCheckConfig(const UINT32 Config[64], UINTN Segment, UINTN Bus,
                      UINTN Device, UINTN Function, GU_CAPS *Out) {
  GU_CAPS Caps = {0, 0, 0, 0, 0};
  UINT8 Occupied[GU_CONFIG_BYTES - GU_CAP_START] = {0};
  UINT64 Seen = 0;
  UINTN Pointer, Steps = 0;
  UINT16 Command;

  if (Out == NULL) return FALSE;
  *Out = Caps;
  if (Config == NULL || !GuTargetConfig(Config, Segment, Bus, Device, Function))
    return FALSE;
  if (ConfigByte(Config, 0x0b) != PCI_CLASS_DISPLAY ||
      (ConfigByte(Config, PCI_HEADER_TYPE_OFFSET) & 0x7fU) != HEADER_TYPE_DEVICE)
    return FALSE;

  Command = ConfigWord(Config, PCI_COMMAND_OFFSET);
  /* Memory space must be enabled and Expansion ROM disabled.
   * Note: If the motherboard BIOS or UEFI GOP driver has Bus Master enabled
   * before exclusive claim, we clear BME upon claiming the controller (matching
   * upstream gpu-unlock-ada). Once owned & armed, BME must be 0 before transaction. */
  if ((Command & EFI_PCI_COMMAND_MEMORY_SPACE) == 0 ||
      (Gu.owned && (Command & EFI_PCI_COMMAND_BUS_MASTER) != 0) ||
      (Config[PCI_EXPANSION_ROM_BASE / 4] & 1U) != 0 ||
      (ConfigWord(Config, PCI_PRIMARY_STATUS_OFFSET) & EFI_PCI_STATUS_CAPABILITY) == 0)
    return FALSE;

  Pointer = ConfigByte(Config, PCI_CAPABILITY_POINTER_OFFSET);
  while (Pointer != 0) {
    UINTN Length, I;
    UINT16 Control;
    UINT8 Id, Next;
    UINT64 Bit;
    if (++Steps > GU_CAP_LIMIT || Pointer < GU_CAP_START || Pointer > GU_CAP_LAST ||
        (Pointer & 3U) != 0)
      return FALSE;
    Bit = (UINT64)1U << (Pointer / 4U);
    if ((Seen & Bit) != 0) return FALSE;
    Seen |= Bit;

    Id = ConfigByte(Config, Pointer);
    Next = ConfigByte(Config, Pointer + 1U);
    Control = ConfigWord(Config, Pointer + 2U);
    switch (Id) {
      case EFI_PCI_CAPABILITY_ID_PMI:
        if (Caps.pm != 0 || (Control & 7U) == 0 || (Control & 7U) > 3)
          return FALSE;
        Length = 8;
        break;
      case EFI_PCI_CAPABILITY_ID_MSI:
        if (Caps.msi != 0 || (Control & 1U) != 0) return FALSE;
        Length = (Control & 0x80U) != 0 ? 14U : 10U;
        if ((Control & 0x100U) != 0) Length += 10U;
        break;
      case PCI_EXPRESS_CAPABILITY_ID:
        if (Caps.pcie != 0 || (Control & 0x0fU) < 1 ||
            (Control & 0x0fU) > 2 || ((Control >> 4U) & 0x0fU) > 1)
          return FALSE;
        Length = (Control & 0x0fU) == 1 ? 0x14U : 0x3cU;
        break;
      case GU_MSIX_ID:
        if (Caps.msix != 0 || (Control & 0x8000U) != 0) return FALSE;
        Length = 12;
        break;
      case EFI_PCI_CAPABILITY_ID_VENDOR:
        Length = Control & 0xffU;
        if (Length < 3) return FALSE;
        break;
      default:
        /* Other standard PCI capabilities (e.g., VPD, Subsystem ID) occupy at least 4 bytes. */
        Length = 4;
        break;
    }

    if (Length > GU_CONFIG_BYTES - Pointer) return FALSE;
    for (I = Pointer; I < Pointer + Length; ++I) {
      if (Occupied[I - GU_CAP_START] != 0) return FALSE;
      Occupied[I - GU_CAP_START] = 1;
    }

    switch (Id) {
      case EFI_PCI_CAPABILITY_ID_PMI:
        if ((ConfigWord(Config, Pointer + 4U) & 3U) != PCI_POWER_STATE_D0)
          return FALSE;
        Caps.pm = (UINT16)Pointer;
        break;
      case EFI_PCI_CAPABILITY_ID_MSI:
        Caps.msi = (UINT16)Pointer;
        break;
      case PCI_EXPRESS_CAPABILITY_ID:
        if ((Config[(Pointer + 4U) / 4U] & (1U << 28U)) == 0 ||
            (ConfigWord(Config, Pointer + 8U) & 0x8000U) != 0)
          return FALSE;
        Caps.pcie = (UINT16)Pointer;
        Caps.pcie_version = (UINT8)(Control & 0x0fU);
        break;
      case GU_MSIX_ID:
        Caps.msix = (UINT16)Pointer;
        break;
      default:
        break;
    }
    Pointer = Next;
  }
  if (Caps.pm == 0 || Caps.pcie == 0) return FALSE;
  *Out = Caps;
  return TRUE;
}

static UINT16 Read16(const UINT8 *Bytes) {
  return (UINT16)(Bytes[0] | ((UINT16)Bytes[1] << 8U));
}

static UINT32 Read32(const UINT8 *Bytes) {
  return (UINT32)Read16(Bytes) | ((UINT32)Read16(Bytes + 2) << 16U);
}

static UINT16 NodeLength(const UINT8 *Bytes, UINTN Remaining) {
  UINT16 Length;
  if (Remaining < sizeof(EFI_DEVICE_PATH_PROTOCOL)) return 0;
  Length = Read16(Bytes + 2);
  if (Length < sizeof(EFI_DEVICE_PATH_PROTOCOL) || Length > Remaining) return 0;
  return Length;
}

static BOOLEAN TakePci(const UINT8 **Bytes, UINTN *Remaining, UINT8 Device) {
  const UINT8 *Node = *Bytes;
  if (NodeLength(Node, *Remaining) != sizeof(PCI_DEVICE_PATH) ||
      Node[0] != HARDWARE_DEVICE_PATH || Node[1] != HW_PCI_DP ||
      Node[4] != 0 || Node[5] != Device)
    return FALSE;
  *Bytes += sizeof(PCI_DEVICE_PATH);
  *Remaining -= sizeof(PCI_DEVICE_PATH);
  return TRUE;
}

BOOLEAN GuWindowsEspPathEx(const EFI_DEVICE_PATH_PROTOCOL *Path, UINTN MaxBytes, BOOLEAN MatchAnyGpt) {
  if (!Path || MaxBytes > 4096) return FALSE;
  const UINT8 *bytes = (const UINT8 *)Path;
  BOOLEAN found = FALSE;
  UINTN used = 0;
  for (UINTN nodes = 0; nodes < 128 && used < MaxBytes; nodes++) {
    UINT16 len = NodeLength(bytes + used, MaxBytes - used);
    if (!len) return FALSE;
    const UINT8 *node = bytes + used;
    if (node[0] == END_DEVICE_PATH_TYPE)
      return found && node[1] == END_ENTIRE_DEVICE_PATH_SUBTYPE && len == 4;
    if (node[0] == MEDIA_DEVICE_PATH) {
      if (node[1] != MEDIA_HARDDRIVE_DP || len != sizeof(HARDDRIVE_DEVICE_PATH) || found)
        return FALSE;
      HARDDRIVE_DEVICE_PATH disk;
      memcpy(&disk, node, sizeof(disk));
      if (disk.MBRType != MBR_TYPE_EFI_PARTITION_TABLE_HEADER ||
          disk.SignatureType != SIGNATURE_TYPE_GUID)
        return FALSE;
      if (!MatchAnyGpt) {
        if (!GuCfg.esp_guid_valid) return FALSE;
        if (memcmp(disk.Signature, &GuCfg.esp_guid, sizeof(GuCfg.esp_guid))) return FALSE;
        if (GuCfg.esp_partition != 0 && disk.PartitionNumber != GuCfg.esp_partition) return FALSE;
        if (GuCfg.esp_start_lba != 0 && disk.PartitionStart != GuCfg.esp_start_lba) return FALSE;
        if (GuCfg.esp_size_lba != 0 && disk.PartitionSize != GuCfg.esp_size_lba) return FALSE;
      }
      found = TRUE;
    } else if (found) {
      return FALSE;
    }
    used += len;
  }
  return FALSE;
}

BOOLEAN GuWindowsEspPath(const EFI_DEVICE_PATH_PROTOCOL *Path, UINTN MaxBytes) {
  return GuWindowsEspPathEx(Path, MaxBytes, FALSE);
}

int GuDisplayPath(const EFI_DEVICE_PATH_PROTOCOL *Path, UINTN MaxBytes) {
  const UINT8 *Bytes = (const UINT8 *)Path;
  UINT32 Hid;
  int Route;
  if (Path == NULL || NodeLength(Bytes, MaxBytes) != sizeof(ACPI_HID_DEVICE_PATH) ||
      Bytes[0] != ACPI_DEVICE_PATH || Bytes[1] != ACPI_DP)
    return 0;
  Hid = Read32(Bytes + 4);
  if ((Hid != EISA_PNP_ID(0x0a03) && Hid != EISA_PNP_ID(0x0a08)) ||
      Read32(Bytes + 8) != 0)
    return 0;
  Bytes += sizeof(ACPI_HID_DEVICE_PATH);
  MaxBytes -= sizeof(ACPI_HID_DEVICE_PATH);

  if (TakePci(&Bytes, &MaxBytes, 2)) {
    Route = 1;
  } else if (TakePci(&Bytes, &MaxBytes, 1) && TakePci(&Bytes, &MaxBytes, 0)) {
    Route = 2;
  } else {
    return 0;
  }
  for (;;) {
    UINT16 Length = NodeLength(Bytes, MaxBytes);
    if (Length == 0) return 0;
    if (Bytes[0] == END_DEVICE_PATH_TYPE) {
      if (Bytes[1] != END_ENTIRE_DEVICE_PATH_SUBTYPE ||
          Length != sizeof(EFI_DEVICE_PATH_PROTOCOL))
        return 0;
      return Route;
    }
    if (Bytes[0] != ACPI_DEVICE_PATH || Bytes[1] != ACPI_ADR_DP ||
        Length < sizeof(ACPI_ADR_DEVICE_PATH) || (Length & 3U) != 0)
      return 0;
    Bytes += Length;
    MaxBytes -= Length;
  }
}
