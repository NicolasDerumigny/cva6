// Copyright 2023 Commissariat a l'Energie Atomique et aux Energies
//                Alternatives (CEA)
//
// Licensed under the Solderpad Hardware License, Version 2.1 (the “License”);
// you may not use this file except in compliance with the License.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// You may obtain a copy of the License at https://solderpad.org/licenses/
//
// Authors: Cesar Fuguet
// Date: February, 2023
// Description: AXI arbiter for the CVA6 cache subsystem integrating standard
//              CVA6's instruction cache and the Core-V High-Performance
//              L1 Dcache (CV-HPDcache).

module cva6_multicore_hpdcache_subsystem_axi_arbiter
//  Parameters
//  {{{
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type hpdcache_mem_id_t = logic,
    parameter type hpdcache_mem_req_t = logic,
    parameter type hpdcache_mem_req_w_t = logic,
    parameter type hpdcache_mem_resp_r_t = logic,
    parameter type hpdcache_mem_resp_w_t = logic,
    parameter type icache_req_t = logic,
    parameter type icache_rtrn_t = logic,

    parameter int unsigned NrHarts = 1,

    parameter int unsigned AxiAddrWidth = 1,
    parameter int unsigned AxiDataWidth = 1,
    parameter int unsigned AxiIdWidth = 1,
    parameter int unsigned AxiUserWidth = 1,
    parameter type axi_ar_chan_t = logic,
    parameter type axi_aw_chan_t = logic,
    parameter type axi_w_chan_t = logic,
    parameter type axi_b_chan_t = logic,
    parameter type axi_r_chan_t = logic,
    parameter type axi_req_t = logic,
    parameter type axi_rsp_t = logic
)
//  }}}

