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
/* #include <pthread.h> */

#include "util.h"
#include "applu.h"
#define FPU_OPS_PER_BATCH 8    // Match CVA6 TRANS_ID_BITS
#define CORE0_ITERATIONS 25    // ~200 long FPU ops total
#define CORE1_FLUSH_LOOPS 100  // Each loop causes branch mispredictions

// Synchronization and result tracking
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


void read_input(void) {
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

void domain(void) {
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

void setcoeff(void) {
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

void setbv(void) {
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

    printf("[%d] starting setbv\n", get_hart_id());
    /* printf("%d\n", nx); */
    /* printf("[%d]\n", get_hart_id()); */

    for (i = 0; i<nx; i++) {
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
}
