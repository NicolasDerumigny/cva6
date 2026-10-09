# load-unit-fix.md — notes for the next agent working on this fork

Handoff notes from the dual-core HPDCACHE_WT load-unit work. The FPGA board now runs the fixed
load unit, so the functional part is done. The observability probes have since been **removed from
the RTL** (§4), so what remains is coverage, the value-regression gap described in §6, and some
harness rough edges that will bite you again.

Read this before touching `core/load_unit.sv`: most of the traps below are not obvious from the
code alone, and several were learned by running simulations, not by reading.

---

## 1. Scope and ground rules

- **Scope**: the Xilinx FPGA block-design flow (not the non-BD / hybrid flow), HPDCache multicore
  configuration, 2 harts. Config traced from `cv64a6_zcu104_sv39`.
- This is a **custom fork**: do not search online for "the dual-core CVA6 bug". The issue is
  specific to this fork's geometry and to the arbiter contract; solve it by reading the RTL.
- The user handles the tcl / Vivado side. You only check or correct the RTL. The probe ports are
  gone (§4); if they are ever re-added they must be **fixed widths** so they can become
  block-design ports (ILA friendly).
- The user is happy to help (board access, re-runs). Ask rather than guess when a claim needs the
  board or a long simulation.

---

## 2. The bug and the fix

Committed as `03bab513e fix(load_unit): correctly handle hpdcache/kill request`
(parent `2000196fd`). Four distinct defects relative to the parent:

1. **Flush drops a presented-but-not-accepted request.** `WAIT_FLUSH` with `data_req = 0` breaks
   the arbiter contract ("once `valid == 1` it stays valid until `ready`"), so the abort applies
   to whatever request passes stage 0 later instead of the one the LSU actually presented.
   Fixed by `WAIT_GNT_FLUSH`: hold until acceptance, then assert `kill_req` in the second cycle,
   then `IDLE`. Deadlock-free because `need_rsp = 1` on the load port. No arbiter change needed.
2. **`ldbuf_r` consumes a response for a slot the LSU never allocated** → stale `trans_id_o` →
   phantom writeback.
3. **The kill was only honoured in the same cycle as the response**, so a later response for a
   killed slot was written back.
4. **Flush raised the discard flag on every slot, including free ones.** A flag on a free slot can
   never be cleared (no response will come to free it), so the next load allocated there is
   silently dropped and the LSU hangs. This is what caused the boot deadlock on the board.

Key invariants that the fix encodes (keep them, they are the reason it works):

- `ldbuf_w` **must still fire for a killed request** — it reserves the slot. Gating `ldbuf_w` with
  `!flushing` is wrong; that was tried and rejected.
- The kill applies to the slot recorded in the **previous** cycle (`ldbuf_last_id_q`, guarded by
  `ldbuf_w_q`), never to the slot being allocated in the same cycle, because the abort is evaluated
  in stage 1 for the request that passed stage 0 in the previous cycle. A kill presented with
  `ldbuf_w_q = 0` is a legitimate no-op.
- The per-slot flag must not be cleared for a killed slot, and it is cleared only at allocation.
- Flush raises the flag only on **outstanding** slots (`|= ldbuf_valid_d`).
- The cache answers an aborted request in stage 1 (`hpdcache_ctrl_pe.sv:456`), so the abort
  response can arrive in the **same cycle** as the abort; the kill writer skips a slot freed in the
  same cycle.
- In `rvalid_output`, the **exception branch must not be gated by the same-cycle kill term**: in
  `SEND_TAG` the kill we present this cycle *is* this exception, and its response comes in the same
  cycle, so gating it prevents the fault from ever retiring while the slot is freed by that same
  response → the instruction stays in the load queue forever → hang. (This was not a bug in the
  parent commit; it was introduced by an intermediate version of the fix.)
- `sdtrig_load_cancel_i` was the only contract violation. It is now restructured: the FSM case runs
  first, the trigger only clears `translation_req_o` / `pop_ld_o`, and a unified kill block handles
  `flush_i | sdtrig_load_cancel_i`.
