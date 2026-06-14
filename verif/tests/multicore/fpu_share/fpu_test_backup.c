#include <stdint.h>
#include <stdio.h>

#include "util.h"

// ============================================================================
// SHARED FPU RESCHEDULE/INVALID STRESS TEST
// ============================================================================
#define FPU_OPS_PER_BATCH 8
#define CORE0_ITERATIONS 50
#define CORE1_FLUSH_LOOPS 100

volatile int start_barrier = 0;
volatile int core0_completed = 0;
volatile int core1_completed = 0;
volatile int errors = 0;

#define CORE0_BASE 100.0
#define CORE1_BASE 200.0

// Initialized to 0.0 to track unexecuted or prematurely killed instructions
volatile double core0_results[CORE0_ITERATIONS][FPU_OPS_PER_BATCH] = {0};
volatile double core0_expected[CORE0_ITERATIONS][FPU_OPS_PER_BATCH] = {0};

union double_to_hex {
  double d;
  uint64_t u64;
};

// ============================================================================
// FPU Helper Functions (Direct RISC-V Instructions)
// ============================================================================
static inline double fpu_sqrt(double x) {
  double result;
  asm volatile("fsqrt.d %0, %1" : "=f"(result) : "f"(x));
  return result;
}

static inline double fpu_add(double a, double b) {
  double result;
  asm volatile("fadd.d %0, %1, %2" : "=f"(result) : "f"(a), "f"(b));
  return result;
}

static inline double fpu_mul(double a, double b) {
  double result;
  asm volatile("fmul.d %0, %1, %2" : "=f"(result) : "f"(a), "f"(b));
  return result;
}

static inline double fpu_div(double a, double b) {
  double result;
  asm volatile("fdiv.d %0, %1, %2" : "=f"(result) : "f"(a), "f"(b));
  return result;
}

// ============================================================================
// Core 0: Fixed-Latency Calculation Loops
// ============================================================================
void core0_fpu_stress() {
  double base = CORE0_BASE;

  for (int iter = 0; iter < CORE0_ITERATIONS; iter++) {
    double iter_base = base + (double)iter;

    // --- Execution Pass ---
    core0_results[iter][0] =
        fpu_div(iter_base + 100.0, 4.0);                // 200.0 / 4.0 = 50.0
    core0_results[iter][1] = fpu_add(iter_base, 50.0);  // 100.0 + 50.0 = 150.0
    core0_results[iter][2] = fpu_mul(iter_base, 2.0);   // 100.0 * 2.0 = 200.0
    core0_results[iter][3] =
        fpu_div(iter_base + 300.0, 8.0);               // 400.0 / 8.0 = 50.0
    core0_results[iter][4] = fpu_mul(iter_base, 3.0);  // 100.0 * 3.0 = 300.0
    core0_results[iter][5] =
        fpu_add(iter_base, 250.0);  // 100.0 + 250.0 = 350.0
    core0_results[iter][6] =
        fpu_div(iter_base + 700.0, 16.0);              // 800.0 / 16.0 = 50.0
    core0_results[iter][7] = fpu_mul(iter_base, 4.0);  // 100.0 * 4.0 = 400.0

    // Dependent chains to force rescheduling interactions
    core0_results[iter][0] = fpu_div(core0_results[iter][7], 2.0);
    core0_results[iter][1] = fpu_add(core0_results[iter][6], 10.0);
    core0_results[iter][2] = fpu_mul(core0_results[iter][5], 2.0);
    core0_results[iter][3] = fpu_div(core0_results[iter][4], 3.0);
    core0_results[iter][4] = fpu_mul(core0_results[iter][3], 5.0);
    core0_results[iter][5] = fpu_add(core0_results[iter][2], 100.0);
    core0_results[iter][6] = fpu_div(core0_results[iter][1], 2.0);
    core0_results[iter][7] = fpu_add(core0_results[iter][0], 1.0);

    // --- Mathematical Gold Standard Copy ---
    core0_expected[iter][0] = fpu_div(iter_base + 100.0, 4.0);
    core0_expected[iter][1] = fpu_add(iter_base, 50.0);
    core0_expected[iter][2] = fpu_mul(iter_base, 2.0);
    core0_expected[iter][3] = fpu_div(iter_base + 300.0, 8.0);
    core0_expected[iter][4] = fpu_mul(iter_base, 3.0);
    core0_expected[iter][5] = fpu_add(iter_base, 250.0);
    core0_expected[iter][6] = fpu_div(iter_base + 700.0, 16.0);
    core0_expected[iter][7] = fpu_mul(iter_base, 4.0);

    core0_expected[iter][0] = fpu_div(core0_expected[iter][7], 2.0);
    core0_expected[iter][1] = fpu_add(core0_expected[iter][6], 10.0);
    core0_expected[iter][2] = fpu_mul(core0_expected[iter][5], 2.0);
    core0_expected[iter][3] = fpu_div(core0_expected[iter][4], 3.0);
    core0_expected[iter][4] = fpu_mul(core0_expected[iter][3], 5.0);
    core0_expected[iter][5] = fpu_add(core0_expected[iter][2], 100.0);
    core0_expected[iter][6] = fpu_div(core0_expected[iter][1], 2.0);
    core0_expected[iter][7] = fpu_add(core0_expected[iter][0], 1.0);
  }

  core0_completed = 1;
}

