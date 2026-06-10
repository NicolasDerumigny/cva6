#include <stdint.h>
#include <stdio.h>
/* #include <pthread.h> */

#include "util.h"

// ============================================================================
// Main Test Orchestrator
// ============================================================================
void read_input(void);
void domain(void);
void setbv(void);
void setcoeff(void);

volatile int start_barrier = 0;

int main(int argc, char *arg[]) {
  // Enable FPU in mstatus
  asm volatile(
      "li      t1, 0x6000\n\t"
      "csrw    mstatus, t1\n\t" ::
          : "t1");

  // Initialize FPU registers
  asm volatile(
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
      "3:\n\t" ::
          : "memory", "a0", "a4", "a5", "t0", "ft0");

  int core_id = get_hart_id();

  /* printf("\n"); */
  /* printf("============================================================\n");
   */
  /* printf("   SHARED FPU RESCHEDULE/INVALID STRESS TEST - Core %d\n",
   * core_id); */
  /* printf("============================================================\n");
   */
  /* printf("TEST OBJECTIVE:\n"); */
  /* printf("Stress the shared FPU reschedule/invalid mechanism by:\n"); */
  /* printf("- Core 0: Continuous ONLY fdiv.d ops (longest latency)\n"); */
  /* printf("- Core 1: Deep FPU chains + branch mispredictions\n"); */
  /* printf("\n"); */
  /* printf("EXPECTED BEHAVIOR:\n"); */
  /* printf("When Core 1 flushes, MULTIPLE Core 0 fdiv ops are in-flight:\n");
   */
  /* printf("1. All victimized simultaneously → RESCHEDULED state\n"); */
  /* printf("2. Petit scoreboard fills with RESCHEDULED entries\n"); */
  /* printf("3. High-priority arbiter replays them (LSB-first)\n"); */
  /* printf("4. All eventually complete with correct results\n"); */
  /* printf("\n"); */
  /* printf("TEST PARAMETERS:\n"); */
  /* printf("- Core 0 batches: %d (x%d ops = %d total)\n", CORE0_ITERATIONS, */
  /*        FPU_OPS_PER_BATCH, CORE0_ITERATIONS * FPU_OPS_PER_BATCH); */
  /* printf("- Core 1 flush loops: %d\n", CORE1_FLUSH_LOOPS); */
  /* printf("============================================================\n\n");
   */

  // Wait for both cores to be ready
  /* __sync_fetch_and_add((int *)&start_barrier, 1); */
  /* while (start_barrier < 2) { */
  /*   asm volatile("nop"); */
  /* } */

  // ===== RUN TEST =====
  if (core_id == 0) {
    read_input();
    printf("setcoef1\n");
    domain();
    printf("setcoef2\n");
    setcoeff();

    printf("setcoef3\n");
    // Core 0: Continuous FPU stress
    /* core0_fpu_stress(); */
  }
  /* __sync_synchronize(); */
  printf("[%d] to barrier\n", get_hart_id());
  __sync_fetch_and_add((int *)&start_barrier, 1);
  while (start_barrier < 2) {
    asm volatile("nop");
  }

  setbv();
  return 0;
}
