/*
 * CLINT directed test for the dual-core CVA7 SoC.
 *
 * Both harts execute main() in M-mode (see common/crt.S). The test exercises
 * the CLINT memory-mapped registers (CLINTBase = 0x0200_0000, see
 * ariane_soc_pkg.sv). The CLINT region is device (non-cacheable) memory, so
 * every access reaches the CLINT directly and is visible to both harts.
 *
 *   - MSIP     : base + 0x0000, 32-bit per hart (bit 0 = msip)
 *   - MTIMECMP : base + 0x4000, 64-bit per hart
 *   - MTIME    : base + 0xBFF8, 64-bit
 *
 * Checked behaviour:
 *   1. At reset MTIMECMP is 0 and MTIME >= MTIMECMP, so the CLINT posts the
 *      timer interrupt: MIP.MTIP is set on every hart. Writing MTIMECMP to a
 *      far future value de-asserts the posted interrupt (MIP.MTIP clears).
 *   2. MTIME is monotonically increasing and 64-bit readable/writable.
 *   3. MTIMECMP[hart] is 64-bit readable/writable (per-hart register).
 *   4. When MTIME >= MTIMECMP[hart] the CLINT raises timer_irq[hart]
 *      (MIP.MTIP). With MIE.MTIE and MSTATUS.MIE set, the M-mode timer
 *      interrupt (mcause = 0x8000000000000007) is taken; clearing MTIMECMP
 *      de-asserts the interrupt. Each hart independently checks its own
 *      MTIMECMP register.
 *   5. Writing 1 to MSIP[hart] sets that hart's MIP.MSIP and, with MIE.MSIE
 *      and MSTATUS.MIE set, raises the M-mode software interrupt
 *      (mcause = 0x8000000000000003). Clearing MSIP[hart] by writing 0
 *      de-asserts the interrupt. Tested in both directions
 *      (hart 1 -> hart 0 and hart 0 -> hart 1).
 *      The MSIP state is observed through the receiver's MIP.MSIP bit (a
 *      level mirror of the CLINT msip output). NOTE: the MSIP register must
 *      NOT be read back with a 32-bit load for the upper word (offset 4):
 *      the CLINT always drives the MSIP value in bit 0 of the 64-bit read
 *      data, so an RV64 lw at a 4-byte offset extracts the upper lane and
 *      always reads 0.
 *
 * The M-mode trap handler (handle_trap) verifies the cause, the MIP pending
 * bit and the MTIME >= MTIMECMP condition, then clears the interrupt cause
 * and returns the interrupted PC so the hart resumes exactly where it was.
 * Note: the handler must not call printf/lock/barrier: an interrupt can
 * preempt a hart that already holds the global printf lock (deadlock).
 */
#include <stdint.h>
#include <stdio.h>

#include "encoding.h"
#include "util.h"

/* CLINT register map (CLINTBase = 0x0200_0000, CLINT_BASE/CLINT_SIZE come from
 * encoding.h and match ariane_soc_pkg.sv: CLINTBase = 0x0200_0000,
 * CLINTLength = 0x000C_0000). */
#define CLINT_MSIP(hart)                                                       \
  ((uintptr_t)CLINT_BASE + 0x0000 + 4 * (hart)) /* 32-bit, bit 0 is MSIP */
#define CLINT_MTIMECMP(hart)                                                   \
  ((uintptr_t)CLINT_BASE + 0x4000 + 8 * (hart))      /* 64-bit */
#define CLINT_MTIME ((uintptr_t)CLINT_BASE + 0xBFF8) /* 64-bit */

/* M-mode interrupt enable bits and M-mode interrupt mcause values.
 * (MIP_MSIP/MIP_MTIP and the IRQ_M_* codes come from encoding.h.) */
#define MIE_MSIE (1UL << IRQ_M_SOFT)
#define MIE_MTIE (1UL << IRQ_M_TIMER)
#define MCAUSE_M_SOFT 0x8000000000000003UL
#define MCAUSE_M_TIMER 0x8000000000000007UL

/* MTIME forward jump used by the write test (hart 0 only: MTIME is shared). */
#define MTIME_WRITE_DELTA 0x100000UL
/* MTIMECMP is programmed that many ticks in the future for the timer test. */
#define TIMER_CMP_DELTA 0x100UL
/* Delay loop length used to make MTIME advance in the monotonicity test. */
#define MTIME_DELAY 10000

