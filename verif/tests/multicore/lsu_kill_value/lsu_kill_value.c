/*
 * LSU kill-path VALUE regression test for the dual-core CVA6 SoC.
 *
 * What this test checks is the loaded value, not a hang: the load unit must write back the data
 * of the transaction that owns the load-buffer slot, and never the data of a transaction it has
 * killed.
 *
 * The bug shape:
 *   tid is ldbuf_free_index, i.e. a recycled slot index.  A request the LSU considers killed
 *   still produces a response from the cache whenever the abort is not forwarded: the abort
 *   multiplexor in hpdcache_core_arbiter.sv selects on arb_req_gnt_q, so a kill is only applied
 *   to the request that passed stage 0 in the PREVIOUS cycle.  A kill presented in a cycle where
 *   the LSU's port was not granted then is dropped.  The cache therefore answers the killed
 *   request with data, and that response carries the tid of a slot the LSU may already have
 *   released and given to another load.  If the response path consumes it, the LSU writes back
 *   the data of the killed transaction for the wrong instruction.
 *
 * So every check here is a value check:
 *   - a load must return the value written by the newest preceding store in program order;
 *   - a killed (faulted) load must not write back at all, so its destination register must still
 *     hold the sentinel.
 *
 * ISS determinism:
 *   - the ISS does not model the arbiter, the load buffer or the latency, so the reference records
 *     only the architectural result, which is the same for any latency;
 *   - the trap handler does not print (an interrupt can preempt a hart that already holds the
 *     printf lock); it records the cause and main() prints it;
 *   - the fault count is deterministic here: one trap per faulting load, the handler steps mepc
 *     past the faulting instruction;
 *   - MTIME is never read;
 *   - each phase is delimited by a barrier, so the two harts' lines for a phase are adjacent in
 *     the trace (the reference uses [01] for their order).
 *
 * Target geometry (cv64a6_imafdc_sv39, HPDCache write-through, 2 harts):
 *   NrLoadBufEntries = 2, DcacheIdWidth = 1 (tid is a slot index), rtabEntries = 4 shared by
 *   nRequesters = 8, DcacheLineWidth = 128 (clWords = 2), MmuPresent = 1, SuperscalarEn = 0,
 *   NonIdemPotenceEn = 0, Sdtrig = 0, LDBUF_FALLTHROUGH = 0.
 *
 * The real request latency is set on the harness with -GFixedDelayOutput=N.  A memory response
 * delayed by N cycles keeps the killed request outstanding long enough for its slot to be reused,
 * which is what opens the window.  The reference stays valid for any N.
 */
#include <stdint.h>
#include <stdio.h>

#include "csr.h"
#include "encoding.h"
#include "trampoline.h"
#include "util.h"
#include "vm.h"

/* CLINT register map (CLINTBase = 0x0200_0000, see ariane_soc_pkg.sv). */
#define CLINT_MSIP(h)     ((uintptr_t)CLINT_BASE + 0x0000 + 4 * (h))
#define CLINT_MTIMECMP(h) ((uintptr_t)CLINT_BASE + 0x4000 + 8 * (h))

/* M-mode software interrupt (mideleg is 0, so it is taken in M-mode): the flush source. */
#define MCAUSE_M_SOFT          0x8000000000000003ULL
/* Load page fault, as reported by the DTLB permission check: the exception-kill source.
 * mcause has the high bit set only for interrupts, so an exception is read as 13. */
#define MCAUSE_LOAD_PAGE_FAULT 13ULL

/* sstatus.SUM (bit 18 of mstatus).  With SUM = 0 a supervisor access to a user page faults on
 * the DTLB HIT, i.e. one cycle after dtlb_hit_i, which is SEND_TAG - the state where the LSU
 * asserts kill_req.  With SUM = 1 the same page is read normally, which populates the DTLB. */
#define SSTATUS_SUM (1ULL << 18)

