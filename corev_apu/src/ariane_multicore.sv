// Copyright 2017-2019 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Florian Zaruba, ETH Zurich
// Date: 19.03.2017
// Description: Ariane Top-level module

`include "cvxif_types.svh"

module ariane_multicore
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type rvfi_probes_instr_t = logic,
    parameter type rvfi_probes_csr_t = logic,
    parameter type rvfi_probes_t = struct packed {
      logic csr;
      logic instr;
    },
    parameter type exception_t = struct packed {
      logic [CVA6Cfg.XLEN-1:0] cause;  // cause of exception
      logic [CVA6Cfg.XLEN-1:0] tval;  // additional information of causing exception (e.g.: instruction causing it),
      // address of LD/ST fault
      logic [CVA6Cfg.GPLEN-1:0] tval2;  // additional information when the causing exception in a guest exception
      logic [31:0] tinst;  // transformed instruction information
      logic gva;  // signals when a guest virtual address is written to tval
      logic valid;
    },
    // CVXIF Types
    localparam type readregflags_t = `READREGFLAGS_T(CVA6Cfg),
    localparam type writeregflags_t = `WRITEREGFLAGS_T(CVA6Cfg),
    localparam type id_t = `ID_T(CVA6Cfg),
    localparam type hartid_t = `HARTID_T(CVA6Cfg),
    localparam type x_compressed_req_t = `X_COMPRESSED_REQ_T(CVA6Cfg, hartid_t),
    localparam type x_compressed_resp_t = `X_COMPRESSED_RESP_T(CVA6Cfg),
    localparam type x_issue_req_t = `X_ISSUE_REQ_T(CVA6Cfg, hartid_t, id_t),
    localparam type x_issue_resp_t = `X_ISSUE_RESP_T(CVA6Cfg, writeregflags_t, readregflags_t),
    localparam type x_register_t = `X_REGISTER_T(CVA6Cfg, hartid_t, id_t, readregflags_t),
    localparam type x_commit_t = `X_COMMIT_T(CVA6Cfg, hartid_t, id_t),
    localparam type x_result_t = `X_RESULT_T(CVA6Cfg, hartid_t, id_t, writeregflags_t),
    localparam type cvxif_req_t =
    `CVXIF_REQ_T(CVA6Cfg, x_compressed_req_t, x_issue_req_t, x_register_t, x_commit_t),
    localparam type cvxif_resp_t =
    `CVXIF_RESP_T(CVA6Cfg, x_compressed_resp_t, x_issue_resp_t, x_result_t),

    // Debug
    parameter type dcache_req_i_t = struct packed {
      logic [CVA6Cfg.DCACHE_INDEX_WIDTH-1:0] address_index;
      logic [CVA6Cfg.DCACHE_TAG_WIDTH-1:0]   address_tag;
      logic [CVA6Cfg.XLEN-1:0]               data_wdata;
      logic [CVA6Cfg.DCACHE_USER_WIDTH-1:0]  data_wuser;
      logic                                  data_req;
      logic                                  data_we;
      logic [(CVA6Cfg.XLEN/8)-1:0]           data_be;
      logic [1:0]                            data_size;
      logic [CVA6Cfg.DcacheIdWidth-1:0]      data_id;
      logic                                  kill_req;
      logic                                  tag_valid;
    },
    parameter type dcache_req_o_t = struct packed {
      logic                                 data_gnt;
      logic                                 data_rvalid;
      logic [CVA6Cfg.DcacheIdWidth-1:0]     data_rid;
      logic [CVA6Cfg.XLEN-1:0]              data_rdata;
      logic [CVA6Cfg.DCACHE_USER_WIDTH-1:0] data_ruser;
    },

    // AXI Types
    parameter int unsigned AxiAddrWidth = ariane_axi::AddrWidth,
    parameter int unsigned AxiDataWidth = ariane_axi::DataWidth,
    parameter int unsigned AxiIdWidth = ariane_axi::IdWidth,
    parameter type axi_ar_chan_t = ariane_axi::ar_chan_t,
    parameter type axi_aw_chan_t = ariane_axi::aw_chan_t,
    parameter type axi_w_chan_t = ariane_axi::w_chan_t,
    parameter type noc_req_t = ariane_axi::req_t,
    parameter type noc_resp_t = ariane_axi::resp_t,
    parameter unsigned NrHarts = 1
) (
    input logic clk_i,
    input logic rst_ni,
    // Core ID, Cluster ID and boot address are considered more or less static
    input logic [CVA6Cfg.VLEN-1:0] boot_addr_i,  // reset boot address

    // Interrupt inputs
    input logic [NrHarts-1:0][1:0] irq_i,  // level sensitive IR lines, mip & sip (async)
    input logic [NrHarts-1:0] ipi_i,  // inter-processor interrupts (async)
    // Timer facilities
    input logic [NrHarts-1:0] time_irq_i,  // timer interrupt in (async)
    input logic [NrHarts-1:0] debug_req_i,  // debug request (async)
    // RISC-V formal interface port (`rvfi`):
    // Can be left open when formal tracing is not needed.
    output rvfi_probes_t rvfi_probes_o[NrHarts],

    // memory side
    output noc_req_t                         noc_req_o,
    input  noc_resp_t                        noc_resp_i,
    // debug
    output dcache_req_o_t [NrHarts-1:0][3:0] dcache_req_from_cache,
    output dcache_req_i_t [NrHarts-1:0][3:0] dcache_req_to_cache,
    output wire           [NrHarts-1:0]      page_offset_matches,
    output logic          [       10:0]      arb_req_gnt_d,
    output exception_t    [NrHarts-1:0]      cva6_mmu_exception,
    output logic          [NrHarts-1:0][3:0] state_o,
    output logic          [NrHarts-1:0][2:0] lsu_id,
    output logic          [NrHarts-1:0][2:0] commit_id
);

  cvxif_req_t  cvxif_req [NrHarts];
  cvxif_resp_t cvxif_resp[NrHarts];

  cva6_multicore #(
      .CVA6Cfg(CVA6Cfg),
      .rvfi_probes_instr_t(rvfi_probes_instr_t),
      .rvfi_probes_csr_t(rvfi_probes_csr_t),
      .rvfi_probes_t(rvfi_probes_t),
      .axi_ar_chan_t(axi_ar_chan_t),
      .axi_aw_chan_t(axi_aw_chan_t),
      .axi_w_chan_t(axi_w_chan_t),
      .noc_req_t(noc_req_t),
      .noc_resp_t(noc_resp_t),
      .readregflags_t(readregflags_t),
      .writeregflags_t(writeregflags_t),
      .id_t(id_t),
      .hartid_t(hartid_t),
      .x_compressed_req_t(x_compressed_req_t),
      .x_compressed_resp_t(x_compressed_resp_t),
      .x_issue_req_t(x_issue_req_t),
      .x_issue_resp_t(x_issue_resp_t),
      .x_register_t(x_register_t),
      .x_commit_t(x_commit_t),
      .x_result_t(x_result_t),
      .cvxif_req_t(cvxif_req_t),
      .cvxif_resp_t(cvxif_resp_t),
      .dcache_req_i_t(dcache_req_i_t),
      .dcache_req_o_t(dcache_req_o_t),
      .NrHarts(NrHarts)
  ) i_cva6 (
      .clk_i                (clk_i),
      .rst_ni               (rst_ni),
      .boot_addr_i          (boot_addr_i),
      .irq_i                (irq_i),
      .ipi_i                (ipi_i),
      .time_irq_i           (time_irq_i),
      .debug_req_i          (debug_req_i),
      .rvfi_probes_o        (rvfi_probes_o),
      .cvxif_req_o          (cvxif_req),
      .cvxif_resp_i         (cvxif_resp),
      .noc_req_o            (noc_req_o),
      .noc_resp_i           (noc_resp_i),
      .dcache_req_from_cache(dcache_req_from_cache),
      .dcache_req_to_cache  (dcache_req_to_cache),
      .page_offset_matches  (page_offset_matches),
      .arb_req_gnt_d        (arb_req_gnt_d),
      .cva6_mmu_exception,
      .state_o,
      .commit_id,
      .lsu_id
  );


  genvar HartId;
  generate
    for (HartId = 0; HartId < NrHarts; HartId++) begin : gen_one_copro
      if (CVA6Cfg.CvxifEn) begin : gen_cvxif
        if (CVA6Cfg.CoproType == config_pkg::COPRO_EXAMPLE) begin : gen_COPRO_EXAMPLE
          cvxif_example_coprocessor #(
              .NrRgprPorts(CVA6Cfg.NrRgprPorts),
              .XLEN(CVA6Cfg.XLEN),
              .readregflags_t(readregflags_t),
              .writeregflags_t(writeregflags_t),
              .id_t(id_t),
              .hartid_t(HartId),
              .x_compressed_req_t(x_compressed_req_t),
              .x_compressed_resp_t(x_compressed_resp_t),
              .x_issue_req_t(x_issue_req_t),
              .x_issue_resp_t(x_issue_resp_t),
              .x_register_t(x_register_t),
              .x_commit_t(x_commit_t),
              .x_result_t(x_result_t),
              .cvxif_req_t(cvxif_req_t),
              .cvxif_resp_t(cvxif_resp_t)
          ) i_cvxif_coprocessor (
              .clk_i       (clk_i),
              .rst_ni      (rst_ni),
              .cvxif_req_i (cvxif_req[HartId]),
              .cvxif_resp_o(cvxif_resp[HartId])
          );
        end else begin : gen_COPRO_NONE
          assign cvxif_resp[HartId] = '{
                  compressed_ready: 1'b1,
                  issue_ready: 1'b1,
                  register_ready: 1'b1,
                  default: '0
              };
        end
      end else begin : gen_no_cvxif
        assign cvxif_resp[HartId] = '0;
      end
    end
  endgenerate


endmodule  // ariane