/* Per-hart status, set by the trap handler. */
static volatile int got_ipi[NUM_HARTS];
static volatile int got_timer[NUM_HARTS];
/* MTIMECMP value programmed during the timer test (checked by the handler). */
static volatile uint64_t timer_cmp[NUM_HARTS];

/* CLINT register access: device memory, no flushing/invalidate needed. */
static inline uint64_t read_mtime(void) {
  return *(volatile uint64_t *)CLINT_MTIME;
}
static inline void write_mtime(uint64_t v) {
  *(volatile uint64_t *)CLINT_MTIME = v;
}
static inline uint64_t read_mtimecmp(int hart) {
  return *(volatile uint64_t *)CLINT_MTIMECMP(hart);
}
static inline void write_mtimecmp(int hart, uint64_t v) {
  *(volatile uint64_t *)CLINT_MTIMECMP(hart) = v;
}
static inline void write_msip(int hart, uint32_t v) {
  *(volatile uint32_t *)CLINT_MSIP(hart) = v;
}

/* M-mode trap handler: verify and clear the two CLINT-generated interrupts.
 * Returns the new mepc (the interrupted PC: re-executed on mret). */
uintptr_t handle_trap(uintptr_t cause, uintptr_t epc, uintptr_t regs[32]) {
  int hart = (int)get_hart_id();

  if (cause == MCAUSE_M_TIMER) {
    /* The interrupt must be pending when the trap is taken. */
    if ((read_csr(mip) & MIP_MTIP) == 0)
      exit(1);
    /* CLINT posts the timer irq while MTIME >= MTIMECMP[hart]: MTIME is
     * monotonic, so it is still >= the programmed value here. */
    if (read_mtime() < timer_cmp[hart])
      exit(1);
    /* Clear the posted irq: MTIMECMP far in the future. */
    write_mtimecmp(hart, UINT64_MAX);
    got_timer[hart] = 1;
    return epc;
  }

  if (cause == MCAUSE_M_SOFT) {
    /* The interrupt must be pending when the trap is taken. */
    if ((read_csr(mip) & MIP_MSIP) == 0)
      exit(1);
    /* Clear own MSIP (a hart clears the MSIP of itself). */
    write_msip(hart, 0);
    got_ipi[hart] = 1;
    return epc;
  }

  /* Unexpected trap: fail. */
  exit(1337);
}

static void disable_irqs(void) {
  write_csr(mie, 0);
  clear_csr(mstatus, MSTATUS_MIE);
}

static void check_fail(const char *msg) {
  printf("%d: CLINT test FAILED: %s\n", (int)get_hart_id(), msg);
  exit(1);
}

