/* SPDX-License-Identifier: GPL-2.0-only */
#pragma once
#include <stdint.h>
/* Cold selector payloads vary between power-ons. Each SS0 nibble uses bit 3
 * to enable its override; SS1 has one such nibble and no accepted upper bits.
 * This does not relax the exact post-unlock selectors checked below. */
static inline int Gu4090ColdSelectorsClosed(uint32_t ss0, uint32_t ss1) {
  return !(ss0 & 0x88888888U) && !(ss1 & ~7U);
}
/* AD10x: all nine 3-bit effective rate fields must read zero. FEAT PLM
 * legitimately reads all ones when opened; do not treat that value as a fault.
 */
static inline int Gu4090SelectorsValid(uint32_t plm, uint32_t ss0,
                                     uint32_t ss1, uint32_t effective) {
  return plm == UINT32_MAX && ss0 == 0x88888888U && ss1 == 8U &&
    (effective & 0xffff0000U) != 0xbadf0000U &&
    effective != UINT32_MAX && (effective & 0x07ffffffU) == 0;
}
/* GA10x (Ampere RTX 3000 series): SS0 == 0x88888888 and SS1 == 8, and FEAT PLM
 * is readable (not 0xbadfxxxx). */
static inline int GuSelectorsValidForArch(uint8_t is_ada, uint32_t plm,
                                          uint32_t ss0, uint32_t ss1,
                                          uint32_t effective) {
  if (is_ada) {
    return Gu4090SelectorsValid(plm, ss0, ss1, effective);
  }
  return (plm & 0xffff0000U) != 0xbadf0000U &&
         ss0 == 0x88888888U && ss1 == 8U;
}
