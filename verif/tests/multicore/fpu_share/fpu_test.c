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
#include "applu.h"
#define FPU_OPS_PER_BATCH 8    // Match CVA6 TRANS_ID_BITS
#define CORE0_ITERATIONS 25    // ~200 long FPU ops total
#define CORE1_FLUSH_LOOPS 100  // Each loop causes branch mispredictions

// Synchronization and result tracking
volatile int start_barrier = 0;
volatile int core0_completed = 0;
volatile int core1_completed = 0;
volatile int errors = 0;

// Core 0 results storage (use different values to detect routing errors)
#define CORE0_BASE 100.0
#define CORE1_BASE 200.0
#define max(a, b) ((a > b) ? (a) : (b))

volatile double core0_results[CORE0_ITERATIONS][FPU_OPS_PER_BATCH];
volatile double core0_expected[CORE0_ITERATIONS][FPU_OPS_PER_BATCH];

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

static inline double fpu_sub(double a, double b) {
  double result;
  asm volatile("fsub.d %0, %1, %2" : "=f"(result) : "f"(a), "f"(b));
  return result;
}

static void exact(int i, int j, int k, double u000ijk[5]) {
  /*--------------------------------------------------------------------
  c
  c   compute the exact solution at (i,j,k)
  c
  --------------------------------------------------------------------*/

  /*--------------------------------------------------------------------
  c  local variables
  --------------------------------------------------------------------*/
  int m;
  double xi, eta, zeta;

  xi = ((double)i) / (nx0 - 1);
  eta = ((double)j) / (ny0 - 1);
  zeta = ((double)k) / (nz - 1);

  for (m = 0; m < 5; m++) {
    u000ijk[m] = ce[m][0] + ce[m][1] * xi + ce[m][2] * eta + ce[m][3] * zeta +
                 ce[m][4] * xi * xi + ce[m][5] * eta * eta +
                 ce[m][6] * zeta * zeta + ce[m][7] * xi * xi * xi +
                 ce[m][8] * eta * eta * eta + ce[m][9] * zeta * zeta * zeta +
                 ce[m][10] * xi * xi * xi * xi +
                 ce[m][11] * eta * eta * eta * eta +
                 ce[m][12] * zeta * zeta * zeta * zeta;
  }
}