// ============================================================================
// Core 1: Pipeline Flush Engine
// ============================================================================
void core1_flush_generator() {
  double ft0 = CORE1_BASE;  // 200.0
  double ft1 = 2.5;
  double ft2, ft3;
  int toggle = 0;

  for (int i = 0; i < CORE1_FLUSH_LOOPS; i++) {
    ft2 = fpu_div(ft0, ft1);         // 200.0 / 2.5 = 80.0
    ft3 = fpu_div(ft2, 1.5);         // 80.0 / 1.5 = 53.333333333333336
    double ft4 = fpu_div(ft3, 2.0);  // 53.3333 / 2 = 26.666666666666668
    double ft5 = fpu_add(ft4, ft0);  // 26.6666 + 200.0 = 226.66666666666666
    double ft6 = fpu_add(ft5, ft0);
    double ft7 = fpu_mul(ft6, ft0);
    double ft8 = fpu_add(ft7, ft0);
    double ft9 = fpu_sqrt(ft8);
    double ft10 = fpu_sqrt(ft9);

    int branch_taken = toggle & 1;
    toggle++;

    // Alternating branch pattern to force execution mispredicts and pipeline
    // flushes
    if (branch_taken == 0) {
      asm volatile("nop");
    } else {
      asm volatile("nop");
    }

    ft0 = ft5;
    ft1 = ft6;
  }

  core1_completed = 1;
}

// ============================================================================
// Mathematical Bit-Perfect Verification Function
// ============================================================================
void verify_core0_results() {
  printf("\n[Core 0] Verifying results...\n");

  int local_errors = 0;
  int swapped_results = 0;
  int killed_operations = 0;

  // Exact Signature Bitmasks of speculative Core 1 intermediate calculations
  uint64_t c1_sign_ft2 = 0x4054000000000000ULL;  // 80.0
  uint64_t c1_sign_ft3 = 0x404aa66666666666ULL;  // 53.33333...
  uint64_t c1_sign_ft4 = 0x403aa66666666666ULL;  // 26.66666...
  uint64_t c1_sign_ft5 = 0x406c555555555555ULL;  // 226.66666...

  for (int iter = 0; iter < CORE0_ITERATIONS; iter++) {
    for (int op = 0; op < FPU_OPS_PER_BATCH; op++) {
      union double_to_hex res_hex = {.d = core0_results[iter][op]};
      union double_to_hex exp_hex = {.d = core0_expected[iter][op]};

      // Bit-perfect comparison logic safely bypasses float printing omissions
      if (res_hex.u64 != exp_hex.u64) {
        local_errors++;

        printf(
            "[Core 0] ERROR: Iter %d, Op %d - Expected 0x%016llx, Got "
            "0x%016llx\n",
            iter, op, (unsigned long long)exp_hex.u64,
            (unsigned long long)res_hex.u64);

        // Test Type A: Operation Completely Dropped / Killed by External Flush
        if (res_hex.u64 == 0) {
          killed_operations++;
          printf(
              "[Core 0] *** KILLED OPERATION DETECTED *** (Core 0 writeback "
              "skipped!)\n");
        }
        // Test Type B: Scoreboard Cross-Routing / Data Leakage Hazard
        else if (res_hex.u64 == c1_sign_ft2 || res_hex.u64 == c1_sign_ft3 ||
                 res_hex.u64 == c1_sign_ft4 || res_hex.u64 == c1_sign_ft5) {
          swapped_results++;
          printf(
              "[Core 0] *** TRUE RESULT SWAP DETECTED *** (Snooped Core 1 "
              "speculation register!)\n");
        }
      }
    }
  }

  printf("\n============================================================\n");
  printf("   DIAGNOSTIC SUMMARY\n");
  printf("============================================================\n");
  printf("Total Mathematical Deviations  : %d\n", local_errors);
  printf("Confirmed Inter-Hart Swaps     : %d\n", swapped_results);
  printf("Confirmed Flush-Killed Ops     : %d\n", killed_operations);

  if (local_errors == 0) {
    printf("\nHARDWARE VERIFIED: 100%% OPERATIONAL\n");
  } else {
    printf("\n✗✗✗ SILICON HAZARD OR SCOREBOARD BUG DETECTED ✗✗✗\n");
  }
  printf("============================================================\n");

  errors += local_errors;
}

// ============================================================================
// Main Entry Point
// ============================================================================
int main(int argc, char *arg[]) {
  // Enable Floating Point Unit
  asm volatile(
      "li      t1, 0x6000\n\t"
      "csrw    mstatus, t1\n\t" ::
          : "t1");

  int core_id = get_hart_id();

  // Multi-hart barrier synchronization
  __sync_fetch_and_add((int *)&start_barrier, 1);
  while (start_barrier < 2) {
    asm volatile("nop");
  }

  if (core_id == 0) {
    core0_fpu_stress();
  } else {
    core1_flush_generator();
  }

  __sync_synchronize();
  while (!core0_completed || !core1_completed) {
    asm volatile("nop");
  }

  if (core_id == 0) {
    verify_core0_results();
  }

  return 0;
}