- The assertions in the `pragma translate_off` block encode these invariants: `rvalid_slot`,
  `kill_slot`, `kill_not_on_new_slot`, `flag_on_outstanding`, `free_slot_no_flag`,
  `exception_in_send_tag_retires` (plus the three pre-existing address-offset checks). They are
  `$fatal`, so a violation ends the simulation rather than printing and continuing.

FSM encoding (the enum order, which the ILA decode needs if probes are ever re-added):

```
IDLE=0, WAIT_GNT=1, SEND_TAG=2, WAIT_PAGE_OFFSET=3, ABORT_TRANSACTION=4,
ABORT_TRANSACTION_NI=5, WAIT_TRANSLATION=6, WAIT_FLUSH=7, WAIT_GNT_FLUSH=8,
WAIT_WB_EMPTY=9, WAIT_SPEC_LOAD=10
```

---

## 3. Arbiter semantics you must not re-derive

- `hpdcache_fxarb.sv`: `gnt_o = wait_q ? gnt_q : gnt`; `gnt` is a pure priority encode of `req_i`,
  **not** gated by `ready_i`. `gnt_q` is latched only when `!ready_i && !wait_q && |req_i`.
  `wait_q` stays 1 while `ready_i` is low even if `|req_i = 0`, so `arb_req_valid_o` can be 1 with
  no live request. Load port has higher fixed priority than the store/AMO port.
