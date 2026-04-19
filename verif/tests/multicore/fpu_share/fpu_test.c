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
  volatile float op1 = 1.0f;
  volatile float op2 = 3.0f;

  float res_before, res_after;
  uint32_t fcsr_before, fcsr_after;
  float inline_result;
  // 1. SET STATE: Set Rounding Mode to 'Round towards Zero' (RTZ = 1)
  // Using 'fsrmi' for the immediate value 1
  res_before = op1 / op2;
  asm volatile("fsrmi x0, 1");

  res_before = op1 / op2;
  /* // Read the full FCSR to see the Inexact flag (bit 0) and Rounding Mode */
  asm volatile("frcsr %0" : "=r"(fcsr_before));
  asm volatile(
      "auipc t0,0x0\n\t"
      "addi	t0,t0,144\n\t"
      "csrw	mtvec,t0\n\t"
      "fscsr zero\n\t"
      "fmv.w.x  ft0,zero\n\t"
      "fmv.w.x  ft1,zero\n\t"
      "fmv.w.x  ft2,zero\n\t"

      "lui t0, 0x3f800\n\t"  // Load upper 20 bits of 1.0f into integer reg t0
      "fmv.w.x fa0, t0\n\t"  // Move bit pattern from t0 to float reg fa0

      // Load 3.0f (0x40400000)
      "lui t1, 0x40400\n\t"  // Load upper 20 bits of 3.0f into integer reg t1
      "fmv.w.x fa1, t1\n\t"  // Move bit pattern from t1 to float reg fa1

      // Perform the division
      "fdiv.s %0, fa0, fa1\n\t"

      "fmv.w.x	ft3,zero\n\t"
      "fmv.w.x	ft4,zero\n\t"
      "fmv.w.x	ft5,zero\n\t"
      "fmv.w.x	ft6,zero\n\t"
      "fmv.w.x	ft7,zero\n\t"
      "fmv.w.x	fs0,zero\n\t"
      "fmv.w.x	fs1,zero\n\t"
      "fmv.w.x	fa0,zero\n\t"
      "fmv.w.x	fa1,zero\n\t"
      "fmv.w.x	fa2,zero\n\t"
      "fmv.w.x	fa3,zero\n\t"
      "fmv.w.x	fa4,zero\n\t"
      "fmv.w.x	fa5,zero\n\t"
      "fmv.w.x	fa6,zero\n\t"
      "fmv.w.x	fa7,zero\n\t"
      "fmv.w.x	fs2,zero\n\t"
      "fmv.w.x	fs3,zero\n\t"
      "fmv.w.x	fs4,zero\n\t"
      "fmv.w.x	fs5,zero\n\t"
      "fmv.w.x	fs6,zero\n\t"
      "fmv.w.x	fs7,zero\n\t"
      "fmv.w.x	fs8,zero\n\t"
      "fmv.w.x	fs9,zero\n\t"
      "fmv.w.x	fs10,zero\n\t"
      "fmv.w.x	fs11,zero\n\t"
      "fmv.w.x	ft8,zero\n\t"
      "fmv.w.x	ft9,zero\n\t"
      "fmv.w.x	ft10,zero\n\t"
      "fmv.w.x	ft11,zero\n\t"
      : "=f"(inline_result)
      : /* no inputs */
      : "memory", "ft0", "ft1", "ft2", "ft3", "ft4", "ft5", "ft6", "ft7", "fs0",
        "fs1", "fs2", "fs3", "fs4", "fs5", "fs6", "fs7", "fs8", "fs9", "fs10",
        "fs11", "fa0", "fa1", "fa2", "fa3", "fa4", "fa5", "fa6", "fa7", "t0",
        "t1", "fa0", "fa1");
  /* // 3. PERFORM MATH AGAIN */
  // After reset, Rounding Mode is back to RNE (0)
  res_after = op1 / op2;
  asm volatile("frcsr %0" : "=r"(fcsr_after));

  // 4. HEX OUTPUT
  uint32_t b_bits = to_bits(res_before);
  uint32_t a_bits = to_bits(res_after);

  // Note: get_hart_id() is a placeholder, use your actual hart-id function
  printf("core %d: FCSR Before: 0x%08x | Result: 0x%08x\n", get_hart_id(),
         fcsr_before, b_bits);
  printf("core %d: FCSR After:  0x%08x | Result: 0x%08x\n", get_hart_id(),
         fcsr_after, a_bits);

  if (b_bits != a_bits) {
    printf("core %d: IMPACT CONFIRMED: Hex pattern changed.\n", get_hart_id());
  }
  return 0;
}
