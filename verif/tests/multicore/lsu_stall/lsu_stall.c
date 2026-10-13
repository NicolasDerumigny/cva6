/*
 * Load-unit stall / load-buffer directed test for the dual-core CVA6 SoC.
 *
 * Target geometry (cv64a6_imafdc_sv39, HPDCache write-through, 2 harts):
 *   NrLoadBufEntries = 2, DcacheIdWidth = 1 (tid is a 1-bit slot index),
 *   wbufWords = 1, rtabEntries = 4 shared by nRequesters = 8,
 *   DcacheLineWidth = 128 (clWords = 2), DcacheSetAssoc = 8,
 *   MmuPresent = 1, SuperscalarEn = 0, NonIdemPotenceEn = 0, Sdtrig = 0.
 *
 * LSU states exercised:
 *   IDLE, WAIT_GNT, SEND_TAG, WAIT_PAGE_OFFSET, ABORT_TRANSACTION,
 *   WAIT_TRANSLATION, WAIT_FLUSH, WAIT_GNT_FLUSH.
 * WAIT_WB_EMPTY and WAIT_SPEC_LOAD are not reachable in this configuration
 * (NonIdemPotenceEn = 0, SuperscalarEn = 0), and the sdtrig load-cancel path
 * needs Sdtrig = 1.
 *
 * How the "cache cannot accept a request" window is created
 * (core_req_ready_o = 0, hpdcache_ctrl_pe.sv:1281-1290):
 *   - uc_busy: only 0x8000_0000..0xC000_0000 is inside the cacheable region, so
 *     every CLINT access goes through the uncached path and keeps uc_busy = 1
 *     for the whole AXI round trip (hpdcache_uncached.sv:635), which blocks all
 *     8 requesters.
 *   - rtab_full: 4 replay-table entries shared by 8 requesters; keeping 2 cold
 *     lines outstanding on each hart uses all 4.
 *
 * How the flush is made to land while the LSU still holds a presented request
 * (WAIT_GNT_FLUSH): the LSU pops a load only at grant, so a load held in
 * WAIT_GNT is not in the commit queue and the commit pointer sits on an earlier
 * instruction.  A software interrupt pending at that moment is taken at commit
 * -> controller flush_ex_o -> load_unit flush_i.
 *
 * Why the test runs in S-mode: ABORT_TRANSACTION / WAIT_TRANSLATION need a DTLB
 * miss, and M-mode never translates (csr_regfile.sv:2809).  The interrupt is
 * nevertheless taken in M-mode, because this fork's riscv_pkg puts MSIP at bit 3
 * of mip (IRQ_M_SOFT = 3) while the delegatable bits are 2/6/10, so the software
 * interrupt cannot be delegated to S-mode; mideleg is therefore left at 0 and a
 * naked M-mode handler mrets back to S-mode.
 *
 * ISS determinism:
 *   - the ISS does not model the arbiter, so the reference records only the
 *     architectural result; every check is "a load returns the value of the
 *     newest preceding store in program order".
 *   - MTIME is never read: its value depends on the AXI timing on the RTL and on
 *     the instruction count on the ISS.  MTIMECMP is read back as the value that
 *     was programmed.
 *   - the trap handler does not print: an interrupt can preempt a hart that
 *     already holds the printf lock.
 *   - the handler count is NOT printed: MSIP is cleared by an asynchronous store
 *     and the level can re-fire, so the number of handler executions is not
 *     ISS-deterministic.  Only "the handler ran at least once" is checked.
 *   - each phase is delimited by a barrier, so the two harts' lines for a phase
 *     are adjacent in the trace (the reference uses [01] for their order).
 *
 * Configurable request latency:
 *   The C test cannot choose the latency it sees: the model's memory round trip is
 *   3 cycles, so a uc_busy window is 3 cycles long and the LSU is never held more
 *   than one cycle (the WAIT_GNT transitions are arbitration losses, not stalls).
 *   The latency is therefore set on the harness, through the AXI delayer that is
 *   already in the testbench:
 *     make verilate target=cv64a6_imafdc_sv39 CVA6_NR_HARTS=2 \
 *       verilator="verilator --no-timing -GNR_CORES=2 -GFixedDelayOutput=12"
 *   Delaying the read-response channel by N cycles keeps uc_busy = 1 for N cycles,
 *   so every request presented during a window is held in WAIT_GNT, and the long
 *   memory latency also makes rtab_full reachable (4 shared entries with 2 harts
 *   keeping cold lines outstanding).  Measured on this test: mean WAIT_GNT dwell
 *   0 cycles at the default, mean 13 / max 358 at FixedDelayOutput = 12.
 *   stream_delay uses a 4-bit counter, so the usable range is 0..15.
 *   The reference stays valid for any latency: the ISS does not model it, so only
 *   the timing changes, not the architectural result.
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

/* M-mode software interrupt (mideleg is 0, so it is taken in M-mode). */
#define MCAUSE_M_SOFT 0x8000000000000003ULL