//  Ports
//  {{{
(
    input logic clk_i,
    input logic rst_ni,

    //  Interfaces from/to I$
    //  {{{
    input  logic             [NrHarts-1:0] icache_miss_valid_i,
    output logic             [NrHarts-1:0] icache_miss_ready_o,
    input  icache_req_t      [NrHarts-1:0] icache_miss_i,
    input  hpdcache_mem_id_t [NrHarts-1:0] icache_miss_id_i,

    output logic         [NrHarts-1:0] icache_miss_resp_valid_o,
    output icache_rtrn_t [NrHarts-1:0] icache_miss_resp_o,
    //  }}}

    //  Interfaces from/to D$
    //  {{{
    //      Read interface
    output logic              dcache_read_ready_o,
    input  logic              dcache_read_valid_i,
    input  hpdcache_mem_req_t dcache_read_i,

    input  logic                 dcache_read_resp_ready_i,
    output logic                 dcache_read_resp_valid_o,
    output hpdcache_mem_resp_r_t dcache_read_resp_o,

    //      Write interface
    output logic              dcache_write_ready_o,
    input  logic              dcache_write_valid_i,
    input  hpdcache_mem_req_t dcache_write_i,

    output logic                dcache_write_data_ready_o,
    input  logic                dcache_write_data_valid_i,
    input  hpdcache_mem_req_w_t dcache_write_data_i,

    input  logic                 dcache_write_resp_ready_i,
    output logic                 dcache_write_resp_valid_o,
    output hpdcache_mem_resp_w_t dcache_write_resp_o,
    //  }}}

    //  AXI port to upstream memory/peripherals
    //  {{{
    output axi_req_t axi_req_o,
    input  axi_rsp_t axi_resp_i
    //  }}}
);
  //  }}}

  //  Internal type definitions
  //  {{{

  localparam int MEM_RESP_RT_DEPTH = (1 << CVA6Cfg.MEM_TID_WIDTH);
  typedef hpdcache_mem_id_t [MEM_RESP_RT_DEPTH-1:0] mem_resp_rt_t;
  typedef logic [CVA6Cfg.ICACHE_LINE_WIDTH-1:0] icache_resp_data_t;
  //  }}}

  //  Adapt the I$ interface to the HPDcache memory interface
  //  {{{
  localparam int ICACHE_UC_WORD_INDEX = CVA6Cfg.AxiDataWidth > 64 ? $clog2(
      CVA6Cfg.AxiDataWidth / 64
  ) : 1;
  localparam int ICACHE_CL_SIZE = $clog2(CVA6Cfg.ICACHE_LINE_WIDTH / 8);
  localparam int ICACHE_WORD_SIZE = 3;
  localparam int ICACHE_MEM_REQ_CL_LEN =
    (CVA6Cfg.ICACHE_LINE_WIDTH + CVA6Cfg.AxiDataWidth - 1)/CVA6Cfg.AxiDataWidth;
  localparam int ICACHE_MEM_REQ_CL_SIZE =
    (CVA6Cfg.AxiDataWidth <= CVA6Cfg.ICACHE_LINE_WIDTH) ?
      $clog2(
      CVA6Cfg.AxiDataWidth / 8
  ) : ICACHE_CL_SIZE;

  //    I$ request
  hpdcache_mem_req_t [NrHarts-1:0] icache_miss_req_wdata;
  logic [NrHarts-1:0] icache_miss_req_w, icache_miss_req_wok;

  hpdcache_mem_req_t [NrHarts-1:0] icache_miss_req_rdata;
  logic [NrHarts-1:0] icache_miss_req_r, icache_miss_req_rok;

  logic [NrHarts-1:0] icache_miss_pending_q;

  generate
    for (genvar HartId = 0; HartId < NrHarts; HartId++) begin : gen_cva6_hpdcache_core_fifo_regs
      //  This FIFO has two functionalities:
      //  -  Stabilize the ready-valid protocol. The ICACHE can abort a valid
      //     transaction without receiving the corresponding ready signal. This
      //     behavior is not supported by AXI.
      //  -  Cut a possible long timing path.
      hpdcache_fifo_reg #(
          .FIFO_DEPTH (1),
          .fifo_data_t(hpdcache_mem_req_t)
      ) i_icache_miss_req_fifo (
          .clk_i,
          .rst_ni,

          .w_i    (icache_miss_req_w[HartId]),
          .wok_o  (icache_miss_req_wok[HartId]),
          .wdata_i(icache_miss_req_wdata[HartId]),

          .r_i    (icache_miss_req_r[HartId]),
          .rok_o  (icache_miss_req_rok[HartId]),
          .rdata_o(icache_miss_req_rdata[HartId])
      );

      assign icache_miss_req_w[HartId] = icache_miss_valid_i[HartId];
      assign icache_miss_ready_o[HartId] = icache_miss_req_wok[HartId];

      assign icache_miss_req_wdata[HartId].mem_req_addr = icache_miss_i[HartId].paddr;
      assign icache_miss_req_wdata[HartId].mem_req_len = icache_miss_i[HartId].nc ? 0 : ICACHE_MEM_REQ_CL_LEN - 1;
      assign icache_miss_req_wdata[HartId].mem_req_size = icache_miss_i[HartId].nc ? ICACHE_WORD_SIZE : ICACHE_MEM_REQ_CL_SIZE;
      assign icache_miss_req_wdata[HartId].mem_req_id = icache_miss_i[HartId].tid;
      assign icache_miss_req_wdata[HartId].mem_req_command = hpdcache_pkg::HPDCACHE_MEM_READ;
      assign icache_miss_req_wdata[HartId].mem_req_atomic = hpdcache_pkg::hpdcache_mem_atomic_e'(0);
      assign icache_miss_req_wdata[HartId].mem_req_cacheable = ~icache_miss_i[HartId].nc;
    end
  endgenerate


  //    I$ response
  logic [NrHarts-1:0] icache_miss_resp_w, icache_miss_resp_wok;
  hpdcache_mem_resp_r_t [NrHarts-1:0] icache_miss_resp_wdata;

  logic [NrHarts-1:0] icache_miss_resp_data_w, icache_miss_resp_data_wok;
  logic [NrHarts-1:0] icache_miss_resp_data_r, icache_miss_resp_data_rok;
  icache_resp_data_t [NrHarts-1:0] icache_miss_resp_data_rdata;

  logic [NrHarts-1:0] icache_miss_resp_meta_w, icache_miss_resp_meta_wok;
  logic [NrHarts-1:0] icache_miss_resp_meta_r, icache_miss_resp_meta_rok;
  hpdcache_mem_id_t  [NrHarts-1:0] icache_miss_resp_meta_id;

  icache_resp_data_t [NrHarts-1:0] icache_miss_rdata;

  generate
    for (genvar HartId = 0; HartId < NrHarts; HartId++) begin : gen_cva6_hpdcache_core_axi_adapter
      if (CVA6Cfg.AxiDataWidth < CVA6Cfg.ICACHE_LINE_WIDTH) begin
        hpdcache_fifo_reg #(
            .FIFO_DEPTH (1),
            .fifo_data_t(hpdcache_mem_id_t)
        ) i_icache_refill_meta_fifo (
            .clk_i,
            .rst_ni,

            .w_i    (icache_miss_resp_meta_w[HartId]),
            .wok_o  (icache_miss_resp_meta_wok[HartId]),
            .wdata_i(icache_miss_resp_wdata[HartId].mem_resp_r_id),

            .r_i    (icache_miss_resp_meta_r[HartId]),
            .rok_o  (icache_miss_resp_meta_rok[HartId]),
            .rdata_o(icache_miss_resp_meta_id[HartId])
        );

        hpdcache_data_upsize #(
            .WR_WIDTH(CVA6Cfg.AxiDataWidth),
            .RD_WIDTH(CVA6Cfg.ICACHE_LINE_WIDTH),
            .DEPTH   (1)
        ) i_icache_hpdcache_data_upsize (
            .clk_i,
            .rst_ni,

            .w_i    (icache_miss_resp_data_w[HartId]),
            .wlast_i(icache_miss_resp_wdata[HartId].mem_resp_r_last),
            .wok_o  (icache_miss_resp_data_wok[HartId]),
            .wdata_i(icache_miss_resp_wdata[HartId].mem_resp_r_data),

            .r_i    (icache_miss_resp_data_r[HartId]),
            .rok_o  (icache_miss_resp_data_rok[HartId]),
            .rdata_o(icache_miss_resp_data_rdata[HartId])
        );

        assign icache_miss_resp_meta_r[HartId] = 1'b1, icache_miss_resp_data_r[HartId] = 1'b1;

        assign icache_miss_resp_meta_w[HartId] = icache_miss_resp_w[HartId] & icache_miss_resp_wdata[HartId].mem_resp_r_last;

        assign icache_miss_resp_data_w[HartId] = icache_miss_resp_w[HartId];

        assign icache_miss_resp_wok[HartId] = icache_miss_resp_data_wok[HartId] & (
               icache_miss_resp_meta_wok[HartId] | ~icache_miss_resp_wdata[HartId].mem_resp_r_last);

      end else begin
        assign icache_miss_resp_data_rok[HartId] = icache_miss_resp_w[HartId];
        assign icache_miss_resp_meta_rok[HartId] = icache_miss_resp_w[HartId];
        assign icache_miss_resp_wok[HartId] = 1'b1;
        assign icache_miss_resp_meta_id[HartId] = icache_miss_resp_wdata[HartId].mem_resp_r_id;
        assign icache_miss_resp_data_rdata[HartId] = icache_miss_resp_wdata[HartId].mem_resp_r_data;
      end
    end
  endgenerate

  //  In the case of uncacheable accesses, the Icache expects the data to be right-aligned
  always_comb begin : icache_miss_resp_data_comb
    for (int HartId = 0; HartId < NrHarts; HartId++) begin
      if (!icache_miss_req_rdata[HartId].mem_req_cacheable) begin
        automatic logic [ICACHE_UC_WORD_INDEX - 1:0] icache_miss_word_index;
        automatic logic [63:0] icache_miss_word;
        if (CVA6Cfg.AxiDataWidth > 64) begin
          icache_miss_word_index = icache_miss_req_rdata[HartId].mem_req_addr[3+:ICACHE_UC_WORD_INDEX];
        end else begin
          icache_miss_word_index = 0;
        end
        icache_miss_word = icache_miss_resp_data_rdata[HartId][icache_miss_word_index*64+:64];
        icache_miss_rdata[HartId] = {{CVA6Cfg.ICACHE_LINE_WIDTH - 64{1'b0}}, icache_miss_word};
      end else begin
        icache_miss_rdata[HartId] = icache_miss_resp_data_rdata[HartId];
      end
    end
  end

  generate
    for (genvar HartId = 0; HartId < NrHarts; HartId++) begin : gen_cva6_hpdcache_icache_miss_resp_o
      assign icache_miss_resp_valid_o[HartId] = icache_miss_resp_meta_rok[HartId];
      assign icache_miss_resp_o[HartId].rtype = wt_cache_pkg::ICACHE_IFILL_ACK;
      assign icache_miss_resp_o[HartId].user = '0;
      assign icache_miss_resp_o[HartId].inv = '0;
      assign icache_miss_resp_o[HartId].tid = icache_miss_resp_meta_id[HartId];
      assign icache_miss_resp_o[HartId].data = icache_miss_rdata[HartId];

      //  consume the Icache miss on the arrival of the response. The request
      //  metadata is decoded to forward the correct word in case of uncacheable
      //  Icache access
      assign icache_miss_req_r[HartId] = icache_miss_resp_meta_rok[HartId];
    end
  endgenerate
  //  }}}

  //  Read request arbiter
  //  {{{
  logic              [NrHarts:0] mem_req_read_ready;
  logic              [NrHarts:0] mem_req_read_valid;
  hpdcache_mem_req_t [NrHarts:0] mem_req_read;

  logic                          mem_req_read_ready_arb;
  logic                          mem_req_read_valid_arb;
  hpdcache_mem_req_t             mem_req_read_arb;

  generate
    for (genvar HartId = 0; HartId < NrHarts; HartId++) begin : gen_cva6_hpdcache_mem_req_read
      assign mem_req_read_valid[HartId] = icache_miss_req_rok[HartId] & ~icache_miss_pending_q[HartId];
      assign mem_req_read[HartId] = icache_miss_req_rdata[HartId];
    end
  endgenerate

  assign dcache_read_ready_o = mem_req_read_ready[NrHarts];
  assign mem_req_read_valid[NrHarts] = dcache_read_valid_i;
  assign mem_req_read[NrHarts] = dcache_read_i;

  hpdcache_mem_req_read_arbiter #(
      .N                 (NrHarts + 1),
      .hpdcache_mem_req_t(hpdcache_mem_req_t)
  ) i_mem_req_read_arbiter (
      .clk_i,
      .rst_ni,

      .mem_req_read_ready_o(mem_req_read_ready),
      .mem_req_read_valid_i(mem_req_read_valid),
      .mem_req_read_i      (mem_req_read),

      .mem_req_read_ready_i(mem_req_read_ready_arb),
      .mem_req_read_valid_o(mem_req_read_valid_arb),
      .mem_req_read_o      (mem_req_read_arb)
  );
  //  }}}

  //  Read response demultiplexor
  //  {{{
  logic                 mem_resp_read_ready;
  logic                 mem_resp_read_valid;
  hpdcache_mem_resp_r_t mem_resp_read;

  logic                 mem_resp_read_ready_arb[NrHarts:0];
  logic                 mem_resp_read_valid_arb[NrHarts:0];
  hpdcache_mem_resp_r_t mem_resp_read_arb      [NrHarts:0];

  mem_resp_rt_t         mem_resp_read_rt;

  // Routing table: transaction with id `i` is routed to output
  // `mem_resp_read_rt[i]`
  always_comb begin
    for (int i = 0; i < MEM_RESP_RT_DEPTH; i++) begin
      mem_resp_read_rt[i] = NrHarts;
      for (int id = 0; id < NrHarts; id++) begin
        if (i == int'(icache_miss_id_i[id])) begin
          mem_resp_read_rt[i] = id;
        end
      end
    end
  end

  hpdcache_mem_resp_demux #(
      .N        (NrHarts + 1),
      .resp_t   (hpdcache_mem_resp_r_t),
      .resp_id_t(hpdcache_mem_id_t)
  ) i_mem_resp_read_demux (
      .clk_i,
      .rst_ni,

      .mem_resp_ready_o(mem_resp_read_ready),
      .mem_resp_valid_i(mem_resp_read_valid),
      .mem_resp_id_i   (mem_resp_read.mem_resp_r_id),
      .mem_resp_i      (mem_resp_read),

      .mem_resp_ready_i(mem_resp_read_ready_arb),
      .mem_resp_valid_o(mem_resp_read_valid_arb),
      .mem_resp_o      (mem_resp_read_arb),

      .mem_resp_rt_i(mem_resp_read_rt)
  );

  generate
    for (genvar HartId = 0; HartId < NrHarts; HartId++) begin : gen_cva6_hpdcache_icache_miss_resp
      assign icache_miss_resp_w[HartId] = mem_resp_read_valid_arb[HartId];
      assign icache_miss_resp_wdata[HartId] = mem_resp_read_arb[HartId];
      assign mem_resp_read_ready_arb[HartId] = icache_miss_resp_wok[HartId];
    end
  endgenerate

  assign dcache_read_resp_valid_o = mem_resp_read_valid_arb[NrHarts];
  assign dcache_read_resp_o = mem_resp_read_arb[NrHarts];
  assign mem_resp_read_ready_arb[NrHarts] = dcache_read_resp_ready_i;
  //  }}}

  //  I$ miss pending
  //  {{{
  always_ff @(posedge clk_i or negedge rst_ni) begin : icache_miss_pending_ff
    for (int HartId = 0; HartId < NrHarts; HartId++) begin
      if (!rst_ni) begin
        icache_miss_pending_q[HartId] <= 1'b0;
      end else begin
        icache_miss_pending_q[HartId] <= (
          ((icache_miss_req_rok[HartId] & mem_req_read_ready[HartId])  & ~icache_miss_pending_q[HartId]) |
          (~(icache_miss_req_r[HartId] & icache_miss_req_rok[HartId]) &  icache_miss_pending_q[HartId])
        );
      end
    end
  end
  // }}}

  //  AXI adapters
  //  {{{

  hpdcache_mem_to_axi_write #(
      .hpdcache_mem_req_t   (hpdcache_mem_req_t),
      .hpdcache_mem_req_w_t (hpdcache_mem_req_w_t),
      .hpdcache_mem_resp_w_t(hpdcache_mem_resp_w_t),
      .aw_chan_t            (axi_aw_chan_t),
      .w_chan_t             (axi_w_chan_t),
      .b_chan_t             (axi_b_chan_t)
  ) i_hpdcache_mem_to_axi_write (
      .req_ready_o(dcache_write_ready_o),
      .req_valid_i(dcache_write_valid_i),
      .req_i      (dcache_write_i),

      .req_data_ready_o(dcache_write_data_ready_o),
      .req_data_valid_i(dcache_write_data_valid_i),
      .req_data_i      (dcache_write_data_i),

      .resp_ready_i(dcache_write_resp_ready_i),
      .resp_valid_o(dcache_write_resp_valid_o),
      .resp_o      (dcache_write_resp_o),

      .axi_aw_valid_o(axi_req_o.aw_valid),
      .axi_aw_o      (axi_req_o.aw),
      .axi_aw_ready_i(axi_resp_i.aw_ready),

      .axi_w_valid_o(axi_req_o.w_valid),
      .axi_w_o      (axi_req_o.w),
      .axi_w_ready_i(axi_resp_i.w_ready),

      .axi_b_valid_i(axi_resp_i.b_valid),
      .axi_b_i      (axi_resp_i.b),
      .axi_b_ready_o(axi_req_o.b_ready)
  );

  hpdcache_mem_to_axi_read #(
      .hpdcache_mem_req_t   (hpdcache_mem_req_t),
      .hpdcache_mem_resp_r_t(hpdcache_mem_resp_r_t),
      .ar_chan_t            (axi_ar_chan_t),
      .r_chan_t             (axi_r_chan_t)
  ) i_hpdcache_mem_to_axi_read (
      .req_ready_o(mem_req_read_ready_arb),
      .req_valid_i(mem_req_read_valid_arb),
      .req_i      (mem_req_read_arb),

      .resp_ready_i(mem_resp_read_ready),
      .resp_valid_o(mem_resp_read_valid),
      .resp_o      (mem_resp_read),

      .axi_ar_valid_o(axi_req_o.ar_valid),
      .axi_ar_o      (axi_req_o.ar),
      .axi_ar_ready_i(axi_resp_i.ar_ready),

      .axi_r_valid_i(axi_resp_i.r_valid),
      .axi_r_i      (axi_resp_i.r),
      .axi_r_ready_o(axi_req_o.r_ready)
  );

  //  }}}

  //  Assertions
  //  {{{
  //  pragma translate_off
  initial
    assert (CVA6Cfg.MEM_TID_WIDTH <= AxiIdWidth)
    else $fatal(1, "MEM_TID_WIDTH shall be less or equal to AxiIdWidth");
  initial
    assert (CVA6Cfg.AxiDataWidth <= CVA6Cfg.ICACHE_LINE_WIDTH)
    else $fatal(1, "AxiDataWidth shall be less or equal to the width of a Icache line");
  initial
    assert (CVA6Cfg.AxiDataWidth <= CVA6Cfg.DCACHE_LINE_WIDTH)
    else $fatal(1, "AxiDataWidth shall be less or equal to the width of a Dcache line");
  //  pragma translate_on
  //  }}}

endmodule : cva6_multicore_hpdcache_subsystem_axi_arbiter