// ============================================================================
// Core 0: Continuous Back-to-Back Long-Latency FPU Operations
// ============================================================================
// This function continuously issues ONLY fdiv.d operations (longest latency)
// in batches to maximize FPU pipeline occupancy. Using only divisions ensures
// that multiple operations are in-flight simultaneously when Core 1 flushes.
//
// With fdiv taking 54-81 cycles, issuing 8 back-to-back creates a situation
// where multiple divides are active in the FPU. When Core 1 flushes, several
// Core 0 operations get victimized simultaneously, filling the petit scoreboard
// with RESCHEDULED entries and testing the reschedule mechanism under load.
void core0_fpu_stress() {
  printf("[Core 0] Starting continuous FPU operations...\n");
  printf("[Core 0] Will issue %d batches of %d long-latency ops\n",
         CORE0_ITERATIONS, FPU_OPS_PER_BATCH);

  double base = CORE0_BASE;

  for (int iter = 0; iter < CORE0_ITERATIONS; iter++) {
    // Vary base slightly per iteration to make results unique
    double iter_base = base + (double)iter;

    // Issue a batch of 8 ONLY fdiv.d operations (longest latency ~54-81 cycles)
    // Using ONLY divisions maximizes time in FPU pipeline, ensuring multiple
    // operations are in-flight when Core 1 flushes. This creates maximum
    // RESCHEDULED entries in the petit scoreboard.
    //
    // Strategy: All 8 divisions issued back-to-back will spend 54-81 cycles
    // EACH in the FPU. With frequent flushes from Core 1, multiple divides
    // will be victimized simultaneously, filling the scoreboard with
    // RESCHEDULED transactions.
    core0_results[iter][0] = fpu_div(iter_base + 100.0, 3.7);   // ~54-81 cycles
    core0_results[iter][1] = fpu_add(iter_base + 150.0, 4.3);   // ~54-81 cycles
    core0_results[iter][2] = fpu_mul(iter_base + 200.0, 5.1);   // ~54-81 cycles
    core0_results[iter][3] = fpu_div(iter_base + 250.0, 6.7);   // ~54-81 cycles
    core0_results[iter][4] = fpu_mul(iter_base + 300.0, 7.3);   // ~54-81 cycles
    core0_results[iter][5] = fpu_add(iter_base + 350.0, 8.3);   // ~54-81 cycles
    core0_results[iter][6] = fpu_div(iter_base + 400.0, 9.1);   // ~54-81 cycles
    core0_results[iter][7] = fpu_mul(iter_base + 450.0, 10.7);  // ~54-81 cycles
    core0_results[iter][0] =
        fpu_div(iter_base + 100.0, core0_results[iter][7]);  // ~54-81 cycles
    core0_results[iter][1] =
        fpu_add(iter_base + 150.0, core0_results[iter][6]);  // ~54-81 cycles
    core0_results[iter][2] =
        fpu_mul(iter_base + 200.0, core0_results[iter][5]);  // ~54-81 cycles
    core0_results[iter][3] =
        fpu_div(iter_base + 250.0, core0_results[iter][4]);  // ~54-81 cycles
    core0_results[iter][4] =
        fpu_mul(iter_base + 300.0, core0_results[iter][3]);  // ~54-81 cycles
    core0_results[iter][5] =
        fpu_add(iter_base + 350.0, core0_results[iter][2]);  // ~54-81 cycles
    core0_results[iter][6] =
        fpu_div(iter_base + 400.0, core0_results[iter][1]);  // ~54-81 cycles
    core0_results[iter][7] =
        fpu_mul(iter_base + 450.0, core0_results[iter][0]);  // ~54-81 cycles

    // Calculate expected values (without reschedules, just correct FPU results)
    core0_expected[iter][0] = fpu_div(iter_base + 100.0, 3.7);
    core0_expected[iter][1] = fpu_mul(iter_base + 150.0, 4.3);
    core0_expected[iter][2] = fpu_add(iter_base + 200.0, 5.1);
    core0_expected[iter][3] = fpu_add(iter_base + 250.0, 6.7);
    core0_expected[iter][4] = fpu_div(iter_base + 300.0, 7.9);
    core0_expected[iter][5] = fpu_mul(iter_base + 350.0, 8.3);
    core0_expected[iter][6] = fpu_div(iter_base + 400.0, 9.1);
    core0_expected[iter][7] = fpu_add(iter_base + 450.0, 10.7);

    core0_expected[iter][0] =
        fpu_div(iter_base + 100.0, core0_expected[iter][7]);
    core0_expected[iter][1] =
        fpu_mul(iter_base + 150.0, core0_expected[iter][6]);
    core0_expected[iter][2] =
        fpu_add(iter_base + 200.0, core0_expected[iter][5]);
    core0_expected[iter][3] =
        fpu_add(iter_base + 250.0, core0_expected[iter][4]);
    core0_expected[iter][4] =
        fpu_div(iter_base + 300.0, core0_expected[iter][3]);
    core0_expected[iter][5] =
        fpu_mul(iter_base + 350.0, core0_expected[iter][2]);
    core0_expected[iter][6] =
        fpu_div(iter_base + 400.0, core0_expected[iter][1]);
    core0_expected[iter][7] =
        fpu_add(iter_base + 450.0, core0_expected[iter][0]);

    // Progress reporting every 10 iterations
    if ((iter + 1) % 10 == 0) {
      printf("[Core 0] Completed %d/%d batches\n", iter + 1, CORE0_ITERATIONS);
    }
  }

  printf("[Core 0] All FPU operations completed!\n");
  core0_completed = 1;
}

