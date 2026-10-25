/* SPDX-License-Identifier: MIT - deterministic subprocess fixture; no GPU access. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc, char **argv) {
  (void)argc;
  if (strstr(argv[0], "validate_gemm")) {
    if (getenv("GU_TEST_VALIDATION_FAIL")) return 1;
    puts("fixture GEMM validation passed");
    return 0;
  }
  if (getenv("GU_TEST_BENCH_FAIL")) return 2;
  puts("# Fixture GPU, sm_89");
  puts("f16/f16 100.0 100.0/99.0");
  if (!getenv("GU_TEST_INCOMPLETE")) {
    puts("f16/f32 90.0 90.0/89.0");
    puts("bf16/f32 90.0 90.0/89.0");
  }
  puts("s8/s32 200.0 200.0/199.0");
  puts("dp4a 10.0 10.0/9.0");
  puts("ffma 20.0 20.0/19.0");
  return 0;
}
