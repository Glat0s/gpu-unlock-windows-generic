/* SPDX-License-Identifier: GPL-2.0-only
 * Complete NVIDIA GeForce RTX 3000 (Ampere GA10x) & RTX 4000 (Ada Lovelace AD10x)
 * GPU Device & Architecture Catalog for the Windows UEFI Unlocker.
 */
#ifndef GU_GPU_CATALOG_H
#define GU_GPU_CATALOG_H

#include <Uefi.h>

#define GU_NVIDIA_VENDOR_ID 0x10deU

typedef enum {
  GU_ARCH_AMPERE = 0, /* RTX 3000 Series: GA102, GA103, GA104, GA106, GA107 */
  GU_ARCH_ADA    = 1, /* RTX 4000 Series: AD102, AD103, AD104, AD106, AD107 */
  GU_ARCH_AUTO   = 2
} GU_GPU_ARCH;

typedef struct {
  UINT16      device_id;
  UINT8       arch;        /* GU_ARCH_AMPERE or GU_ARCH_ADA */
  UINT16      pmc_prefix;  /* Expected (PMC_BOOT_0 >> 20), e.g. 0x192 for AD102, 0x172 for GA102 */
  const char *chip_family; /* e.g. "AD102", "GA102" */
  const char *name;        /* e.g. "GeForce RTX 4090" */
} GU_GPU_MODEL_INFO;