/* One 128 B cache line = 16 x 64-bit words (clWords = 2, wordWidth = 64). */
#define LINE_WORDS 16
#define NLINES     48

#define SENTINEL 0xdeadbeef00000000ULL

/* Pressure knobs, overridable with -D.  They change only the internal timing, never the printed
 * output, so the reference stays valid for any value. */
#ifndef FAULT_ITERS
#define FAULT_ITERS 16  /* faulting loads per hart */
#endif
#ifndef KILL_ITERS
#define KILL_ITERS  24  /* kill windows per hart */
#endif
#ifndef UC_ITERS
#define UC_ITERS    64  /* uncached (CLINT) accesses by the hart that blocks the cache */
#endif
#ifndef OUTSTANDING
#define OUTSTANDING 2   /* requests kept outstanding; must stay <= NrLoadBufEntries */
#endif

/* Private buffers: each hart only touches its own, so the expected value of every load is known
 * independently of the other hart. */
static volatile uint64_t cold[NUM_HARTS][NLINES][LINE_WORDS] __attribute__((aligned(128)));

static volatile uint64_t traps[NUM_HARTS];
static volatile uint64_t faults[NUM_HARTS];
static volatile uint64_t spurious[NUM_HARTS];
static volatile uint64_t bad[NUM_HARTS];

/* Mirror of the memory model contents: the value a load must return after its line has been
 * invalidated is whatever the last store to that word put there, which is not necessarily the
 * value written at setup.  Only the hart's own words are ever written, so this stays valid. */
static uint64_t shadow[NUM_HARTS][NLINES][LINE_WORDS];

static inline uint64_t pat(uint64_t hart, uint64_t line, uint64_t word) {
  return 0x10000000ULL * hart + 0x100000ULL * line + word + 0x5eb0d60fULL;
}

/* Load into a register we then check.  The operand is read-write so the sentinel is really in the
 * destination register before the load executes: if the load faults and never retires, the
 * register keeps the sentinel, and a wrong writeback (the data of a killed transaction) shows up
 * as a mismatch. */
static inline uint64_t load_checked(volatile uint64_t *p) {
  uint64_t got = SENTINEL;
  asm volatile("ld %0, 0(%1)" : "+r"(got) : "r"(p) : "memory");
  return got;
}

/* Step mepc past the faulting instruction.  The test is compiled with the C extension, so the
 * instruction is 2 or 4 bytes: bit 1 of the first opcode byte is 0 for a compressed instruction
 * and 1 for a 32-bit one.  Byte accesses are always aligned in CVA6, so this is safe inside a
 * trap handler (a halfword or word read at an address that is 2 mod 4 would itself fault). */
#define STEP_OVER_FAULTING_INSTRUCTION                                   \
  asm volatile(                                                          \
      "csrr t0, mepc\n"                                                  \
      "lb   t1, 0(t0)\n"                                                 \
      "andi t1, t1, 2\n"                                                 \
      "beqz t1, 1f\n"                                                    \
      "addi t0, t0, 4\n"                                                 \
      "j    2f\n"                                                        \
      "1: addi t0, t0, 2\n"                                              \
      "2: csrw mepc, t0\n" ::: "t0", "t1", "memory")

/* M-mode trap handler: the software interrupt is the flush source, the page fault is the
 * exception-kill source.  It must not print and must not call barrier(). */
