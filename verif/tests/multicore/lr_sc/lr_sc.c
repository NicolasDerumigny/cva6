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
            "addi   %1, %1, 1\n"      // newval = old + 2
            "addi   %1, %1, -1\n"     // newval = old + 1
            "addi   %1, %1, 1\n"      // newval = old + 2
            "addi   %1, %1, -1\n"     // newval = old + 1
            "addi   %1, %1, 1\n"      // newval = old + 2
            "addi   %1, %1, -1\n"     // newval = old + 1
            "addi   %1, %1, 1\n"      // newval = old + 2
            "addi   %1, %1, -1\n"     // newval = old + 1
            "addi   %1, %1, 1\n"      // newval = old + 2
            "addi   %1, %1, -1\n"     // newval = old + 1
            "addi   %1, %1, 1\n"      // newval = old + 2
            "addi   %1, %1, -1\n"     // newval = old + 1
            "addi   %1, %1, 1\n"      // newval = old + 2
            "addi   %1, %1, -1\n"     // newval = old + 1
            "addi   %1, %1, 1\n"      // newval = old + 2
            "addi   %1, %1, -1\n"     // newval = old + 1
            "sc.w   %2, %1, (%3)\n"  // status = store-conditional
            : "=&r"(old), "=&r"(newval), "=&r"(status)
            : "r"(addr)
            : "memory"
        );
    } while (status != 0);           // retry if SC failed

    return newval;                   // return incremented value
}

static inline int atomic_inc_amo(int *addr) {
    int old, newval, status;

    __asm__ volatile (
        "addi   %2, x0, 1\n"      // %1 = 1
        "amoadd.w.aqrl  %1, %2, (%3)\n" // %1 = atomic_add(%3, %1)
        "amoadd.w.aqrl  %1, %2, (%3)\n" // %1 = atomic_add(%3, %1)
        "amoadd.w.aqrl  %1, %2, (%3)\n" // %1 = atomic_add(%3, %1)
        "amoadd.w.aqrl  %1, %2, (%3)\n" // %1 = atomic_add(%3, %1)
        "amoadd.w.aqrl  %1, %2, (%3)\n" // %1 = atomic_add(%3, %1)
        "amoadd.w.aqrl  %1, %2, (%3)\n" // %1 = atomic_add(%3, %1)
        "amoadd.w.aqrl  %1, %2, (%3)\n" // %1 = atomic_add(%3, %1)
        "amoadd.w.aqrl  %1, %2, (%3)\n" // %1 = atomic_add(%3, %1)
        "amoadd.w.aqrl  %1, %2, (%3)\n" // %1 = atomic_add(%3, %1)
        "amoadd.w.aqrl  %1, %2, (%3)\n" // %1 = atomic_add(%3, %1)
        "amoadd.w.aqrl  %1, %2, (%3)\n" // %1 = atomic_add(%3, %1)
        "amoadd.w.aqrl  %1, %2, (%3)\n" // %1 = atomic_add(%3, %1)
        "amoadd.w.aqrl  %1, %2, (%3)\n" // %1 = atomic_add(%3, %1)
        "amoadd.w.aqrl  %1, %2, (%3)\n" // %1 = atomic_add(%3, %1)
        "amoadd.w.aqrl  %1, %2, (%3)\n" // %1 = atomic_add(%3, %1)
        "amoadd.w.aqrl  %1, %2, (%3)\n" // %1 = atomic_add(%3, %1)
        "amoadd.w.aqrl  %1, %2, (%3)\n" // %1 = atomic_add(%3, %1)
        "amoadd.w.aqrl  %1, %2, (%3)\n" // %1 = atomic_add(%3, %1)
        "amoadd.w.aqrl  %1, %2, (%3)\n" // %1 = atomic_add(%3, %1)
        "amoadd.w.aqrl  %1, %2, (%3)\n" // %1 = atomic_add(%3, %1)
        "amoadd.w.aqrl  %1, %2, (%3)\n" // %1 = atomic_add(%3, %1)
        : "=&r"(old), "=&r"(newval), "=&r"(status)
        : "r"(addr)
        : "memory"
    );

    if (status == 0) {
        printf("ERROR, LR/SC should have failed\n");
    }

    return newval;                   // return incremented value
}


int main(int argc, char *arg[]) {

  printf("%d: LR/SC test started, val is %p!\n", get_hart_id(), &shared_value);

  for (int i=0; i<NUM_INCREASE; i++) {
      atomic_inc(&shared_value);
  }

  barrier(NUM_HARTS);

  printf("%d: LR/SC int value: %d!\n", get_hart_id(), __sync_load(&shared_value));

  if (get_hart_id() == 0) {
    for (int i=0; i<NUM_INCREASE; i++) {
      atomic_inc(&shared_value);
    }
  } else {
    for (int i=0; i<NUM_INCREASE; i++) {
      atomic_inc_amo(&shared_value);
    }
  }

  barrier(NUM_HARTS);
  printf("%d: LR/SC mix amoadd final value: %d!\n", get_hart_id(), __sync_load(&shared_value));

  for (int i=0; i<NUM_INCREASE; i++) {
    atomic_inc_amo(&shared_value);
  }

  barrier(NUM_HARTS);

  printf("%d: Amoadd final value: %d!\n", get_hart_id(), __sync_load(&shared_value));
  return 0;
}
