/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef GPU_UNLOCK_BENCH_ARGS_H
#define GPU_UNLOCK_BENCH_ARGS_H
#include <errno.h>
#include <stdbool.h>
#include <stdlib.h>

static inline bool bench_positive_count(const char *text, unsigned long long maximum,
				       unsigned long long *out)
{
	char *end;
	unsigned long long value;

	if (!text || *text < '0' || *text > '9')
		return false;
	errno = 0;
	value = strtoull(text, &end, 0);
	if (errno == ERANGE || *end || !value || value > maximum)
		return false;
	*out = value;
	return true;
}
#endif
