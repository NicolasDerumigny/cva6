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

uint32_t to_bits(float f) { return *(uint32_t *)&f; }

int main(int argc, char *arg[]) {
  /* if (get_hart_id() == 0) { */
  /*   asm volatile( */
  /*       "auipc t0,0x0\n\t" */
  /*       "addi	t0,t0,144\n\t" */
  /*       "csrw	mtvec,t0\n\t" */
  /*       "fmv.w.x  ft0,zero\n\t" */
  /*       "fmv.w.x  ft1,zero\n\t" */
  /*       "fmv.w.x  ft2,zero\n\t" */
  /*       "fmv.w.x	ft3,zero\n\t" */
  /*       "fmv.w.x	ft4,zero\n\t" */
  /*       "fmv.w.x	ft5,zero\n\t" */
  /*       "fmv.w.x	ft6,zero\n\t" */
  /*       "fmv.w.x	ft7,zero\n\t" */
  /*       "fmv.w.x	fs0,zero\n\t" */
  /*       "fmv.w.x	fs1,zero\n\t" */
  /*       "fmv.w.x	fa0,zero\n\t" */
  /*       "fmv.w.x	fa1,zero\n\t" */
  /*       "fmv.w.x	fa2,zero\n\t" */
  /*       "fmv.w.x	fa3,zero\n\t" */
  /*       "fmv.w.x	fa4,zero\n\t" */
  /*       "fmv.w.x	fa5,zero\n\t" */
  /*       "fmv.w.x	fa6,zero\n\t" */
  /*       "fmv.w.x	fa7,zero\n\t" */
  /*       "fmv.w.x	fs2,zero\n\t" */
  /*       "fmv.w.x	fs3,zero\n\t" */
  /*       "fmv.w.x	fs4,zero\n\t" */
  /*       "fmv.w.x	fs5,zero\n\t" */
  /*       "fmv.w.x	fs6,zero\n\t" */
  /*       "fmv.w.x	fs7,zero\n\t" */
  /*       "fmv.w.x	fs8,zero\n\t" */
  /*       "fmv.w.x	fs9,zero\n\t" */
  /*       "fmv.w.x	fs10,zero\n\t" */
  /*       "fmv.w.x	fs11,zero\n\t" */
  /*       "fmv.w.x	ft8,zero\n\t" */
  /*       "fmv.w.x	ft9,zero\n\t" */
  /*       "fmv.w.x	ft10,zero\n\t" */
  /*       "fmv.w.x	ft11,zero\n\t" */
  /*       : */
  /*       : /\* no inputs *\/ */
  /*       : "memory", "ft0", "ft1", "ft2", "ft3", "ft4", "ft5", "ft6", "ft7",
   */
  /*         "fs0", "fs1", "fs2", "fs3", "fs4", "fs5", "fs6", "fs7", "fs8",
   * "fs9", */
  /*         "fs10", "fs11", "fa0", "fa1", "fa2", "fa3", "fa4", "fa5", "fa6", */
  /*         "fa7", "t0", "t1", "fa0", "fa1", "a0"); */
  /* } */

  /* asm volatile( */
  /*     "li      t1, 0x6000\n\t" */
  /*     "csrw    mstatus, t1\n\t" */

  /*     "li      a0, 0\n\t" */
  /*     "li      a5, 0\n\t" */

  /*     "1:\n\t" */
  /*     "auipc   a4, %%pcrel_hi(put_f32_reg%=)\n\t" */
  /*     "add     a4, a4, a5\n\t" */
  /*     "jalr    t0, a4, %%pcrel_lo(1b)\n\t" */
  /*     "j       2f\n\t" */

  /*     "put_f32_reg%=:\n\t" */
  /*     "fmv.w.x ft0, a0\n\t" */
  /*     "jr      t0\n\t" */

  /*     "2:\n\t" */
  /*     : */
  /*     : */
  /*     : "memory", "t1", "a0", "a4", "a5", "t0", "ft0"); */

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
  /* printf("pi = %.15f\n", pi); */
  /* return 0; */
  printf("core %d: pi: 0x%08x\n", get_hart_id(), to_bits(pi));
  return 0;
}