- `hpdcache_core_arbiter.sv:91`: `core_req_ready_o[p] = arb_req_gnt_d[p] & arb_req_ready_i`; the
  abort multiplexor selects on `arb_req_gnt_q` (the previous cycle's grant).
- `cva6_hpdcache_if_adapter.sv:117` and `:342`: `data_gnt = hpdcache_req_ready_i`. This is why the
  LSU can never consider a slot owned while the cache did not accept the request — see §6.
- `sid` mapping: `__idx(r, HartId) = r * NrHarts + HartId`, `nRequesters = 8` (`NumPorts = 4` per
  hart). Per hart: MMU(0), load unit(2, the accelerator), store/AMO(3). So bit 3 of the 8-bit grant
  vector is the load unit of hart 1.
- `dcache_flush_ctrl_cache` (the CSR-driven Dcache flush request, `core/cva6_multicore.sv:225`) is
  permanently 0 because `CVA6ConfigDcacheFlushOnFence = 0` and `CVA6ConfigDcacheFlushOnFenceI = 0`
  in the zcu104 config, so `WAIT_FLUSH` is a one-cycle pulse and the only way to reach it is a
  pipeline flush (`flush_i` from commit). `data_gnt` without `pop_ld` is normal only when
  `!dtlb_hit_i` (→ `ABORT_TRANSACTION`) or `stall_ni`.

---

## 4. Probe path — removed from the RTL

The LSU observability probes are no longer in the code. `ariane_pkg::lsu_probe_t`, the `lsu_probe_o`
port on `load_unit.sv`, the multicore plumbing, and the flattened block-design ports in
`corev_apu/fpga/src/verilog_wrappers/ariane/cva6_wrapper.sv` and
`block_design_wrappers/cva6_wrapper_verilog.v` were all removed; those files are back to their
committed state. Board observability is now Vivado's internal debug probes on the BD cell, or the
assertions in simulation.

What to keep in mind:

- Do not trust `corev_apu/fpga/work-fpga/ariane_funcsim.v`: it is a stale generated netlist that
  still contains the probe ports. Regenerate it before reading anything from it.
- If the probes are re-added, the struct cannot use `CVA6Cfg`-dependent widths — fixed widths are
  mandatory for BD ports. The widths previously hard-coded from the zcu104 geometry were
  `NrLoadBufEntries = 8`, `DcacheIdWidth = 3`, `TRANS_ID_BITS = 3`.
- `accept_req` is an automatic variable inside the FSM, so a probe has to recompute it with the same
  expression rather than move it out of the `always_comb`.
- The response probe was the arbiter response **inputs** (`core_rsp_valid_i` / `core_rsp_i`), and the
  grant vector is `[7:0]` = `nRequesters = 8`, same index mapping as `sid`.
- ILA must be clocked on `aclk`. The tcl side is the user's job.

The set that proved worth observing, in case it comes back: `state`(4), `data_req`, `data_gnt`,
`data_rvalid`, `data_rid`(3), `data_id`(3), `kill_req`, `pop_ld`, `accept_req`, `ldbuf_valid`(8),
`ldbuf_discard`(8), `ldbuf_free_index`(3), `ldbuf_w`, `ldbuf_r`, `ldbuf_full`, `ldbuf_empty`,
`page_offset_matches`, `is_speculative_load`, `is_speculative_load_miss`, `trans_id_o`(3),
`valid_o`.

Still undecided, only relevant if probes come back:
- Optional additions: `dtlb_hit_i`, `stall_ni`, `valid_i`, fxarb `wait_q`/`gnt_q`, and the six
  `ready_i` blockers (`rtab_full`, `cmo_busy`, `uc_busy`, `rtab_busy`, `mshr_empty`, `wbuf_empty`).
- Two-flag shape: merged `ldbuf_discard` vs. `ldbuf_flushed` + `ldbuf_killed`. The merged flag is
  what is committed, so the *cause* of a discard is not observable without splitting it.

---

## 5. Latency knob

The C test cannot control the request latency it sees: the model's memory round trip is 3 cycles,
so a `uc_busy` window is 3 cycles long and the LSU is never held more than one cycle. The knob
lives on the harness, on `axi_delayer_intf`
(`corev_apu/tb/ariane_testharness.sv`, params `FixedDelayInput` / `FixedDelayOutput`, default 0).
Delaying the read-response channel keeps the uncached handler busy for N cycles, which makes
`rtab_full` reachable and opens the stall windows. `stream_delay` uses a 4-bit counter → usable
range **0..15**.

It is a make / cva6.py variable:
- `verif/sim/Makefile`: `export VERILATOR_FIXED_DELAY_INPUT ?= 0`,
  `export VERILATOR_FIXED_DELAY_OUTPUT ?= 0`, and `VERILATOR_PARAMS += -GNR_CORES=... -GFixedDelay...`.
- `verif/sim/cva6.py`: `--mem_input_delay` / `--mem_output_delay`, appended to the make command by
  `get_iss_cmd` as `VERILATOR_FIXED_DELAY_INPUT=<n> VERILATOR_FIXED_DELAY_OUTPUT=<n>`.
- **Known bug**: the `veri-testharness` and `veri-testharness-pk` recipes interpolate
  `$(VERI_PARAMS)`, which is never defined — the defined variable is `VERILATOR_PARAMS`. `make -n`
  shows the Verilator command with no `-G` parameters at all, so the delay from cva6.py does not
  reach the build. Until that is fixed, pass the delay through `VERILATOR_EXTRA_ARGS` or build
  Verilator directly. (The end-to-end effect was measured before the rename, when the parameters
  were actually passed: 1.25M cycles at delay 12 vs ~410k at 0.)

The ISS does not model the latency, so a reference stays valid for any value: only timing changes,
not the architectural result.

---

## 6. Benches

Neither bench is in the committed regress script: `verif/regress/multicore-tests-cv64a6_imafdc_sv39.sh`
runs only `hello_world`, `lr_sc` and `clint`. They are in the untracked
`verif/regress/multicore-tests-cv64a6_zcu104_sv39.sh`, which runs both on the zcu104 target with
`--mem_input_delay=15 --mem_output_delay=15`.

### `verif/tests/multicore/lsu_stall/lsu_stall.c` (8 phases) — passes for both harts
Phases: 1 `uc_busy` + `WAIT_GNT` + `ldbuf_full`; 2 store→load same line; 3 mispredicted branch +
pending store; 4 `rtab_full`; 5 `WAIT_PAGE_OFFSET`; 6 DTLB miss / `ABORT_TRANSACTION`;
7 `WAIT_GNT_FLUSH`; 8 latency window. Reference
`verif/tests/multicore/references/lsu_stall` (20 lines) reports `[PASSED]: 20 matched`. Output is
byte-identical across runs apart from hart line order within a phase. Verified at default latency,
at delay 12, and with larger pressure knobs — but only when Verilator is built directly, since the
regress path does not pass the delay (§5).

### `verif/tests/multicore/lsu_kill_value/lsu_kill_value.c` (4 phases) — passes at latency 0 and 12
Value checks, not hang checks: phase 1 exception kill in `SEND_TAG` (faulting load must leave the
sentinel), phase 2 killed response vs reused slot, phase 3 store then load another word with a kill
between, phase 4 kill storm on both slots. Reference
`verif/tests/multicore/references/lsu_kill_value` (10 lines, `[01]` hart id) reports
`[PASSED]: 10 matched`.

**Important limitation, do not oversell this bench:** it does **not** exhibit the wrong-value bug.
It passes on both the pre-fix `load_unit.sv` (`2000196fd`) and the fixed one, at latency 0 and 12.
Bugs 2 and 3 need a response for a slot the LSU considers free, which cannot happen because
`cva6_hpdcache_if_adapter.sv:117/342` sets `data_gnt = hpdcache_req_ready_i`, so `ldbuf_w` only
fires for a request the cache actually accepted. The bench is coverage/stress, not a regression test
for the wrong value. The only observable pre-fix defect is the flush flag raised on free slots,
which fires during boot with the assertion build (`free_slot_no_flag`), and it is cleared at
reallocation so it cannot reach a value.

To make it a real regression test, find a scenario where the LSU owns a slot while a killed
request's response arrives — the original trace's shape: store hit + load to a different word +
pending wbuf entry + mispredicted branch. That needs the zcu104 geometry (`NrLoadBufEntries = 8`,
`DcacheIdWidth = 3`). Note that `tid '0` is the flush ack and `tid '1` the AMO ack, both on the
store/AMO port (`cva6_hpdcache_if_adapter.sv:179` and `:344`): the load port can never receive a
flush, which `flush_on_load_port_assert` enforces, so the LSU's flush is only the internal discard
flags.

### Test-writing rules (learned the hard way)
- Must be **ISS-deterministic**: reference files are regex lists compared by `compare_text_regexp`
  (`verif/sim/cva6_compare_text_traces.py`). One line per printed line; each phase prints one line
  per hart, so the reference needs two `[01]` lines per phase.
- Trap handlers must **not** print (`printf` is lock-protected; the lock may be held by the
  preempted hart, and cross-hart print order is nondeterministic). Use a print ticket or a barrier
  per phase.
- Never read `MTIME` (nondeterministic). `MTIMECMP` / `MSIP` reads are deterministic.
- Trap count is not printed: MSIP is cleared by an asynchronous store, so the handler can re-fire →
  not ISS-deterministic. Only "handler ran at least once" is checked. Page-fault counts are
  deterministic.
- Value checks use an explicit `asm volatile("ld %0, 0(%1)" : "+r"(got) ...)` with `"+r"` so the
  sentinel is really in the destination register; a faulting load must leave the sentinel.
- Expected values come from a `shadow[NUM_HARTS][NLINES][LINE_WORDS]` mirror of the memory model,
  not from `pat()`, because earlier phases store into lines later phases read.
- Pressure knobs are `#ifndef`-guarded for `-D` overrides: `UC_ITERS` 64, `LOAD_ITERS` 32,
  `PO_ITERS` 24, `TLB_ITERS` 16, `FLUSH_ITERS` 24, `LATENCY_ROUNDS` 8, `OUTSTANDING` 2,
  `PRESSURE_ROUNDS` 4, `FAULT_ITERS` 16, `KILL_ITERS` 24. They change internal timing only, never
  the printed output.

---

## 7. Traps that will bite you again

- **`mcause` has the high bit set only for interrupts in this fork.** An exception reads as `13`,
  not `0x800000000000000D`. Handlers must compare `cause == 13`. Verified empirically.
- **Step `mepc` by the actual instruction size**, not a fixed 4: the test is compiled with the C
  extension, so the faulting load can be 2 bytes. Use bit 1 of the first opcode byte via byte
  loads — a `lh`/`lw` at an address ≡ 2 mod 4 would itself fault in CVA6. Getting this wrong
  produced a bogus `ST_ADDR_MISALIGNED exception @ 0x800033ec (0xfef4)` with `mtval = 0xf9` at a
  non-instruction boundary.
- Tests run in **S-mode via a manual `mret` entry** (must set `MPP = S`:
  `csr_clear(CSR_MSTATUS, SR_MPP|SR_MPRV); csr_set(CSR_MSTATUS, SR_MPP_S)`) so `mideleg` can be
  written in M-mode and left at 0; the interrupt is then taken in M-mode by a naked handler that
  `mret`s back to S-mode. Required because translation is disabled in M-mode
  (`core/csr_regfile.sv:2809`).
- The **S-mode software interrupt is unusable here**: `mideleg` writes are masked to
  `MIP_SSIP | MIP_STIP | MIP_SEIP` = bits 1, 5, 9 (`core/csr_regfile.sv:1697`), so `IRQ_M_SOFT = 3`
  can never be delegated, and the CLINT MSIP drives `MIP_MSIP = 1 << IRQ_M_SOFT`. An
  MSIP-triggered software interrupt is therefore always taken in M-mode.
- `trap_entry` is a local label in `crt.S` and cannot be referenced from C, so tests use their own
  naked handler.
- The MSIP store reaches the CLINT asynchronously (store buffer), so `sip`/`mip` read immediately
  after the store shows SSIP = 0.
- The DTLB-hit permission fault requires the DTLB to already hold the page, so the test uses a
  **user alias page** (`satp_lvl3[0x1]`, VA `0x4000_0000` → PA `0x8000_0000`) and toggles
  `sstatus.SUM` (bit 18, in both read and write masks): SUM = 1 populates the DTLB, SUM = 0 faults
  on the hit. The RAM mega-page itself must **not** be a user page — with SUM = 0 an instruction
  fetch from a user page faults (cause 12) on the test's own code.
- **Verilator silently drops `$fwrite(2, …)`** (stderr) and this harness does not execute `final`
  blocks, so coverage prints must go to stdout — which interleaves with the test's prints and would
  break the reference. Writing to a file via `$fopen`/`$fwrite` works as a workaround.
- **`verif/sim/Makefile` `veri-testharness` is hardcoded to `$(path_var)/work-ver/Variane_testharness`**
  (not `$(ver-library)`), and Verilator's `work-ver` cache is not rebuilt automatically, so a stale
  binary can silently serve a run. This already caused the zcu104 regress to run the stale imafdc
  binary. Rebuild `work-ver` explicitly when you change parameters.
- Spike cannot be used standalone for 2 harts (`-p2` creates a second RV32 proc); the reference
  must come from the Verilator run.
- The `emulate_syscall` bounds guard (`corev_apu/tb/dpi/syscalls.cc`, committed as `af8762d15`,
  `SyscallHandler::is_ram_addr` on `tohost`, `fromhost` and the `write()` buffer address `arg1`)
  cannot itself end the simulation — `rvfi_tracer.sv` only sets `end_of_test_d` for a tohost value
  with bit 0 set. It stops the segfault, nothing more.

---

## 8. Working commands

Compile a multicore test:

```bash
$RISCV_CC -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles -g <test.c> \
  -I verif/sim/dv/user_extension -I verif/tests/multicore/env -I verif/tests/multicore/common \
  verif/tests/multicore/common/syscalls.c verif/tests/multicore/common/vm.c \
  verif/tests/multicore/common/crt.S verif/tests/multicore/common/page_table.s \
  -T verif/tests/multicore/common/main.ld -nostdlib -lgcc \
  -march=rv64gc_zba_zbb_zbs_zbc_zbkb_zbkx_zkne_zknd_zknh_zicbom -mabi=lp64d -DNUM_HARTS=2 -o <elf>
```

`objdump` is `$RISCV/bin/riscv-none-elf-objdump`.

Harness build and run:

```bash
make verilate target=cv64a6_imafdc_sv39 CVA6_NR_HARTS=2 \
  verilator="verilator --no-timing --assert -GNR_CORES=2 -GFixedDelayOutput=<N>"
./work-ver/Variane_testharness <elf> +debug_disable=1
```

Verilator needs `--assert` for the SVA in `load_unit.sv`. Latency runs need a longer timeout
(~1.7M cycles).

The regress script must be launched by sourcing `set-env.sh` first (RISCV must be set). The
committed `verif/regress/multicore-tests-cv64a6_imafdc_sv39.sh` runs `hello_world`, `lr_sc` and
`clint`; the LSU benches are only in the untracked zcu104 script (§6).

Lint:

```bash
P=/home/derumigny/FPGA/cva6
sed -e "s|\${HPDCACHE_DIR}|$P/core/cache_subsystem/hpdcache|g" \
    -e "s|\${CVA6_REPO_DIR}|$P|g" \
    -e 's|\${TARGET_CFG}|cv64a6_imafdc_sv39|g' core/Flist.cva6 \
  | sed 's|-F .*hpdcache.Flist|-F /tmp/opencode/hpd_flist.txt|' > /tmp/opencode/flist.txt
sed "s|\${HPDCACHE_DIR}|$P/core/cache_subsystem/hpdcache|g" \
    core/cache_subsystem/hpdcache/rtl/hpdcache.Flist > /tmp/opencode/hpd_flist.txt
verilator --lint-only -Wall --top-module cva6_multicore -Wno-fatal --timing -f /tmp/opencode/flist.txt
```

Verilator does **not** expand `${...}` in a command file, so both `core/Flist.cva6` and the nested
`hpdcache.Flist` must be expanded (the nested one is what makes `hpdcache_typedef.svh` resolvable).
Last run on this target: no errors, ~1390 `-Wall` warnings, and **no `UNOPTFLAT` on `load_unit.sv`**
(the `UNOPTFLAT` warnings are in `decoder.sv`, `hpdcache.sv` and the store if adapter). Two width
warnings come from the assertions themselves (`load_unit.sv:720` SEL width, `load_unit.sv:735`
`1'(ldbuf_r) << ldbuf_rindex`); they are cosmetic, do not "fix" them by changing the assertion.
`corev_apu/fpga/src/verilog_wrappers/ariane/cva6_wrapper.sv` cannot be linted because the
`register_interface` submodule is not checked out.

---

## 9. Geometry

Both targets use `HPDCACHE_WT`, and the hpdcache params are derived from the CVA6 config by
`hpdcacheSetConfig()` in `core/cache_subsystem/cva6_multicore_hpdcache_subsystem.sv`. Common to
both: `rtabEntries = 4`, `wbufWords = 1`, `reqSrcIdWidth = 3`, `lowLatency = 1`,
`nRequesters = 8` (`NumPorts = 4` × 2 harts), `LDBUF_FALLTHROUGH = 0`, `Sdtrig = 0`,
`SuperscalarEn = 0` → `SpeculativeSb = 0` → `WAIT_SPEC_LOAD` is unreachable, CLINT at
`0x0200_0000` is outside the cached region → `uc_busy` is reachable.

**zcu104** (`core/include/cv64a6_zcu104_sv39_config_pkg.sv`): XLEN 64, PLEN 56, AxiIdWidth 4,
MemTidWidth 4, DcacheByteSize 32768, SetAssoc 8, DcacheLineWidth 512 → clWords 8 and 8 sets,
DcacheIdWidth 3, NrLoadBufEntries 8 → mshrSets 1 / mshrWays 8, WtDcacheWbufDepth 8 →
wbufDirEntries 8. `NonIdemPotenceEn = 1` (1 rule, length `0x8000_0000`), so `ABORT_TRANSACTION_NI`
and `WAIT_WB_EMPTY` are reachable. Cached region `0x8000_0000` + `0x2_0000_0000`.

**imafdc** (`core/include/cv64a6_imafdc_sv39_hpdcache_config_pkg.sv`): DcacheLineWidth 128 →
clWords 2 and 32 sets, DcacheIdWidth 3, NrLoadBufEntries 8, MemTidWidth 4, WtDcacheWbufDepth 8,
`NonIdemPotenceEn = 0` (`NonIdempotentLength = 0`) → the NI states are unreachable on this target.
Cached region `0x8000_0000` + `0x4000_0000`.

With latency 0 `rtab_full` cannot block the load port (2 + 2 = rtabEntries exactly); it becomes
reachable only with the latency knob.

CLINT map: `CLINT_BASE 0x02000000`, MSIP `+0x0000+4*h`, MTIMECMP `+0x4000+8*h`, MTIME `+0xBFF8`.
A 32-bit read at offset 4 always reads 0.

---

## 10. Trace evidence for the original bug (keep this, it is the only ground truth)

Two requests from `sid = 3` (load unit of hart 1): first `0x1d8` (word 3, the store's address),
second `0x1d0` (word 2, the real load). The first was never killed. Two responses with the same
`sid`, only the first (wrong) one registered. `phys_indexed = 0` for both ⇒ both came from the load
port. `PMA = 0x01` is a constant (the adapter hardcodes `HPDCACHE_WR_POLICY_AUTO`); with
`cfg_default_wb_i = 0` AUTO resolves to WT.

---

## 11. State of the working tree and next moves

**Committed** (as of 2026-10-13): `03bab513e` (LSU fix + assertions), `653c0e811` (the relaxed
`MEM_TID_WIDTH` assertion + the hpdcache submodule pointer), `af8762d15` (the syscall bounds guard),
`ea720d8c1` (the S/U-mode multicore test harness: `vm.c`, `main.ld`, `page_table.s`, `trampoline.h`,
`types.h`, `util.h`), `f889eabb0` (the latency parameters and the linker file in the test infra),
`2dd82aa04` (the xbar wrapper AXI ID defaults). Everything probe-related is reverted.

**Untracked**: this note, `verif/regress/multicore-tests-cv64a6_zcu104_sv39.sh`, the two benches
(`lsu_stall`, `lsu_kill_value`) and their references.

Next moves:

1. Fix the `VERI_PARAMS` / `VERILATOR_PARAMS` mismatch in `verif/sim/Makefile` (§5): as committed,
   the latency never reaches the Verilator build, so the zcu104 regress script's
   `--mem_input_delay=15 --mem_output_delay=15` has no effect.
2. Re-run the benches with `--assert` at delay 12 and confirm the assertions stay quiet under real
   stall windows — they are the only observability of the kill path now.
3. Close the value-regression gap in §6: find a scenario where the LSU owns a slot while a killed
   request's response arrives, so the bench fails on the pre-fix code. Without that, the bench is
   coverage only and nothing in the repo can catch a regression of bugs 2 and 3.
4. Commit the benches, their references, and the zcu104 regress script.
5. Decide whether the probes come back and whether the discard flag is split (§4).

---

## 12. A note to the next self

The board works now, and that came from refusing to "fix" the code by pattern-matching: the shape of
the fix is entirely determined by two facts you cannot see in one file — the arbiter contract
(`valid` stays until `ready`) and the fact that the abort is evaluated one cycle after acceptance.
Keep the assertions in `load_unit.sv`: they are the invariant, not decoration. Now that the probes
are gone they are also the only observability of the kill path, so a run without `--assert` sees
nothing. Do not weaken an assertion to make a run pass; if it fires, either the code or the
assumption is wrong, and the assumption is usually the interesting one.