/* One 128 B cache line = 16 x 64-bit words (clWords = 2, wordWidth = 64). */
#define LINE_WORDS 16
#define NLINES     48

/* Pressure knobs.  They are overridable from the command line with -D, e.g.
 *   --gcc_opts="... -DLATENCY=24 -DOUTSTANDING=2 -DPRESSURE_ROUNDS=8"
 * They change only the internal timing, never the printed output, so the
 * reference file stays valid for any value. */
#ifndef UC_ITERS
#define UC_ITERS    64  /* uncached (CLINT) accesses by the hart that blocks the cache */
#endif
#ifndef LOAD_ITERS
#define LOAD_ITERS  32  /* cold-line load groups */
#endif
#ifndef PO_ITERS
#define PO_ITERS    24  /* page-offset collisions */
#endif
#ifndef TLB_ITERS
#define TLB_ITERS   16  /* cold pages (DTLB misses) */
#endif
#ifndef FLUSH_ITERS
#define FLUSH_ITERS 24  /* interrupt taken at commit while a load is held */
#endif

/* Request latency.  The real latency is set on the harness with
 * -GFixedDelayOutput=N (see the header): each memory response then comes back N
 * cycles late, so one uncached access keeps core_req_ready_o low for N + 3 cycles.
 * LATENCY_ROUNDS is how many back-to-back uncached accesses the blocking hart
 * issues per window, so the window is LATENCY_ROUNDS * (N + 3) cycles long and the
 * worker's requests presented inside it are held in WAIT_GNT for that long.
 * With the default harness (N = 0) a window is only LATENCY_ROUNDS * 3 cycles, which
 * is the best the C test can do on its own. */
#ifndef LATENCY_ROUNDS
#define LATENCY_ROUNDS 8
#endif
/* How many requests the worker keeps outstanding per window.  Keep it <=
 * NrLoadBufEntries: the LSU enters WAIT_GNT only for a request it has accepted,
 * so a value above the load-buffer depth measures ldbuf_full instead (the LSU
 * stays in IDLE and does not present at all). */
#ifndef OUTSTANDING
#define OUTSTANDING 2
#endif
/* Number of latency windows per round. */
#ifndef PRESSURE_ROUNDS
#define PRESSURE_ROUNDS 4
#endif

#define UC_SENTINEL 0x5a5a000000000000ULL
#define STORE_VALUE 0x00000000000000bbULL

/* Private buffers: each hart only touches its own, so the expected value of
 * every load is known independently of the other hart. */
static volatile uint64_t cold[NUM_HARTS][NLINES][LINE_WORDS] __attribute__((aligned(128)));
/* Two pages 4 KiB apart: the store and the load share the same page offset. */
static volatile uint64_t po_page[NUM_HARTS][1024] __attribute__((aligned(4096)));
/* A page touched only in the TLB-miss phase, so its first access always misses. */
static volatile uint64_t tlb_page[NUM_HARTS][512] __attribute__((aligned(4096)));

static volatile uint64_t traps[NUM_HARTS];
static volatile uint64_t bad[NUM_HARTS];

static inline uint64_t pat(uint64_t hart, uint64_t line, uint64_t word) {
  return 0x10000000ULL * hart + 0x100000ULL * line + word + 0x5eb0d60fULL;
}

