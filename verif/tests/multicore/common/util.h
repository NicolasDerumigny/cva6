// See LICENSE for license details.

#ifndef __UTIL_H
#define __UTIL_H

extern void setStats(int enable);

#include <stdint.h>

#define static_assert(cond)                                                    \
  switch (0) {                                                                 \
  case 0:                                                                      \
  case !!(long)(cond):;                                                        \
  }

static unsigned long get_hart_id() {
  register unsigned long ret asm("a0");
  asm volatile("csrr    a0, mhartid" : "=r"(ret));
  return ret;
}

static int verify(int n, const volatile int *test, const int *verify) {
  int i;
  // Unrolled for faster verification
  for (i = 0; i < n / 2 * 2; i += 2) {
    int t0 = test[i], t1 = test[i + 1];
    int v0 = verify[i], v1 = verify[i + 1];
    if (t0 != v0)
      return i + 1;
    if (t1 != v1)
      return i + 2;
  }
  if (n % 2 != 0 && test[n - 1] != verify[n - 1])
    return n;
  return 0;
}

static int verifyDouble(int n, const volatile double *test,
                        const double *verify) {
  int i;
  // Unrolled for faster verification
  for (i = 0; i < n / 2 * 2; i += 2) {
    double t0 = test[i], t1 = test[i + 1];
    double v0 = verify[i], v1 = verify[i + 1];
    int eq1 = t0 == v0, eq2 = t1 == v1;
    if (!(eq1 & eq2))
      return i + 1 + eq1;
  }
  if (n % 2 != 0 && test[n - 1] != verify[n - 1])
    return n;
  return 0;
}

static void __attribute__((noinline)) barrier(int ncores) {
#ifdef __riscv_atomic // __sync_* builtins require A extension
  static volatile int sense;
  static volatile int count;
  static __thread int threadsense;

  __sync_synchronize();

  threadsense = !threadsense;
  if (__sync_fetch_and_add(&count, 1) == ncores - 1) {
    count = 0;
    sense = threadsense;
  } else
    while (sense != threadsense)
      ;

  __sync_synchronize();
#endif // __riscv_atomic
}

static uint64_t lfsr(uint64_t x) {
  uint64_t bit = (x ^ (x >> 1)) & 1;
  return (x >> 1) | (bit << 62);
}

static uintptr_t insn_len(uintptr_t pc) {
  return (*(unsigned short *)pc & 3) ? 4 : 2;
}

#ifdef __riscv
#include "encoding.h"
#endif

#define stringify_1(s) #s
#define stringify(s) stringify_1(s)
#define stats(code, iter)                                                      \
  do {                                                                         \
    unsigned long _c = -read_csr(mcycle), _i = -read_csr(minstret);            \
    code;                                                                      \
    _c += read_csr(mcycle), _i += read_csr(minstret);                          \
    if (cid == 0)                                                              \
      printf("\n%s: %ld cycles, %ld.%ld cycles/iter, %ld.%ld CPI\n",           \
             stringify(code), _c, _c / iter, 10 * _c / iter % 10, _c / _i,     \
             10 * _c / _i % 10);                                               \
  } while (0)

#define __sync_load(a) __atomic_load_n(a, __ATOMIC_ACQUIRE)
#define __sync_store(a, val) __atomic_store_n(a, val, __ATOMIC_RELEASE)
#define __sync_compare_and_swap_n(a, old_val, new_val)                         \
  __atomic_compare_exchange_n(a, old_val, new_val, 0, __ATOMIC_RELEASE,        \
                              __ATOMIC_ACQUIRE)
#define __sync_fetch_and_add(a, inc)                                           \
  __atomic_fetch_add(a, inc, __ATOMIC_ACQUIRE)

#ifdef __riscv_atomic // __sync_* builtins require A extension
static uint8_t __syscall_lock = 0;

static inline void lock() {
  uint8_t expected;
  do {
    expected = 0;
  } while (__sync_compare_and_swap_n(&__syscall_lock, &expected, 1));
}

static inline void unlock() { __sync_store(&__syscall_lock, 0); }

static inline void invalidate_cacheline(volatile void *addr) {
  __asm__ volatile("cbo.inval (%0)" ::"r"(addr) : "memory");
}

#endif

#endif //__UTIL_H