// ============================================================================
// Core 1: Branch Misprediction Generator (Flush Producer)
// ============================================================================
// This function executes loops with deep FPU operation chains followed by
// alternating branches that cause frequent branch mispredictions.
//
// Each iteration creates a chain of 3 dependent fdiv operations before the
// branch. This deep chain (3 × 54-81 cycles = 162-243 cycles) gives Core 0
// ample time to issue multiple operations that will be in-flight when the
// flush occurs.
//
// The pattern creates:
// 1. fdiv → fdiv → fdiv → fadd chain (enters and fills pipeline)
// 2. Branch that alternates every iteration (hard to predict)
// 3. Flush on misprediction (kills Core 1's chain)
// 4. Also victimizes MULTIPLE Core 0 ISSUED transactions (→ RESCHEDULED)
// 5. Petit scoreboard fills with RESCHEDULED entries
void core1_flush_generator() {
  printf(
      "[Core 1] Starting flush generator (branch misprediction pattern)...\n");
  printf("[Core 1] Will execute %d flush-inducing loops\n", CORE1_FLUSH_LOOPS);

  // Initialize FPU registers with non-zero values
  double ft0 = CORE1_BASE;
  double ft1 = 2.5;
  double ft2, ft3;
  int toggle = 0;
  int branch_taken;

  for (int i = 0; i < CORE1_FLUSH_LOOPS; i++) {
    // Issue multiple long-latency FPU operations to create a deep pipeline
    // This gives Core 0 time to issue multiple operations that will be
    // in-flight when the flush occurs, maximizing RESCHEDULED entries
    ft2 = fpu_div(ft0, ft1);         // Heavy multi-cycle FPU op (54-81 cycles)
    ft3 = fpu_div(ft2, 1.5);         // Another long div (dependent chain)
    double ft4 = fpu_div(ft3, 2.0);  // Third div extends the chain
    double ft5 = fpu_add(ft4, ft0);  // Final add
    double ft6 = fpu_add(ft5, ft0);  // Final add
    double ft7 = fpu_mul(ft6, ft0);  // Final add
    double ft8 = fpu_add(ft7, ft0);  // Final add
    double ft9 = fpu_sqrt(ft8);      // Final add
    double ft10 = fpu_sqrt(ft9);     // Final add

    // Create hard-to-predict branch that alternates every iteration
    // This pattern causes maximum branch mispredictions
    branch_taken = toggle & 1;
    toggle++;

    // The branch predictor will routinely mispredict this alternating pattern
    // Misprediction causes flush, killing Core 1's multi-div chain AND
    // victimizing multiple Core 0 operations that are now in-flight
    if (branch_taken == 0) {
      // Branch taken path
      asm volatile("nop");
    } else {
      // Branch not taken path
      asm volatile("nop");
    }

    // Use results to prevent compiler optimization
    ft0 = ft5;
    ft1 = ft6;
    ft2 = ft7;
    ft3 = ft8;
    ft4 = ft9;
    ft5 = ft10;

    // Progress reporting every 50 loops
    if ((i + 1) % 50 == 0) {
      ft0 += fpu_add(ft5, ft6);
      ft1 += fpu_add(ft6, ft7);
      ft2 += fpu_add(ft7, ft8);
      ft3 += fpu_add(ft8, ft9);
      ft4 += fpu_add(ft9, ft10);
      ft5 += fpu_add(ft10, ft5);
      printf("[Core 1] Completed %d/%d flush loops\n", i + 1,
             CORE1_FLUSH_LOOPS);
    }
  }

  printf("[Core 1] Flush generator completed!\n");
  core1_completed = 1;
}

// ============================================================================
// Result Verification
// ============================================================================
// Verify that Core 0's results are correct despite being rescheduled multiple
// times
void verify_core0_results() {
  printf("\n[Core 0] Verifying results...\n");

  int local_errors = 0;
  int swapped_results = 0;

  for (int iter = 0; iter < CORE0_ITERATIONS; iter++) {
    for (int op = 0; op < FPU_OPS_PER_BATCH; op++) {
      double result = core0_results[iter][op];
      double expect = core0_expected[iter][op];
      double diff = result - expect;
      if (diff < 0) diff = -diff;

      // Check for match within floating-point tolerance
      if (diff > 0.001) {
        printf(
            "[Core 0] ERROR: Iter %d, Op %d - Expected %.6f, Got %.6f "
            "(diff=%.6f)\n",
            iter, op, expect, result, diff);
        local_errors++;

        // Check if result looks like it came from Core 1 (routing error)
        if (result >= 180.0) {
          swapped_results++;
          printf(
              "[Core 0] *** RESULT SWAP DETECTED *** (Got Core 1 result!)\n");
        }
      }
    }
  }

  if (swapped_results > 0) {
    printf("[Core 0] ✗✗✗ %d RESULT SWAPS DETECTED ✗✗✗\n", swapped_results);
    printf("[Core 0] Results routed to wrong core!\n");
    errors += swapped_results;
  }

  if (local_errors == 0) {
    printf("[Core 0] ✓ All %d operations completed correctly!\n",
           CORE0_ITERATIONS * FPU_OPS_PER_BATCH);
    printf("[Core 0] Reschedule mechanism working correctly!\n");
  } else {
    printf("[Core 0] ✗ %d errors detected\n", local_errors);
  }

  errors += local_errors;
}