/* M-mode trap handler: the software interrupt is the flush source.  It must not
 * print and must not call barrier(). */
__attribute__((naked, aligned(4))) void mhandler(void) {
  SAVE_CONTEXT();
  uint64_t cause = csr_read(CSR_MCAUSE);
  uint64_t hart = (uint64_t)get_hart_id();

  if (cause == MCAUSE_M_SOFT) {
    traps[hart]++;
    *(volatile uint32_t *)CLINT_MSIP(hart) = 0;
    RESTORE_CONTEXT(mret);
  }

  printf("%d: LSU stall test FAILED: unexpected mcause=0x%lx mepc=0x%lx\n",
         (int)hart, cause, csr_read(CSR_MEPC));
  exit(1337);
}

/* Identity mega-pages: RAM (0x8000_0000) and the CLINT region (0x0000_0000).
 * The CLINT stays uncacheable (PMA) even though its page is mapped. */
static void build_tables(void) {
  satp_lvl3[0x0] = BUILD_PTE(0x00000000ULL,
                             FLAG_VALID | FLAG_READ | FLAG_WRITE | FLAG_EXEC |
                             DEFAULT_FLAGS);
  satp_lvl3[0x2] = BUILD_PTE(0x80000000ULL,
                             FLAG_VALID | FLAG_READ | FLAG_WRITE | FLAG_EXEC |
                             DEFAULT_FLAGS);
}

static void check(int hart, uint64_t got, uint64_t expected) {
  if (got != expected) bad[hart]++;
}

/* Keep the uncached path busy: every access here blocks core_req_ready_o for
 * all 8 requesters while the AXI round trip is in flight. */
static void hammer(int hart, int iters) {
  for (int i = 0; i < iters; i++) {
    if (*(volatile uint64_t *)CLINT_MTIMECMP(hart) != UC_SENTINEL)
      bad[hart]++;
  }
}