int main(int argc, char *arg[]) {
  int hart = (int)get_hart_id();

  printf("%d: CLINT test started\n", hart);
  barrier(NUM_HARTS);

  /* --- 1. Initial state: MTIMECMP[hart] = 0 (reset) and MTIME >= 0, so the
   * timer interrupt is posted: MIP.MTIP must be set. Clearing MTIMECMP (and
   * MSIP) must de-assert it. Each hart only touches its own registers: the
   * check above must run before any hart clears a MTIMECMP. --- */
  disable_irqs();
  if ((read_csr(mip) & MIP_MTIP) == 0)
    check_fail("MIP.MTIP not set at boot");
  write_msip(hart, 0);
  write_mtimecmp(hart, UINT64_MAX);
  /* Wait for the posted timer irq to be de-asserted (MIP.MTIP clears) and
   * for any leftover MSIP to de-assert (MIP.MSIP clears). */
  while (read_csr(mip) & (MIP_MTIP | MIP_MSIP))
    ;
  printf("%d: CLINT: MTIMECMP reset and clear OK\n", hart);
  barrier(NUM_HARTS);

  /* --- 2. MTIME: monotonically increasing and 64-bit readable/writable.
   * MTIME is a shared register: only hart 0 writes it. --- */
  uint64_t m0 = read_mtime();
  for (volatile int i = 0; i < MTIME_DELAY; i++)
    ;
  uint64_t m1 = read_mtime();
  if (m1 <= m0)
    check_fail("MTIME is not increasing");
  if (hart == 0) {
    uint64_t t = read_mtime();
    write_mtime(t + MTIME_WRITE_DELTA);
    for (volatile int i = 0; i < 100; i++)
      ;
    /* The write must be visible: MTIME jumped by MTIME_WRITE_DELTA, plus a
     * few ticks while the core and the CLINT settle. */
    uint64_t t2 = read_mtime();
    if (t2 < t + MTIME_WRITE_DELTA || t2 > t + MTIME_WRITE_DELTA + 0x10000UL)
      check_fail("MTIME write not visible");
  }
  printf("%d: CLINT: MTIME monotonic and read/write OK\n", hart);
  barrier(NUM_HARTS);

  /* --- 3. MTIMECMP[hart]: 64-bit read/write of the per-hart register. --- */
  uint64_t val = 0x0123456789ABCDEFULL;
  write_mtimecmp(hart, val);
  if (read_mtimecmp(hart) != val)
    check_fail("MTIMECMP readback failed");
  printf("%d: CLINT: MTIMECMP read/write OK\n", hart);
  barrier(NUM_HARTS);

  /* --- 4. M-mode timer interrupt, on this hart's own MTIMECMP. --- */
  disable_irqs();
  uint64_t t = read_mtime();
  uint64_t cmp = t + TIMER_CMP_DELTA;
  timer_cmp[hart] = cmp;
  write_mtimecmp(hart, cmp);
  /* The CLINT posts the irq as soon as MTIME >= MTIMECMP[hart]: wait for
   * MIP.MTIP to mirror the posted interrupt. */
  while (!(read_csr(mip) & MIP_MTIP))
    ;
  /* Enable the M-mode timer interrupt and wait for the trap handler. */
  write_csr(mie, MIE_MTIE);
  set_csr(mstatus, MSTATUS_MIE);
  while (!__sync_load(&got_timer[hart]))
    ;
  /* The handler cleared MTIMECMP: the posted irq must now be de-asserted. */
  disable_irqs();
  while (read_csr(mip) & MIP_MTIP)
    ;
  printf("%d: CLINT: M timer interrupt OK\n", hart);
  barrier(NUM_HARTS);

  /* --- 5. IPI hart 1 -> hart 0: the receiver observes the MSIP state
   * through its MIP.MSIP bit (level mirror of the CLINT msip output), takes
   * the M-mode software interrupt (checked in the trap handler), and the
   * handler's MSIP clear must de-assert MIP.MSIP. --- */
  disable_irqs();
  if (hart == 1)
    write_msip(0, 1);
  barrier(NUM_HARTS);
  if (hart == 0) {
    /* The CLINT must now post the M software interrupt for this hart. */
    while (!(read_csr(mip) & MIP_MSIP))
      ;
    write_csr(mie, MIE_MSIE);
    set_csr(mstatus, MSTATUS_MIE);
    while (!__sync_load(&got_ipi[0]))
      ;
    /* The handler cleared MSIP[0]: the posted irq must de-assert. */
    disable_irqs();
    while (read_csr(mip) & MIP_MSIP)
      ;
  }
  printf("%d: CLINT: IPI 1 -> 0 OK\n", hart);
  barrier(NUM_HARTS);

  /* --- 6. IPI hart 0 -> hart 1: symmetric to the previous phase. --- */
  disable_irqs();
  if (hart == 0)
    write_msip(1, 1);
  barrier(NUM_HARTS);
  if (hart == 1) {
    /* The CLINT must now post the M software interrupt for this hart. */
    while (!(read_csr(mip) & MIP_MSIP))
      ;
    write_csr(mie, MIE_MSIE);
    set_csr(mstatus, MSTATUS_MIE);
    while (!__sync_load(&got_ipi[1]))
      ;
    /* The handler cleared MSIP[1]: the posted irq must de-assert. */
    disable_irqs();
    while (read_csr(mip) & MIP_MSIP)
      ;
  }
  printf("%d: CLINT: IPI 0 -> 1 OK\n", hart);
  barrier(NUM_HARTS);

  /* --- 7. Leave the CLINT in a quiescent state and pass. --- */
  disable_irqs();
  write_msip(hart, 0);
  write_mtimecmp(hart, UINT64_MAX);
  printf("%d: CLINT test PASSED\n", hart);
  barrier(NUM_HARTS);
  return 0;
}