static void read_input(void) {
  FILE *fp;

  /*--------------------------------------------------------------------
  c    if input file does not exist, it uses defaults
  c       ipr = 1 for detailed progress output
  c       inorm = how often the norm is printed (once every inorm iterations)
  c       itmax = number of pseudo time steps
  c       dt = time step
  c       omega 1 over-relaxation factor for SSOR
  c       tolrsd = steady state residual tolerance levels
  c       nx, ny, nz = number of grid points in x, y, z directions
  --------------------------------------------------------------------*/

  printf(
      "\n\n NAS Parallel Benchmarks 3.0 structured OpenMP C version"
      " - LU Benchmark\n\n");

  /* fp = fopen("inputlu.data", "r"); */
  /* else { */
  ipr = IPR_DEFAULT;
  inorm = INORM_DEFAULT;
  itmax = ITMAX_DEFAULT;
  dt = DT_DEFAULT;
  omega = OMEGA_DEFAULT;
  tolrsd[0] = TOLRSD1_DEF;
  tolrsd[1] = TOLRSD2_DEF;
  tolrsd[2] = TOLRSD3_DEF;
  tolrsd[3] = TOLRSD4_DEF;
  tolrsd[4] = TOLRSD5_DEF;
  nx0 = ISIZ1;
  ny0 = ISIZ2;
  nz0 = ISIZ3;
  /* } */
}

static void domain(void) {
  /*--------------------------------------------------------------------
  c  local variables
  --------------------------------------------------------------------*/

  nx = nx0;
  ny = ny0;
  nz = nz0;

  /*--------------------------------------------------------------------
  c   check the sub-domain size
  --------------------------------------------------------------------*/
  if (nx < 4 || ny < 4 || nz < 4) {
    printf(
        "     SUBDOMAIN SIZE IS TOO SMALL - \n"
        "     ADJUST PROBLEM SIZE OR NUMBER OF PROCESSORS\n"
        "     SO THAT NX, NY AND NZ ARE GREATER THAN OR EQUAL\n"
        "     TO 4 THEY ARE CURRENTLY%3d%3d%3d\n",
        nx, ny, nz);
    exit(1);
  }

  if (nx > ISIZ1 || ny > ISIZ2 || nz > ISIZ3) {
    printf(
        "     SUBDOMAIN SIZE IS TOO LARGE - \n"
        "     ADJUST PROBLEM SIZE OR NUMBER OF PROCESSORS\n"
        "     SO THAT NX, NY AND NZ ARE LESS THAN OR EQUAL TO \n"
        "     ISIZ1, ISIZ2 AND ISIZ3 RESPECTIVELY.  THEY ARE\n"
        "     CURRENTLY%4d%4d%4d\n",
        nx, ny, nz);
    exit(1);
  }

  /*--------------------------------------------------------------------
  c   set up the start and end in i and j extents for all processors
  --------------------------------------------------------------------*/
  ist = 1;
  iend = nx - 2;

  jst = 1;
  jend = ny - 2;
}

