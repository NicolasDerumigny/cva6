#include <stdint.h>
#include <stdio.h>

#include "util.h"

#define NUM_INCREASE 100

int shared_value = 0;

static inline int atomic_inc(int *addr) {
    int old, newval, status;

    do {
        __asm__ volatile (
            "lr.w   %0, (%3)\n"      // old = *addr (reservation set)
            "addi   %1, %0, 1\n"     // newval = old + 1
            "sc.w   %2, %1, (%3)\n"  // status = store-conditional
            : "=&r"(old), "=&r"(newval), "=&r"(status)
            : "r"(addr)
            : "memory"
        );
    } while (status != 0);           // retry if SC failed

    return newval;                   // return incremented value
}


int main(int argc, char *arg[]) {

  printf("%d: LR/SC test started, val is %p!\n", get_hart_id(), &shared_value);

  for (int i=0; i<NUM_INCREASE; i++) {
      atomic_inc(&shared_value);
  }

  // FIXME: do not run Spike on that!
  barrier(NUM_HARTS);

  printf("%d: LR/SC final value: %d!\n", get_hart_id(), __sync_load(&shared_value));
  return 0;
}
