// Copyright 2026 Comissariat a l'Energie Atomique et aux Energies
//                Alternatives (CEA)
//
// Licensed under the Solderpad Hardware License, Version 2.1 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, software
// and materials distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied. See the License for the specific language governing
// permissions and limitations under the License.
//
// Description: Bridge between the classic CVA6 fetch protocol (the four
// address-translation / data request-response structs used by the
// cacheless pipeline) and the YPB fetch protocol of the hpicache L1
// instruction cache. The bridge implements the request-side protocol of
// the classic cva6_icache: one outstanding fetch, translation requested
// to the core through areq_o/areq_i, data returned on the s2 side with
// kill_s2 gating.

module cva6_fetch_bridge
//  Parameters
//  {{{
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type icache_areq_t = logic,
    parameter type icache_arsp_t = logic,
    parameter type icache_dreq_t = logic,
    parameter type icache_drsp_t = logic,
    parameter type ypb_fetch_req_t = logic,
    parameter type ypb_fetch_rsp_t = logic
)
//  }}}

//  Ports
//  {{{
(
    input  logic clk_i,
    input  logic rst_ni,

    //  Cache management - CSR_REGFILE
    input  logic flush_i,
    input  logic en_i,

    //  Fetch request/response - FRONTEND
    input  icache_areq_t areq_i,
    output icache_arsp_t areq_o,
    input  icache_dreq_t dreq_i,
    output icache_drsp_t dreq_o,

    //  Fetch request/response - hpicache (YPB)
    output ypb_fetch_req_t ypb_fetch_req_o,
    input  ypb_fetch_rsp_t ypb_fetch_rsp_i
);
//  }}}

  //  Internal state: one outstanding fetch
  //  {{{
  logic busy_q;         // a fetch request is in flight
  logic trans_q;        // physical address granted, physical request pending
  logic granted_q;      // physical request accepted, awaiting data
  logic ex_q;           // latched fetch exception
  logic ex_valid_q;     // exception response cycle
  logic flush_q;        // cache flush in progress
  logic [CVA6Cfg.PLEN-1:0] paddr_q;  // latched translated address
  logic [CVA6Cfg.VLEN-1:0] vaddr_q;  // latched virtual address of the in-flight fetch
  logic killed_q;         // the in-flight request was killed by the core
  //  }}}

  logic idle;
  assign idle = !busy_q && !flush_q;

  //  Request side: the core keeps the request alive until data returns
  //  {{{
  // Translation request: issued while idle, served by the core MMU
  assign areq_o.fetch_req   = busy_q && !trans_q && !granted_q && !ex_q;
  //  The address must be the one of the request in flight: the frontend
  //  derives the re-alignment shift amount and the instruction PCs from it.
  assign areq_o.fetch_vaddr = vaddr_q;

  // The core accepts a new request when the bridge is idle.
  //  A request must not be accepted in a cycle where the core kills the
  //  fetch (branch misprediction, replay or the pipeline flush that a CSR
  //  write / AMO / fence.i triggers at commit): the address the core puts
  //  on the request side in such a cycle is the one it is about to
  //  discard, so latching it would return a stale word right after the
  //  flush and push an already retired instruction a second time into the
  //  instruction queue.  The classic cva6_icache behaves the same way --
  //  it leaves its lookup states on kill_s1 and only asserts ready in IDLE.
  assign dreq_o.ready = idle && !(dreq_i.kill_s1 || dreq_i.kill_s2);
  //  }}}

  //  YPB request driving - {{{
  logic pma_cacheable, pma_bufferable;
  assign pma_cacheable = config_pkg::is_inside_cacheable_regions(
      CVA6Cfg, {{64 - CVA6Cfg.PLEN{1'b0}}, paddr_q}
  );
  assign pma_bufferable = !config_pkg::is_inside_nonidempotent_regions(
      CVA6Cfg, {{64 - CVA6Cfg.PLEN{1'b0}}, paddr_q}
  );

  always_comb begin
    ypb_fetch_req_o = '0;
    // Virtual request: mirrors the core request (self-granted)
    ypb_fetch_req_o.vreq         = dreq_i.req | busy_q;
    ypb_fetch_req_o.vaddr        = vaddr_q;
    // Physical request: armed once the translation returned
    ypb_fetch_req_o.preq         = busy_q && trans_q && !flush_q;
    ypb_fetch_req_o.paddr        = paddr_q;
    ypb_fetch_req_o.be           = '1;
    ypb_fetch_req_o.size         = 2'(CVA6Cfg.FETCH_ALIGN_BITS);
    ypb_fetch_req_o.we           = 1'b0;
    ypb_fetch_req_o.wdata        = '0;
    ypb_fetch_req_o.aid          = '0;
    ypb_fetch_req_o.atop         = ariane_pkg::AMO_NONE;
    ypb_fetch_req_o.cbo_op       = ariane_pkg::CBO_NONE;
    ypb_fetch_req_o.access_type  = '0;  // 0 = fetch
    ypb_fetch_req_o.cacheable    = pma_cacheable;
    ypb_fetch_req_o.bufferable   = pma_bufferable;
    //  Never abort: the cache either answers the request or drops it, and the
    //  bridge cannot tell which.  Abandoning a request the cache still answers
    //  would let that answer be taken for the response of the NEXT request,
    //  i.e. deliver the word of another address, and shift the instruction
    //  stream.  A fetch has no side effect, so let it complete and discard the
    //  data instead (see killed_q below); the request/response pairing then
    //  stays one to one.
    ypb_fetch_req_o.kill_req     = 1'b0;
    ypb_fetch_req_o.rready       = 1'b1;  // always ready
  end
  //  }}}

  //  Response side: data and exception return to the core
  //  {{{
  //  A killed request must not produce a response: the core has already
  //  discarded the corresponding fetch and re-requests the new address.
  //  Same behaviour as the classic cva6_icache (dreq_o.valid = ~kill_s2).
  //  The kill must be sampled both registered (kill while waiting for the
  //  response) and combinationally (kill in the very cycle the response
  //  arrives) -- otherwise the response is latched into the front-end one
  //  cycle before the flush reaches instr_realign, which then keeps a stale
  //  half-word for an instruction spanning two fetch words.
  assign dreq_o.valid = ((granted_q && ypb_fetch_rsp_i.rvalid && !flush_q) ||
                         ex_valid_q) && !killed_q && !dreq_i.kill_s1 && !dreq_i.kill_s2;
  assign dreq_o.data  = ex_valid_q ? '0 : ypb_fetch_rsp_i.rdata;
  assign dreq_o.user  = '0;
  assign dreq_o.vaddr = vaddr_q;  // address the returned data belongs to
  assign dreq_o.ex    = ex_valid_q ? ex_q : areq_i.fetch_exception;
  //  }}}

  //  State machine
  //  {{{
  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      busy_q     <= 1'b0;
      trans_q    <= 1'b0;
      granted_q  <= 1'b0;
      ex_q       <= 1'b0;
      ex_valid_q <= 1'b0;
      flush_q    <= 1'b0;
      paddr_q    <= '0;
      vaddr_q    <= '0;
      killed_q   <= '0;
    end else begin
      //  Flush management: one-cycle invalidation window; the cache array
      //  flush progresses in parallel and gates the physical request grant
      flush_q <= flush_i;

      //  Request acceptance: start translation (except during flush).
      //  This must use exactly the same condition as dreq_o.ready below:
      //  accepting a request in a cycle where the core is told "not ready"
      //  (i.e. while it kills the fetch) makes the bridge answer a request
      //  the core believes it never issued.  That response then reaches the
      //  instruction queue after the flush, as a duplicate of an already
      //  retired word, and the queue keeps its own PC for it -> the whole
      //  stream gets shifted by one word.
      if (dreq_o.ready && dreq_i.req) begin
        busy_q  <= 1'b1;
        vaddr_q  <= dreq_i.vaddr;
        //  The new request starts from a clean state: the caches' answer to a
        //  previous request has been drained (granted_q is only cleared when
        //  the data returns), so no stale response can be pending here.
        trans_q    <= 1'b0;
        granted_q  <= 1'b0;
        ex_q       <= 1'b0;
        ex_valid_q <= 1'b0;
        killed_q   <= 1'b0;
      end

      //  A kill from the core invalidates the response of the request in flight
      if ((busy_q || trans_q || granted_q) && (dreq_i.kill_s1 || dreq_i.kill_s2))
        killed_q <= 1'b1;

      //  Translation return: latch exception or arm the physical request
      if (busy_q && !trans_q && !granted_q && areq_i.fetch_valid) begin
        if (areq_i.fetch_exception.valid) begin
          ex_q <= 1'b1;
        end else begin
          paddr_q <= areq_i.fetch_paddr;
          trans_q <= 1'b1;
        end
      end

      //  Physical request grant from the cache
      if (trans_q && ypb_fetch_rsp_i.pgnt) begin
        trans_q   <= 1'b0;
        granted_q <= 1'b1;
      end

      //  Early kill of the in-flight translation request
      if (busy_q && !trans_q && !granted_q && !ex_q && dreq_i.kill_s1) begin
        busy_q <= 1'b0;
      end

      //  Data return.  The bridge must wait for the answer of every request it
      //  issued, even a killed one: it never aborts (see kill_req above), so a
      //  request left unanswered would have its data taken for the answer of
      //  the next request, and the core would get the word of another address
      //  at the right PC.  The data of a killed request is simply discarded.
      if (granted_q) begin
        if (ypb_fetch_rsp_i.rvalid) begin
          granted_q <= 1'b0;
          busy_q    <= 1'b0;
        end
      end

      //  Exception return: single-cycle response, bypasses the cache array
      if (ex_q) begin
        ex_q       <= 1'b0;
        ex_valid_q <= 1'b1;
        busy_q     <= 1'b0;
      end else if (ex_valid_q) begin
        ex_valid_q <= 1'b0;
      end

      //  Flush takes precedence over request acceptance
      if (flush_q) begin
        busy_q <= 1'b0;
      end
    end
  end
  //  }}}

endmodule