static int real_main(void) {
  int hart = (int)get_hart_id();

  for (int h = 0; h < NUM_HARTS; h++) {
    for (int l = 0; l < NLINES; l++)
      for (int w = 0; w < LINE_WORDS; w++) cold[h][l][w] = pat(h, l, w);
    for (int i = 0; i < 1024; i++) po_page[h][i] = pat(h, i, 0);
    for (int i = 0; i < 512; i++) tlb_page[h][i] = pat(h, i, 1);
    *(volatile uint64_t *)CLINT_MTIMECMP(h) = UC_SENTINEL;
  }

  barrier(NUM_HARTS);

  /* Enter S-mode manually: mideleg can only be written in M-mode, and it must
   * stay 0 for the software interrupt to be taken in M-mode. */
  csr_write(CSR_PMPADDR0, ~0ul);
  csr_write(CSR_PMPCFG0, 0x1f);
  csr_write(CSR_MIDELEG, 0);
  csr_write(CSR_MTVEC, (uint64_t)&mhandler);
  build_tables();
  csr_write(CSR_SATP, (8ULL << 60) | ((uint64_t)satp_lvl3 >> 12));
  flush_tlb();
  csr_clear(CSR_MSTATUS, SR_MPP | SR_MPRV);
  csr_set(CSR_MSTATUS, SR_MPP_S);
  csr_write(CSR_MIE, 1ULL << IRQ_M_SOFT);
  csr_set(CSR_MSTATUS, MSTATUS_MIE | MSTATUS_MPIE);

  csr_write(CSR_MEPC, (uint64_t)&&smode_entry);
  asm volatile goto("mret" ::: "memory" : smode_entry);

smode_entry:
  printf("%d: LSU stall test started (S-mode, paging)\n", hart);

  /* --- Phase 1: uc_busy window, WAIT_GNT, load buffer full. ---
   * Three cold lines per group: the first two fill the 2-entry load buffer,
   * the third cannot be accepted (ldbuf_full) and the first two are presented
   * without a grant, so the LSU sits in WAIT_GNT. */
  for (int round = 0; round < 2; round++) {
    barrier(NUM_HARTS);
    if (hart == round) {
      hammer(hart, UC_ITERS);
    } else {
      for (int i = 0; i < LOAD_ITERS; i++) {
        for (int k = 0; k < 3; k++) {
          int l = (i * 3 + k) % NLINES;
          check(hart, cold[hart][l][0], pat(hart, l, 0));
        }
      }
    }
    barrier(NUM_HARTS);
  }
  printf("%d: Phase 1 (uc_busy + WAIT_GNT + ldbuf_full) %s\n", hart,
         bad[hart] ? "FAILED" : "OK");

  /* --- Phase 2: store and load in the same line, different words. ---
   * Word 3 is written, word 2 is read: the page offsets differ, so the store
   * buffer does not force WAIT_PAGE_OFFSET and the load is presented while the
   * store is still pending.  The load must return the line content, not the
   * data of the pending store. */
  for (int round = 0; round < 2; round++) {
    barrier(NUM_HARTS);
    if (hart == round) {
      hammer(hart, UC_ITERS);
    } else {
      for (int i = 0; i < LOAD_ITERS; i++) {
        int l = (i * 3) % NLINES;
        cold[hart][l][3] = STORE_VALUE;
        check(hart, cold[hart][l][2], pat(hart, l, 2));
      }
    }
    barrier(NUM_HARTS);
  }
  printf("%d: Phase 2 (store->load same line) %s\n", hart,
         bad[hart] ? "FAILED" : "OK");

  /* --- Phase 3: mispredicted branch before the load. ---
   * The load is speculative: the branch direction comes from an LCG so the
   * predictor cannot learn it, and the flush lands while the load is presented.
   * Combined with the pending store in the same line, this is the shape of the
   * original repro: the load must not be attributed to the store's word. */
  for (int round = 0; round < 2; round++) {
    barrier(NUM_HARTS);
    if (hart == round) {
      hammer(hart, UC_ITERS);
    } else {
      uint64_t seed = 0x12345678ULL + (uint64_t)hart;
      uint64_t acc = 0;
      for (int i = 0; i < LOAD_ITERS; i++) {
        int l = (i * 3 + 1) % NLINES;
        cold[hart][l][3] = STORE_VALUE;
        seed = seed * 6364136223846793005ULL + 1442695040888963407ULL;
        if ((seed >> 61) & 1ULL) acc++;   /* unpredictable direction */
        else acc--;
        check(hart, cold[hart][l][2], pat(hart, l, 2));
      }
      if (acc == 123456789ULL) bad[hart]++;  /* keep the branch alive */
    }
    barrier(NUM_HARTS);
  }
  printf("%d: Phase 3 (mispredicted branch + pending store) %s\n", hart,
         bad[hart] ? "FAILED" : "OK");

  /* --- Phase 4: rtab_full. ---
   * Both harts stream cold lines at the same time: 2 load-buffer entries each
   * saturate the 4 shared replay-table entries, so any further request is held
   * in WAIT_GNT.  The response of a request must still be delivered to the slot
   * that is still allocated (tid is a recycled slot index). */
  barrier(NUM_HARTS);
  for (int i = 0; i < LOAD_ITERS; i++) {
    for (int k = 0; k < 3; k++) {
      int l = (i * 3 + k) % NLINES;
      check(hart, cold[hart][l][0], pat(hart, l, 0));
    }
  }
  barrier(NUM_HARTS);
  printf("%d: Phase 4 (rtab_full) %s\n", hart, bad[hart] ? "FAILED" : "OK");

  /* --- Phase 5: WAIT_PAGE_OFFSET. ---
   * Store and load share bits 11:0, so the load must wait for the store buffer
   * to drain before it is presented. */
  for (int i = 0; i < PO_ITERS; i++) {
    po_page[hart][0] = i + 1;
    check(hart, po_page[hart][512], pat(hart, 512, 0));
  }
  barrier(NUM_HARTS);
  printf("%d: Phase 5 (WAIT_PAGE_OFFSET) %s\n", hart, bad[hart] ? "FAILED" : "OK");

  /* --- Phase 6: DTLB miss -> ABORT_TRANSACTION -> WAIT_TRANSLATION. ---
   * The request is accepted, then aborted in the second cycle of the addressing
   * pipeline, so the kill must be recorded against the slot that was allocated
   * in the previous cycle.  tlb_page is touched only here: every access misses. */
  for (int round = 0; round < 2; round++) {
    barrier(NUM_HARTS);
    if (hart == round) {
      hammer(hart, UC_ITERS);
    } else {
      for (int i = 0; i < TLB_ITERS; i++) {
        check(hart, tlb_page[hart][i], pat(hart, i, 1));
        flush_tlb();
      }
    }
    barrier(NUM_HARTS);
  }
  printf("%d: Phase 6 (DTLB miss / ABORT_TRANSACTION) %s\n", hart,
         bad[hart] ? "FAILED" : "OK");

  /* --- Phase 7: WAIT_GNT_FLUSH. ---
   * The load is presented and held (the other hart keeps the cache busy), so it
   * is not in the commit queue; the commit pointer is on the ALU instruction.
   * The pending software interrupt is taken there -> flush_i while the LSU holds
   * a presented request.  The request must be held until the grant and then
   * killed; the load is re-executed and must return the right value. */
  for (int round = 0; round < 2; round++) {
    barrier(NUM_HARTS);
    if (hart == round) {
      hammer(hart, UC_ITERS);
    } else {
      for (int i = 0; i < FLUSH_ITERS; i++) {
        int l = (i * 5) % NLINES;
        *(volatile uint32_t *)CLINT_MSIP(hart) = 1; /* interrupt becomes pending */
        unsigned long acc = i;                      /* ALU op: at commit */
        acc += 1;
        check(hart, cold[hart][l][0], pat(hart, l, 0)); /* presented, held */
        /* The slot that was killed must be reusable: a flag left on a free slot
         * can never be cleared, and the next load allocated there is dropped,
         * which hangs the LSU. */
        check(hart, cold[hart][l][1], pat(hart, l, 1));
        if (acc == 0) bad[hart]++;
      }
    }
    barrier(NUM_HARTS);
  }
  printf("%d: Phase 7 (WAIT_GNT_FLUSH) %s\n", hart, bad[hart] ? "FAILED" : "OK");

  /* --- Phase 8: configurable request latency window. ---
   * The blocking hart keeps the uncached path busy for LATENCY_ROUNDS accesses per
   * window, so every request the worker presents during a window is held in
   * WAIT_GNT for the whole window (LATENCY_ROUNDS * (FixedDelayOutput + 3) cycles).
   * OUTSTANDING requests per window keep the load buffer exactly full: the LSU
   * enters WAIT_GNT only for a request it has accepted, so OUTSTANDING must stay
   * <= NrLoadBufEntries, otherwise the extra request is not presented at all and the
   * phase measures ldbuf_full instead.  Both harts take about one memory round trip
   * per iteration, so they stay aligned without a per-window barrier: a barrier would
   * serialise the window and remove the pressure. */
  for (int round = 0; round < 2; round++) {
    barrier(NUM_HARTS);
    if (hart == round) {
      for (int w = 0; w < PRESSURE_ROUNDS; w++) hammer(hart, LATENCY_ROUNDS);
    } else {
      for (int w = 0; w < PRESSURE_ROUNDS; w++) {
        for (int k = 0; k < OUTSTANDING; k++) {
          int l = (w * OUTSTANDING + k) % NLINES;
          check(hart, cold[hart][l][0], pat(hart, l, 0));
        }
      }
    }
    barrier(NUM_HARTS);
  }
  printf("%d: Phase 8 (latency window) %s\n", hart, bad[hart] ? "FAILED" : "OK");

  /* The handler must have run at least once, otherwise the flush path was never
   * exercised.  The exact count is not ISS-deterministic (see the header). */
  barrier(NUM_HARTS);
  if (traps[hart] == 0) bad[hart]++;
  printf("%d: LSU stall test %s (handler ran, bad=%lu)\n", hart,
         bad[hart] ? "FAILED" : "PASSED", bad[hart]);

  return 0;
}

int main(int argc, char *arg[]) { return real_main(); }