static void setcoeff(void) {
  /*--------------------------------------------------------------------
  c   set up coefficients
  --------------------------------------------------------------------*/
  dxi = 1.0 / (nx0 - 1);
  deta = 1.0 / (ny0 - 1);
  dzeta = 1.0 / (nz0 - 1);

  tx1 = 1.0 / (dxi * dxi);
  tx2 = 1.0 / (2.0 * dxi);
  tx3 = 1.0 / dxi;

  ty1 = 1.0 / (deta * deta);
  ty2 = 1.0 / (2.0 * deta);
  ty3 = 1.0 / deta;

  tz1 = 1.0 / (dzeta * dzeta);
  tz2 = 1.0 / (2.0 * dzeta);
  tz3 = 1.0 / dzeta;

  ii1 = 1;
  ii2 = nx0 - 2;
  ji1 = 1;
  ji2 = ny0 - 3;
  ki1 = 2;
  ki2 = nz0 - 2;

  /*--------------------------------------------------------------------
  c   diffusion coefficients
  --------------------------------------------------------------------*/
  dx1 = 0.75;
  dx2 = dx1;
  dx3 = dx1;
  dx4 = dx1;
  dx5 = dx1;

  dy1 = 0.75;
  dy2 = dy1;
  dy3 = dy1;
  dy4 = dy1;
  dy5 = dy1;

  dz1 = 1.00;
  dz2 = dz1;
  dz3 = dz1;
  dz4 = dz1;
  dz5 = dz1;

  /*--------------------------------------------------------------------
  c   fourth difference dissipation
  --------------------------------------------------------------------*/
  dssp = (max(dx1, max(dy1, dz1))) / 4.0;

  /*--------------------------------------------------------------------
  c   coefficients of the exact solution to the first pde
  --------------------------------------------------------------------*/
  ce[0][0] = 2.0;
  ce[0][1] = 0.0;
  ce[0][2] = 0.0;
  ce[0][3] = 4.0;
  ce[0][4] = 5.0;
  ce[0][5] = 3.0;
  ce[0][6] = 5.0e-01;
  ce[0][7] = 2.0e-02;
  ce[0][8] = 1.0e-02;
  ce[0][9] = 3.0e-02;
  ce[0][10] = 5.0e-01;
  ce[0][11] = 4.0e-01;
  ce[0][12] = 3.0e-01;

  /*--------------------------------------------------------------------
  c   coefficients of the exact solution to the second pde
  --------------------------------------------------------------------*/
  ce[1][0] = 1.0;
  ce[1][1] = 0.0;
  ce[1][2] = 0.0;
  ce[1][3] = 0.0;
  ce[1][4] = 1.0;
  ce[1][5] = 2.0;
  ce[1][6] = 3.0;
  ce[1][7] = 1.0e-02;
  ce[1][8] = 3.0e-02;
  ce[1][9] = 2.0e-02;
  ce[1][10] = 4.0e-01;
  ce[1][11] = 3.0e-01;
  ce[1][12] = 5.0e-01;

  /*--------------------------------------------------------------------
  c   coefficients of the exact solution to the third pde
  --------------------------------------------------------------------*/
  ce[2][0] = 2.0;
  ce[2][1] = 2.0;
  ce[2][2] = 0.0;
  ce[2][3] = 0.0;
  ce[2][4] = 0.0;
  ce[2][5] = 2.0;
  ce[2][6] = 3.0;
  ce[2][7] = 4.0e-02;
  ce[2][8] = 3.0e-02;
  ce[2][9] = 5.0e-02;
  ce[2][10] = 3.0e-01;
  ce[2][11] = 5.0e-01;
  ce[2][12] = 4.0e-01;

  /*--------------------------------------------------------------------
  c   coefficients of the exact solution to the fourth pde
  --------------------------------------------------------------------*/
  ce[3][0] = 2.0;
  ce[3][1] = 2.0;
  ce[3][2] = 0.0;
  ce[3][3] = 0.0;
  ce[3][4] = 0.0;
  ce[3][5] = 2.0;
  ce[3][6] = 3.0;
  ce[3][7] = 3.0e-02;
  ce[3][8] = 5.0e-02;
  ce[3][9] = 4.0e-02;
  ce[3][10] = 2.0e-01;
  ce[3][11] = 1.0e-01;
  ce[3][12] = 3.0e-01;

  /*--------------------------------------------------------------------
  c   coefficients of the exact solution to the fifth pde
  --------------------------------------------------------------------*/
  ce[4][0] = 5.0;
  ce[4][1] = 4.0;
  ce[4][2] = 3.0;
  ce[4][3] = 2.0;
  ce[4][4] = 1.0e-01;
  ce[4][5] = 4.0e-01;
  ce[4][6] = 3.0e-01;
  ce[4][7] = 5.0e-02;
  ce[4][8] = 4.0e-02;
  ce[4][9] = 3.0e-02;
  ce[4][10] = 1.0e-01;
  ce[4][11] = 3.0e-01;
  ce[4][12] = 2.0e-01;
}

