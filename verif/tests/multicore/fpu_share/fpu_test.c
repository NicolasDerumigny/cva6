/*
**
** Copyright 2020 OpenHW Group
**
** Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
** you may not use this file except in compliance with the License.
** You may obtain a copy of the License at
**
**     https://solderpad.org/licenses/
**
** Unless required by applicable law or agreed to in writing, software
** distributed under the License is distributed on an "AS IS" BASIS,
** WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
** See the License for the specific language governing permissions and
** limitations under the License.
**
*/

#include <stdint.h>
#include <stdio.h>

#include "util.h"

static inline uint64_t to_bits(double d) { return *(uint64_t *)&d; }

volatile int barrier_count = 0;
volatile int barrier_generation = 0;
volatile int hang_detected = 0;

#define MAX_RETRIES 1000000  // Safety limit to detect hang

void test_barrier_hang_single_core() {
  printf("=== Test 1: Simulated Barrier with Retry Limit (Single Core) ===\n");

  barrier_count = 0;
  int retries = 0;
  int sc_result;

  // This is the exact pattern from GOMP_barrier at line 10632-1063c in btdump
  asm volatile(
      "mv      s0, %3\n\t"  // s0 = &barrier_count
      "li      a4, 1\n\t"   // a4 = value to store
      "li      %0, 0\n\t"   // retries = 0

      "retry_loop:\n\t"
      "lr.w    a5, (s0)\n\t"      // Load-reserved (line 10632)
      "sc.w.aq a3, a4, (s0)\n\t"  // Store-conditional with acquire (line 10638)
      "addi    %0, %0, 1\n\t"     // retries++

      // Check if we hit max retries
      "li      t0, %4\n\t"
      "bge     %0, t0, hit_limit\n\t"

      // Check if SC succeeded
      "bnez    a3, retry_loop\n\t"  // If SC failed, retry (line 1063c)
      "j       success\n\t"

      "hit_limit:\n\t"
      "li      %1, 1\n\t"  // sc_result = FAILED
      "j       done\n\t"

      "success:\n\t"
      "li      %1, 0\n\t"  // sc_result = SUCCESS

      "done:\n\t"
      : "=r"(retries), "=r"(sc_result)
      : "m"(barrier_count), "r"(&barrier_count), "i"(MAX_RETRIES)
      : "memory");

  printf("Retries: %d, SC Result: %s, barrier_count: %d\n", retries,
         sc_result ? "FAILED" : "SUCCESS", barrier_count);

  if (retries >= MAX_RETRIES) {
    printf("✗ FAIL: Hit retry limit - HANG DETECTED!\n");
    printf(
        "This indicates SC.W is continuously failing (reservation broken)\n");
  } else {
    printf("✓ PASS: LR/SC completed in %d retries\n", retries);
  }
}

void test_barrier_with_interference() {
  printf("\n=== Test 2: Barrier with Instruction Fetch Interference ===\n");

  barrier_count = 0;
  int retries = 0;
  int sc_result;

  // Simulate Core 0 trying LR/SC while Core 1 fetches instructions
  asm volatile(
      "mv      s0, %3\n\t"
      "li      a4, 1\n\t"
      "li      %0, 0\n\t"

      "retry_loop2:\n\t"
      // Create reservation
      "lr.w    a5, (s0)\n\t"

      // Simulate Core 1 instruction fetch (breaks reservation on real hardware)
      "fence   i, i\n\t"
      "nop\n\t"
      "nop\n\t"
      "nop\n\t"

      // Try to complete SC
      "sc.w.aq a3, a4, (s0)\n\t"
      "addi    %0, %0, 1\n\t"

      "li      t0, %4\n\t"
      "bge     %0, t0, hit_limit2\n\t"

      "bnez    a3, retry_loop2\n\t"
      "j       success2\n\t"

      "hit_limit2:\n\t"
      "li      %1, 1\n\t"
      "j       done2\n\t"

      "success2:\n\t"
      "li      %1, 0\n\t"

      "done2:\n\t"
      : "=r"(retries), "=r"(sc_result)
      : "m"(barrier_count), "r"(&barrier_count), "i"(MAX_RETRIES)
      : "memory");

  printf("Retries with I-fence: %d, SC Result: %s, barrier_count: %d\n",
         retries, sc_result ? "FAILED" : "SUCCESS", barrier_count);

  if (retries >= MAX_RETRIES) {
    printf("✗ FAIL: HANG DETECTED with instruction fetch interference!\n");
    printf("This replicates the FPGA board hang condition.\n");
  } else if (retries > 100) {
    printf("⚠ WARNING: High retry count (%d) indicates reservation issues\n",
           retries);
  } else {
    printf("✓ PASS: Completed in %d retries\n", retries);
  }
}

