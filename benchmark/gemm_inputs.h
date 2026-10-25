/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef GPU_UNLOCK_GEMM_INPUTS_H
#define GPU_UNLOCK_GEMM_INPUTS_H
#include <stdint.h>

/* Seeded dyadic values are exact in FP16/BF16, as are these small GEMMs'
 * products and FP32 sums. Mix both coordinates to avoid repeated rows. */
static inline float gemm_input(unsigned int row, unsigned int col, uint32_t seed)
{
	uint32_t value = seed ^ (row + 1u) * 0x9e3779b9u ^ (col + 1u) * 0x85ebca6bu;

	value ^= value >> 16;
	value *= 0x7feb352du;
	value ^= value >> 15;
	value *= 0x846ca68bu;
	value ^= value >> 16;
	return ((int)(value & 31u) - 16) / 16.0f;
}
#endif