static void setbv(void) {
  /* #pragma omp parallel */
  {
    /*--------------------------------------------------------------------
    c   set the boundary values of dependent variables
    --------------------------------------------------------------------*/

    /*--------------------------------------------------------------------
    c   local variables
    --------------------------------------------------------------------*/
    int i, j, k;
    int iglob, jglob;

    /*--------------------------------------------------------------------
    c   set the dependent variable values along the top and bottom faces
    --------------------------------------------------------------------*/
    /* #pragma omp for */

    printf("[%d] %d\n", get_hart_id(), nx * get_hart_id() / 2);
    printf("[%d] %d\n", get_hart_id(), ((nx * (1 + get_hart_id()) / 2)));
    /* printf("%d\n", nx); */
    /* printf("[%d]\n", get_hart_id()); */

    for (i = nx * get_hart_id() / 2; i < ((nx * (1 + get_hart_id()) / 2));
         i++) {
      iglob = i;
      for (j = 0; j < ny; j++) {
        jglob = j;
        exact(iglob, jglob, 0, &u[i][j][0][0]);
        exact(iglob, jglob, nz - 1, &u[i][j][nz - 1][0]);
        /* printf("%d\n", i); */
        /* exit(0); */
      }
      /* exit(0); */
    }

    return;
    /*--------------------------------------------------------------------
    c   set the dependent variable values along north and south faces
    --------------------------------------------------------------------*/
    /* #pragma omp for */
    for (i = 0; i < nx; i++) {
      iglob = i;
      for (k = 0; k < nz; k++) {
        exact(iglob, 0, k, &u[i][0][k][0]);
      }
    }

    /* #pragma omp for */
    for (i = 0; i < nx; i++) {
      iglob = i;
      for (k = 0; k < nz; k++) {
        exact(iglob, ny0 - 1, k, &u[i][ny - 1][k][0]);
      }
    }

    /*--------------------------------------------------------------------
    c   set the dependent variable values along east and west faces
    --------------------------------------------------------------------*/
    /* #pragma omp for */
    for (j = 0; j < ny; j++) {
      jglob = j;
      for (k = 0; k < nz; k++) {
        exact(0, jglob, k, &u[0][j][k][0]);
      }
    }

    /* #pragma omp for */
    for (j = 0; j < ny; j++) {
      jglob = j;
      for (k = 0; k < nz; k++) {
        exact(nx0 - 1, jglob, k, &u[nx - 1][j][k][0]);
      }
    }
  }
}

// ============================================================================
// Main Test Orchestrator
// ============================================================================
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
  __sync_fetch_and_add((int *)&start_barrier, 1);
  while (start_barrier < 2) {
    asm volatile("nop");
  }

  setbv();

  // Wait for both cores to complete
  /* __sync_synchronize(); */
  /* while (!core0_completed || !core1_completed) { */
  /*   asm volatile("nop"); */
  /* } */

  // ===== VERIFICATION =====
  /* if (core_id == 0) { */
  /*   verify_core0_results(); */

  /*   printf("\n"); */
  /*   printf("============================================================\n");
   */
  /*   printf("   FINAL TEST SUMMARY\n"); */
  /*   printf("============================================================\n");
   */
  /*   printf("Core 0: Issued %d FPU operations\n", */
  /*          CORE0_ITERATIONS * FPU_OPS_PER_BATCH); */
  /*   printf("Core 1: Executed %d flush-inducing loops\n", CORE1_FLUSH_LOOPS);
   */
  /*   printf("Total errors: %d\n", errors); */

  /*   if (errors == 0) { */
  /*     printf("\n✓✓✓ TEST PASSED ✓✓✓\n"); */
  /*     printf("Reschedule/invalid mechanism working correctly!\n"); */
  /*     printf("- Multiple Core 0 ops successfully rescheduled after
   * flushes\n"); */
  /*     printf("- Scoreboard handled many simultaneous RESCHEDULED entries\n");
   */
  /*     printf("- High-priority replay path functioning under load\n"); */
  /*     printf("- Results correctly routed despite multiple reschedules\n"); */
  /*     printf("============================================================\n");
   */
  /*     return 0; */
  /*   } else { */
  /*     printf("\n✗✗✗ TEST FAILED ✗✗✗\n"); */
  /*     printf("Reschedule/invalid mechanism has bugs!\n"); */
  /*     printf("Possible causes:\n"); */
  /*     printf("- RESCHEDULED entries not immune to subsequent flushes\n"); */
  /*     printf("- Scoreboard can't handle multiple simultaneous
   * reschedules\n"); */
  /*     printf("- High-priority replay arbiter not working under load\n"); */
  /*     printf("- Result routing errors through reschedule path\n"); */
  /*     printf("- Transaction ID corruption during reschedule\n"); */
  /*     printf("============================================================\n");
   */
  /*     return 1; */
  /*   } */
  /* } */

  return 0;
}