void test_gomp_barrier_exact_pattern() {
  printf("\n=== Test 3: Exact GOMP_barrier Pattern ===\n");
  printf("This replicates the exact assembly from btdump line 10632-1063c\n");

  barrier_count = 0;
  int local_sense = 1;
  int retries = 0;

  // Exact pattern from GOMP_barrier disassembly
  asm volatile(
      "mv      s0, %2\n\t"  // s0 = &barrier_count
      "li      %0, 0\n\t"   // retries counter

      "gomp_retry:\n\t"
      // Line 10632: 100427af  lr.w a5,(s0)
      "lr.w    a5, (s0)\n\t"

      // Optionally check value (GOMP does bnez check)
      // "bnez    a5, already_set\n\t"

      // Line 10638: 18e426af  sc.w.aq a3,a4,(s0)
      "li      a4, 1\n\t"
      "sc.w.aq a3, a4, (s0)\n\t"

      // Count retries
      "addi    %0, %0, 1\n\t"

      // Check retry limit
      "li      t0, %3\n\t"
      "bge     %0, t0, gomp_limit\n\t"

      // Line 1063c: fed69ce3  bnez a3,10632
      "bnez    a3, gomp_retry\n\t"

      "j       gomp_success\n\t"

      "gomp_limit:\n\t"
      "li      a5, -1\n\t"  // Error indicator
      "j       gomp_done\n\t"

      "gomp_success:\n\t"
      "li      a5, 0\n\t"  // Success

      "gomp_done:\n\t"
      : "=r"(retries), "=r"(local_sense)
      : "r"(&barrier_count), "i"(MAX_RETRIES)
      : "memory");

  printf("GOMP pattern retries: %d, barrier_count: %d\n", retries,
         barrier_count);

  if (retries >= MAX_RETRIES) {
    printf("✗✗✗ CRITICAL: EXACT GOMP HANG REPRODUCED ✗✗✗\n");
    printf("SC.W failed %d times - infinite loop detected!\n", retries);
    printf("This is exactly what happens on the FPGA board.\n");
  } else {
    printf("Completed in %d retries (no hang)\n", retries);
  }
}

void test_dual_core_simultaneous() {
  printf("\n=== Test 4: Dual-Core Simultaneous Access ===\n");
  printf("NOTE: This test requires BOTH cores to execute simultaneously\n");
  printf("In single-core simulation, this may not replicate the hang.\n");

  barrier_count = 0;
  int core0_retries = 0, core1_retries = 0;

  // Core 0 attempts
  asm volatile(
      "mv      s0, %1\n\t"
      "li      %0, 0\n\t"
      "li      a4, 1\n\t"

      "core0_loop:\n\t"
      "lr.w    a5, (s0)\n\t"

      // Add some instructions to increase I-cache activity
      "nop\n\t"
      "nop\n\t"

      "sc.w.aq a3, a4, (s0)\n\t"
      "addi    %0, %0, 1\n\t"

      "li      t0, 1000\n\t"
      "bge     %0, t0, core0_done\n\t"

      "bnez    a3, core0_loop\n\t"
      "core0_done:\n\t"
      : "=r"(core0_retries)
      : "r"(&barrier_count)
      : "memory");

  printf("Core 0 retries: %d\n", core0_retries);
  printf("If running on dual-core hardware with both cores active,\n");
  printf("expect this to hang or have very high retry counts.\n");
}

int main(int argc, char *arg[]) {
  asm volatile(
      "li      t1, 0x6000\n\t"
      "csrw    mstatus, t1\n\t"

      "li      a0, 0\n\t"
      "li      a5, 0\n\t"

      "1:\n\t"
      "auipc   a4, %%pcrel_hi(put_f32_reg%=)\n\t"
      "add     a4, a4, a5\n\t"
      "jalr    t0, a4, %%pcrel_lo(1b)\n\t"

      "beq     zero, zero, 3f\n\t"
      "nop\n\t"

      "put_f32_reg%=:\n\t"
      "fmv.w.x ft0, a0\n\t"
      "jr      t0\n\t"

      "3:\n\t"
      :
      :
      : "memory", "t1", "a0", "a4", "a5", "t0", "ft0");

  double pi = 0.0;
  int sign = 1;

  for (long k = 0; k < 30; k++) {
    pi += sign * (1.0 / (2.0 * k + 1.0));
    sign = -sign;
  }

  pi *= 4.0;
  printf("core %d: pi: 0x%08x\n", get_hart_id(), to_bits(pi));

  test_barrier_hang_single_core();
  test_barrier_with_interference();
  test_gomp_barrier_exact_pattern();
  test_dual_core_simultaneous();

  return 0;
}