static const GU_GPU_MODEL_INFO GuGpuCatalog[] = {
  /* ================= RTX 4000 Series (Ada Lovelace - AD10x) ================= */
  /* AD102 */
  { 0x2684U, GU_ARCH_ADA, 0x192U, "AD102", "GeForce RTX 4090" },
  { 0x2685U, GU_ARCH_ADA, 0x192U, "AD102", "GeForce RTX 4090 D" },
  { 0x2689U, GU_ARCH_ADA, 0x192U, "AD102", "GeForce RTX 4090 (AD102 Variant)" },
  /* AD103 */
  { 0x2702U, GU_ARCH_ADA, 0x193U, "AD103", "GeForce RTX 4080 SUPER" },
  { 0x2703U, GU_ARCH_ADA, 0x193U, "AD103", "GeForce RTX 4080 (AD103 Variant)" },
  { 0x2704U, GU_ARCH_ADA, 0x193U, "AD103", "GeForce RTX 4080" },
  { 0x2705U, GU_ARCH_ADA, 0x193U, "AD103", "GeForce RTX 4070 Ti SUPER" },
  { 0x2709U, GU_ARCH_ADA, 0x193U, "AD103", "GeForce RTX 4070 (AD103)" },
  { 0x2717U, GU_ARCH_ADA, 0x193U, "AD103", "GeForce RTX 4090 Laptop GPU" },
  { 0x2757U, GU_ARCH_ADA, 0x193U, "AD103", "GeForce RTX 4090 Laptop GPU (Max-Q)" },
  /* AD104 */
  { 0x2782U, GU_ARCH_ADA, 0x194U, "AD104", "GeForce RTX 4070 Ti" },
  { 0x2783U, GU_ARCH_ADA, 0x194U, "AD104", "GeForce RTX 4070 SUPER" },
  { 0x2786U, GU_ARCH_ADA, 0x194U, "AD104", "GeForce RTX 4070" },
  { 0x2788U, GU_ARCH_ADA, 0x194U, "AD104", "GeForce RTX 4060 Ti (AD104)" },
  { 0x27a0U, GU_ARCH_ADA, 0x194U, "AD104", "GeForce RTX 4080 Laptop GPU" },
  { 0x27e0U, GU_ARCH_ADA, 0x194U, "AD104", "GeForce RTX 4080 Laptop GPU (Max-Q)" },
  /* AD106 */
  { 0x2803U, GU_ARCH_ADA, 0x196U, "AD106", "GeForce RTX 4060 Ti 8GB" },
  { 0x2805U, GU_ARCH_ADA, 0x196U, "AD106", "GeForce RTX 4060 Ti 16GB" },
  { 0x2808U, GU_ARCH_ADA, 0x196U, "AD106", "GeForce RTX 4060 (AD106)" },
  { 0x2820U, GU_ARCH_ADA, 0x196U, "AD106", "GeForce RTX 4070 Laptop GPU" },
  { 0x2860U, GU_ARCH_ADA, 0x196U, "AD106", "GeForce RTX 4070 Laptop GPU (Max-Q)" },
  /* AD107 */
  { 0x2882U, GU_ARCH_ADA, 0x197U, "AD107", "GeForce RTX 4060" },
  { 0x28a0U, GU_ARCH_ADA, 0x197U, "AD107", "GeForce RTX 4060 Laptop GPU" },
  { 0x28a1U, GU_ARCH_ADA, 0x197U, "AD107", "GeForce RTX 4050 Laptop GPU" },
  { 0x28e0U, GU_ARCH_ADA, 0x197U, "AD107", "GeForce RTX 4060 Laptop GPU (Max-Q)" },
  { 0x28e1U, GU_ARCH_ADA, 0x197U, "AD107", "GeForce RTX 4050 Laptop GPU (Max-Q)" },

  /* ================= RTX 3000 Series (Ampere - GA10x) ================= */
  /* GA102 */
  { 0x2200U, GU_ARCH_AMPERE, 0x172U, "GA102", "GeForce RTX 3090 Ti / GA102" },
  { 0x2203U, GU_ARCH_AMPERE, 0x172U, "GA102", "GeForce RTX 3090 Ti" },
  { 0x2204U, GU_ARCH_AMPERE, 0x172U, "GA102", "GeForce RTX 3090" },
  { 0x2205U, GU_ARCH_AMPERE, 0x172U, "GA102", "GeForce RTX 3080 Ti 20GB / GA102" },
  { 0x2206U, GU_ARCH_AMPERE, 0x172U, "GA102", "GeForce RTX 3080 10GB" },
  { 0x2207U, GU_ARCH_AMPERE, 0x172U, "GA102", "GeForce RTX 3080 Ti (GA102)" },
  { 0x2208U, GU_ARCH_AMPERE, 0x172U, "GA102", "GeForce RTX 3080 Ti 12GB" },
  { 0x220aU, GU_ARCH_AMPERE, 0x172U, "GA102", "GeForce RTX 3080 12GB" },
  { 0x220dU, GU_ARCH_AMPERE, 0x172U, "GA102", "NVIDIA CMP 90HX (GA102)" },
  { 0x2216U, GU_ARCH_AMPERE, 0x172U, "GA102", "GeForce RTX 3080 10GB LHR" },
  { 0x222bU, GU_ARCH_AMPERE, 0x172U, "GA102", "GeForce RTX 3080 / GA102 Variant" },
  { 0x222fU, GU_ARCH_AMPERE, 0x172U, "GA102", "GeForce RTX 3080 / GA102 OEM" },
  /* GA103 */
  { 0x2414U, GU_ARCH_AMPERE, 0x173U, "GA103", "GeForce RTX 3060 Ti (GA103)" },
  { 0x2420U, GU_ARCH_AMPERE, 0x173U, "GA103", "GeForce RTX 3080 Ti Laptop GPU" },
  { 0x2460U, GU_ARCH_AMPERE, 0x173U, "GA103", "GeForce RTX 3080 Ti Laptop GPU (Max-Q)" },
  /* GA104 */
  { 0x2480U, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3070 / GA104" },
  { 0x2482U, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3070 Ti" },
  { 0x2483U, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3070 (GA104 Variant)" },
  { 0x2484U, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3070" },
  { 0x2486U, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3060 Ti" },
  { 0x2487U, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3060 (GA104)" },
  { 0x2488U, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3070 LHR" },
  { 0x2489U, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3060 Ti LHR" },
  { 0x248aU, GU_ARCH_AMPERE, 0x174U, "GA104", "NVIDIA CMP 70HX (GA104)" },
  { 0x248cU, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3060 Ti GDDR6X" },
  { 0x248dU, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3070 Laptop / GA104" },
  { 0x248eU, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3070 / GA104 OEM" },
  { 0x249cU, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3080 Laptop GPU" },
  { 0x249dU, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3070 Laptop GPU" },
  { 0x249fU, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3070 Laptop GPU (Variant)" },
  { 0x24a0U, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3070 Ti Laptop GPU" },
  { 0x24a4U, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3070 Laptop / GA104" },
  { 0x24acU, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3080 Laptop / GA104" },
  { 0x24adU, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3070 Laptop / GA104" },
  { 0x24afU, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3070 Laptop / GA104" },
  { 0x24bfU, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3070 / GA104" },
  { 0x24c0U, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3080 Ti / GA104" },
  { 0x24c7U, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3060 / GA104" },
  { 0x24c8U, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3070 Ti / GA104" },
  { 0x24c9U, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3070 Ti (GA104)" },
  { 0x24dcU, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3080 Laptop GPU (Max-Q)" },
  { 0x24ddU, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3070 Laptop GPU (Max-Q)" },
  { 0x24dfU, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3070 Laptop GPU" },
  { 0x24e0U, GU_ARCH_AMPERE, 0x174U, "GA104", "GeForce RTX 3070 Ti Laptop GPU (Max-Q)" },
  /* GA106 */
  { 0x2501U, GU_ARCH_AMPERE, 0x176U, "GA106", "GeForce RTX 3060 (GA106)" },
  { 0x2503U, GU_ARCH_AMPERE, 0x176U, "GA106", "GeForce RTX 3060 12GB" },
  { 0x2504U, GU_ARCH_AMPERE, 0x176U, "GA106", "GeForce RTX 3060 12GB LHR" },
  { 0x2505U, GU_ARCH_AMPERE, 0x176U, "GA106", "GeForce RTX 3060 (GA106 Variant)" },
  { 0x2507U, GU_ARCH_AMPERE, 0x176U, "GA106", "GeForce RTX 3050 8GB (GA106)" },
  { 0x2508U, GU_ARCH_AMPERE, 0x176U, "GA106", "GeForce RTX 3050 OEM (GA106)" },
  { 0x2509U, GU_ARCH_AMPERE, 0x176U, "GA106", "GeForce RTX 3050 (GA106)" },
  { 0x2520U, GU_ARCH_AMPERE, 0x176U, "GA106", "GeForce RTX 3060 Laptop GPU" },
  { 0x252fU, GU_ARCH_AMPERE, 0x176U, "GA106", "GeForce RTX 3060 / GA106" },
  { 0x2544U, GU_ARCH_AMPERE, 0x176U, "GA106", "GeForce RTX 3060 / GA106 Variant" },
  { 0x2560U, GU_ARCH_AMPERE, 0x176U, "GA106", "GeForce RTX 3060 Laptop GPU (Max-Q)" },
  { 0x25a0U, GU_ARCH_AMPERE, 0x176U, "GA106", "GeForce RTX 3050 Ti Laptop GPU" },
  { 0x25e0U, GU_ARCH_AMPERE, 0x176U, "GA106", "GeForce RTX 3050 Ti Laptop GPU (Max-Q)" },
  /* GA107 */
  { 0x2582U, GU_ARCH_AMPERE, 0x177U, "GA107", "GeForce RTX 3050 8GB" },
  { 0x2584U, GU_ARCH_AMPERE, 0x177U, "GA107", "GeForce RTX 3050 6GB" },
  { 0x25a2U, GU_ARCH_AMPERE, 0x177U, "GA107", "GeForce RTX 3050 Laptop GPU" },
  { 0x25a5U, GU_ARCH_AMPERE, 0x177U, "GA107", "GeForce RTX 3050 Laptop GPU (4GB)" },
  { 0x25e2U, GU_ARCH_AMPERE, 0x177U, "GA107", "GeForce RTX 3050 Laptop GPU (Max-Q)" },
  { 0x25e5U, GU_ARCH_AMPERE, 0x177U, "GA107", "GeForce RTX 3050 Laptop GPU (Max-Q)" }
};

static inline const GU_GPU_MODEL_INFO *GuFindGpuModel(UINT16 DeviceId) {
  UINTN i;
  for (i = 0; i < sizeof(GuGpuCatalog) / sizeof(GuGpuCatalog[0]); ++i) {
    if (GuGpuCatalog[i].device_id == DeviceId) {
      return &GuGpuCatalog[i];
    }
  }
  return NULL;
}

static inline BOOLEAN GuIsSupportedBoardId(UINT32 BoardId) {
  UINT16 vendor = (UINT16)(BoardId & 0xffffU);
  UINT16 device = (UINT16)(BoardId >> 16);
  if (vendor != GU_NVIDIA_VENDOR_ID) return FALSE;
  return GuFindGpuModel(device) != NULL;
}

static inline BOOLEAN GuIsValidChipForArch(UINT32 ChipId, UINT8 Arch) {
  /* NV_PMC_BOOT_0_ARCHITECTURE..IMPLEMENTATION is bits [28:20] (9 bits).
   * On Ampere (GA102..GA107), bits [31:29] are 0b101 (e.g. 0xb72000a1 for GA102,
   * 0xb76000a1 for GA106), so masking with 0x1ffU yields 0x172..0x177.
   * On Ada (AD102..AD107), masking with 0x1ffU yields 0x192..0x197. */
  UINT32 prefix = (ChipId >> 20) & 0x1ffU;
  if (ChipId == 0 || ChipId == 0xffffffffU || (ChipId & 0xffff0000U) == 0xbadf0000U)
    return FALSE;
  if (Arch == GU_ARCH_ADA) {
    return prefix >= 0x192U && prefix <= 0x197U;
  }
  if (Arch == GU_ARCH_AMPERE) {
    return prefix >= 0x172U && prefix <= 0x177U;
  }
  return (prefix >= 0x172U && prefix <= 0x177U) || (prefix >= 0x192U && prefix <= 0x197U);
}

static inline UINT8 GuDetectArchFromChip(UINT32 ChipId, UINT8 FallbackArch) {
  UINT32 prefix = (ChipId >> 20) & 0x1ffU;
  if (prefix >= 0x192U && prefix <= 0x197U) return GU_ARCH_ADA;
  if (prefix >= 0x172U && prefix <= 0x177U) return GU_ARCH_AMPERE;
  return FallbackArch == GU_ARCH_AMPERE ? GU_ARCH_AMPERE : GU_ARCH_ADA;
}

static inline BOOLEAN GuChipIdMatchesExpected(UINT32 ActualBoot0, UINT32 ExpectedChipId) {
  if (ActualBoot0 == ExpectedChipId) return TRUE;
  return ((ActualBoot0 ^ ExpectedChipId) & 0x1ff000ffU) == 0;
}

#endif