__attribute__((naked, aligned(4))) void mhandler(void) {
  SAVE_CONTEXT();
  uint64_t cause = csr_read(CSR_MCAUSE);
  uint64_t hart = (uint64_t)get_hart_id();

  if (cause == MCAUSE_M_SOFT) {
    traps[hart]++;
    *(volatile uint32_t *)CLINT_MSIP(hart) = 0;
    RESTORE_CONTEXT(mret);
  }

  if (cause == MCAUSE_LOAD_PAGE_FAULT) {
    faults[hart]++;
    /* The faulting load must not write back, so its destination register keeps its sentinel. */
    STEP_OVER_FAULTING_INSTRUCTION;
    RESTORE_CONTEXT(mret);
  }

  /* A store-address-misaligned fault (cause 6) whose tval is not a mapped address means the LSU
   * retired an exception for an instruction it had already retired with data: the faulting load
   * wrote back the data of the transaction it had killed.  Count it and keep running so the value
   * check in main() can report the wrong value. */
  if (cause == 6) {
    spurious[hart]++;
    STEP_OVER_FAULTING_INSTRUCTION;
    RESTORE_CONTEXT(mret);
  }

  printf("%d: LSU kill value test FAILED: unexpected mcause=0x%lx mepc=0x%lx mtval=0x%lx\n",
         (int)hart, cause, csr_read(CSR_MEPC), csr_read(CSR_MTVAL));
  exit(1337);
}

/* Identity mega-pages for RAM and the CLINT region.  The RAM mega-page is NOT a user page: with
 * SUM = 0 an instruction fetch from a user page faults (cause 12), which would fault the test's
 * own code.  Instead the user page is a separate alias mapping, VA 0x4000_0000 -> PA 0x8000_0000,
 * so the same physical buffer can be read through a user PTE. */
static void build_tables(void) {
  satp_lvl3[0x0] = BUILD_PTE(0x00000000ULL,
                             FLAG_VALID | FLAG_READ | FLAG_WRITE | FLAG_EXEC |
                             DEFAULT_FLAGS);
  satp_lvl3[0x1] = BUILD_PTE(0x80000000ULL,
                             FLAG_VALID | FLAG_READ | FLAG_WRITE | FLAG_EXEC |
                             FLAG_USER | DEFAULT_FLAGS);
  satp_lvl3[0x2] = BUILD_PTE(0x80000000ULL,
                             FLAG_VALID | FLAG_READ | FLAG_WRITE | FLAG_EXEC |
                             DEFAULT_FLAGS);
}

/* User alias of a physical address inside the RAM mega-page. */
static inline volatile uint64_t *user_alias(volatile uint64_t *p) {
  return (volatile uint64_t *)(0x40000000ULL + ((uint64_t)p - 0x80000000ULL));
}

static void check(int hart, uint64_t got, uint64_t expected) {
  if (got != expected) {
    bad[hart]++;
#ifdef DEBUG_CHECK
    printf("%d:   check got=0x%lx expected=0x%lx\n", (int)hart, got, expected);
#endif
  }
}

/* Keep the uncached path busy: every access here blocks core_req_ready_o for all 8 requesters
 * while the AXI round trip is in flight, so the worker's kill is presented in a cycle where the
 * arbiter cannot accept it. */
static void hammer(int hart, int iters) {
  for (int i = 0; i < iters; i++) {
    if (*(volatile uint64_t *)CLINT_MTIMECMP(hart) != 0x5a5a000000000000ULL)
      bad[hart]++;
  }
}

