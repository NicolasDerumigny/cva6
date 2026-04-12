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

int main(int argc, char *arg[]) {
  /* float op1 = 1.4142; */
  /* float op2 = 1.4142; */
  /* float ans = op1 * op2; */

  // Cast the memory address of the floats to uint32_t pointers
  /* uint32_t op1_bits = *(uint32_t *)&op1; */
  /* uint32_t op2_bits = *(uint32_t *)&op2; */
  /* uint32_t ans_bits = *(uint32_t *)&ans; */

  /* printf("op1 in core %d: 0x%08x\n", get_hart_id(), op1_bits); */
  /* printf("op2 in core %d: 0x%08x\n", get_hart_id(), op2_bits); */
  /* printf("result in core %d: 0x%08x\n", get_hart_id(), ans_bits); */
  /* uint32_t core_id = get_hart_id(); */
  /* if (core_id == 0) { */
  /*   float a = 3.14; */
  /*   float b = 2.0; */
  /*   float res_add = a + b; */
  /*   uint32_t bits = *(uint32_t *)&res_add; */
  /*   printf("Core 0 Addition: 0x%08x\n", bits); */
  /* } else if (core_id == 1) { */
  /*   /\* float x = 1.4142; *\/ */
  /*   /\* float y = 1.4142; *\/ */
  /*   /\* float res_mul = x * y; *\/ */
  /*   /\* uint32_t bits = *(uint32_t *)&res_mul; *\/ */
  /*   /\* printf("Core 1 Multiplication: 0x%08x\n", bits); *\/ */
  /*   printf("%d: Hello World!\n", core_id); */
  /*   /\* int a = 0; *\/ */
  /*   /\* for (int i = 0; i < 5; i++) { *\/ */
  /*   /\*   a += i; *\/ */
  /*   /\* } *\/ */
  /*   /\* printf("%d: Hello World finished!\n", core_id); *\/ */
  /* } */

  printf("%d: Hello World!\n", get_hart_id());

  int a = 0;
  for (int i = 0; i < 5; i++) {
    a += i;
  }

  printf("%d: Hello World finished!\n", get_hart_id());
  return 0;
}