static int real_main(void) {
  int hart = (int)get_hart_id();

  for (int h = 0; h < NUM_HARTS; h++) {
    for (int l = 0; l < NLINES; l++)
      for (int w = 0; w < LINE_WORDS; w++) {
        cold[h][l][w] = pat(h, l, w);
        shadow[h][l][w] = pat(h, l, w);
      }
    *(volatile uint64_t *)CLINT_MTIMECMP(h) = 0x5a5a000000000000ULL;
  }

  barrier(NUM_HARTS);

  /* Enter S-mode manually: mideleg can only be written in M-mode, and it must stay 0 for the
   * software interrupt to be taken in M-mode.  Translation is disabled in M-mode, so the kill
   * states that need a DTLB hit only make sense in S-mode. */
  csr_write(CSR_PMPADDR0, ~0ul);
  csr_write(CSR_PMPCFG0, 0x1f);
  csr_write(CSR_MIDELEG, 0);
  csr_write(CSR_MTVEC, (uint64_t)&mhandler);
  build_tables();
  csr_write(CSR_SATP, (8ULL << 60) | ((uint64_t)satp_lvl3 >> 12));
  flush_tlb();
  /* Translation is disabled in M-mode, so the kill states that need a DTLB hit only make sense
   * in S-mode: enter it with MPP = S. */
  csr_clear(CSR_MSTATUS, SR_MPP | SR_MPRV);
  csr_set(CSR_MSTATUS, SR_MPP_S);
  csr_write(CSR_MIE, 1ULL << IRQ_M_SOFT);
  csr_set(CSR_MSTATUS, MSTATUS_MIE | MSTATUS_MPIE);

  asm volatile("la a6, 1f\n"
               "csrw mepc, a6" ::
                   : "memory", "a6");
  asm volatile("mret\n"
               "1:\n");

  /* --- Phase 1: exception kill in SEND_TAG, value check. ---
   * First read populates the DTLB with SUM = 1.  Then SUM = 0 makes the next read fault on the
   * DTLB hit, i.e. in SEND_TAG, where the LSU asserts kill_req.  The faulting load must not write
   * back: its destination register must still hold the sentinel. */
  for (int round = 0; round < 2; round++) {
    barrier(NUM_HARTS);
    if (hart == round) {
      hammer(hart, UC_ITERS);
    } else {
      for (int i = 0; i < FAULT_ITERS; i++) {
        int l = 1 + (i % (NLINES - 1));
        volatile uint64_t *u = user_alias(&cold[hart][l][0]);

        /* populate the DTLB for this page with SUM = 1 */
        csr_set(CSR_SSTATUS, SSTATUS_SUM);
        check(hart, load_checked(u), shadow[hart][l][0]);

        /* SUM = 0 -> the same access faults on the DTLB hit, i.e. in SEND_TAG, where the LSU
         * asserts kill_req.  The faulting load must not write back. */
        csr_clear(CSR_SSTATUS, SSTATUS_SUM);
        uint64_t before = faults[hart];
        uint64_t got = load_checked(u);
        if (faults[hart] != before + 1) bad[hart]++;
        check(hart, got, SENTINEL);
      }
      csr_set(CSR_SSTATUS, SSTATUS_SUM);
    }
    barrier(NUM_HARTS);
  }
  printf("%d: Phase 1 (exception kill in SEND_TAG, no writeback) %s (bad=%lu)\n", hart,
         bad[hart] ? "FAILED" : "OK", bad[hart]);

  /* --- Phase 2: killed request whose response arrives after the slot is reused. ---
   * OUTSTANDING cold-line loads are outstanding when the interrupt is taken at commit.  With the
   * latency knob the killed request stays in the cache pipeline long enough for its slot to be
   * taken by another load; the response of the killed request must not be attributed to it. */
  for (int round = 0; round < 2; round++) {
    barrier(NUM_HARTS);
    if (hart == round) {
      hammer(hart, UC_ITERS);
    } else {
      for (int i = 0; i < KILL_ITERS; i++) {
        int a = (i * 5) % NLINES;
        int b = (i * 5 + 1) % NLINES;
        for (int k = 0; k < OUTSTANDING; k++) invalidate_cacheline(&cold[hart][a][k]);
        invalidate_cacheline(&cold[hart][b][0]);

        *(volatile uint32_t *)CLINT_MSIP(hart) = 1; /* interrupt becomes pending */
        unsigned long acc = i;                      /* ALU op: at commit -> flush */
        acc += 1;

        /* the killed loads must not write back */
        check(hart, load_checked(&cold[hart][a][0]), pat(hart, a, 0));
        check(hart, load_checked(&cold[hart][b][0]), pat(hart, b, 0));
        if (acc != (unsigned long)i + 1) bad[hart]++;
      }
    }
    barrier(NUM_HARTS);
  }
  printf("%d: Phase 2 (killed response vs reused slot) %s (bad=%lu)\n", hart,
         bad[hart] ? "FAILED" : "OK", bad[hart]);

  /* --- Phase 3: store then load a different word of the same line, with a kill between. ---
   * The store's address is what the killed request carries; the load must return the value of the
   * newest preceding store in program order, not the data of the killed transaction. */
  for (int round = 0; round < 2; round++) {
    barrier(NUM_HARTS);
    if (hart == round) {
      hammer(hart, UC_ITERS);
    } else {
      for (int i = 0; i < KILL_ITERS; i++) {
        int l = (i * 7 + 2) % NLINES;
        invalidate_cacheline(&cold[hart][l][0]);
        invalidate_cacheline(&cold[hart][l][1]);

        unsigned long stored = 0x10000000ULL * (uint64_t)hart + 0x100000ULL * (uint64_t)l + 0x111ULL;
        cold[hart][l][0] = stored;
        shadow[hart][l][0] = stored;
        *(volatile uint32_t *)CLINT_MSIP(hart) = 1;
        unsigned long acc = i;
        acc += 1;

        /* the load of the word the store wrote must see the store, not the data of a killed
         * transaction; the load of the other word must see the value written at setup */
        check(hart, load_checked(&cold[hart][l][0]), shadow[hart][l][0]);
        check(hart, load_checked(&cold[hart][l][1]), shadow[hart][l][1]);
        if (acc != (unsigned long)i + 1) bad[hart]++;
      }
    }
    barrier(NUM_HARTS);
  }
  printf("%d: Phase 3 (store then load another word, kill between) %s (bad=%lu)\n", hart,
         bad[hart] ? "FAILED" : "OK", bad[hart]);

  /* --- Phase 4: kill storm, two slots, value checks on both. ---
   * Repeated flushes with the buffer full so both flag writers are exercised on every slot.  A
   * flag left on a slot that is freed in the same cycle must not survive into the next occupant
   * of that slot, and a response must never be attributed to a slot that is not outstanding. */
  for (int round = 0; round < 2; round++) {
    barrier(NUM_HARTS);
    if (hart == round) {
      hammer(hart, UC_ITERS);
    } else {
      for (int i = 0; i < KILL_ITERS; i++) {
        int l = (i * 11 + 3) % NLINES;
        invalidate_cacheline(&cold[hart][l][0]);
        invalidate_cacheline(&cold[hart][l][1]);

        *(volatile uint32_t *)CLINT_MSIP(hart) = 1;
        check(hart, load_checked(&cold[hart][l][0]), shadow[hart][l][0]);
        *(volatile uint32_t *)CLINT_MSIP(hart) = 1;
        check(hart, load_checked(&cold[hart][l][1]), shadow[hart][l][1]);

        /* the slot that was killed must now be reused by a load that is not discarded */
        check(hart, load_checked(&cold[hart][l][2]), shadow[hart][l][2]);
      }
    }
    barrier(NUM_HARTS);
  }
  printf("%d: Phase 4 (kill storm, both slots) %s\n", hart, bad[hart] ? "FAILED" : "OK");

  /* The handler must have run at least once for both sources.  The software-interrupt count is
   * not ISS-deterministic (MSIP is cleared by an asynchronous store and the level can re-fire),
   * so only "the handler ran at least once" is checked.  The page-fault count is deterministic. */
  barrier(NUM_HARTS);
  if (traps[hart] == 0) bad[hart]++;
  if (faults[hart] != FAULT_ITERS) bad[hart]++;
  if (spurious[hart] != 0) bad[hart]++;
  printf("%d: LSU kill value test %s (bad=%lu spurious=%lu)\n", hart,
         bad[hart] ? "FAILED" : "PASSED", bad[hart], spurious[hart]);

  return 0;
}

int main(int argc, char *arg[]) { return real_main(); }
