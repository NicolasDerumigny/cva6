`include "register_interface/assign.svh"
`include "rvfi_types.svh"

`include "ariane_xlnx_mapper.svh"

import cva6_config_pkg::*;

module cva6_wrapper #(
    parameter unsigned AXI_ADDR_WIDTH = 64,
    parameter unsigned AXI_DATA_WIDTH = 64,
    parameter unsigned AXI_ID_WIDTH   = 4,
    parameter unsigned AXI_USER_WIDTH = 1,
    parameter unsigned AXI_CUT_BYPASS = 1,
    parameter unsigned NR_CORES       = 1
) (
    input logic aclk,
    input logic aresetn,
    input logic [NR_CORES-1:0][1:0] irqs_in,
    input logic [NR_CORES-1:0] ipi_in,
    input logic [NR_CORES-1:0] timer_irq_i,
    input logic [NR_CORES-1:0] debug_req_irq,

    output wire [1:0][63:0] pc0,
    output wire [1:0][63:0] pc1,
    output wire [31:0] instr0,
    output wire [31:0] instr1,
    output wire [1:0] valid0,
    output wire [1:0] valid1,
    output wire [7:0] lsu_ctrl_be1,
    output wire [3:0] lsu_ctrl_fu1,
    output wire [2:0] lsu_ctrl_trans_id1,
    output wire [63:0] lsu_ctrl_vaddr1,
    output wire [55:0] mem_paddr1,
    output wire flush1,
    output wire [63:0] mcause1,

    output wire         req_from_cache_valid1,
    output wire         req_from_cache_gnt1,
    output wire  [63:0] req_to_cache_data_wdata1,
    output wire  [63:0] req_to_cache_data_wuser1,
    output wire  [43:0] req_to_cache_tag1,
    output wire         req_to_cache_data_req1,
    output wire         req_to_cache_data_we1,
    output wire  [ 7:0] req_to_cache_data_be1,
    output wire  [ 1:0] req_to_cache_data_size1,
    output wire  [ 2:0] req_to_cache_data_id1,
    output wire         req_to_cache_kill_req1,
    output wire         req_to_cache_valid1,
    output wire         page_offset_matches1,
    output logic [10:0] arb_req_gnt_d,
    output wire  [63:0] exc_cause1,
    output wire  [63:0] exc_tval1_1,
    output wire  [40:0] exc_tval2_1,
    output wire  [31:0] exc_tinst1,
    output wire         exc_gva1,
    output wire         exc_valid1,
    output wire  [ 3:0] state1,
    output logic [ 2:0] lsu_id1,
    output logic [ 2:0] commit_id1,

    `AXI_INTERFACE_MODULE_OUTPUT(m_axi_cpu, AXI_ID_WIDTH)
);
  localparam config_pkg::cva6_cfg_t CVA6Cfg = build_fpga_config_pkg::build_fpga_config(
      cva6_config_pkg::cva6_cfg
  );

  ariane_axi::req_t axi_ariane_req, axi_cut_req;
  ariane_axi::resp_t axi_ariane_resp, axi_cut_resp;

  AXI_BUS #(
      .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
      .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
      .AXI_ID_WIDTH  (AXI_ID_WIDTH),
      .AXI_USER_WIDTH(AXI_DATA_WIDTH)
  )
      tmp_bus (), cpu_bus ();

  import axi_pkg::BURST_FIXED;
  import axi_pkg::BURST_INCR;
  import axi_pkg::BURST_WRAP;

  import axi_pkg::RESP_OKAY;
  import axi_pkg::RESP_EXOKAY;
  import axi_pkg::RESP_DECERR;
  import axi_pkg::RESP_SLVERR;

  typedef `RVFI_PROBES_INSTR_T(CVA6Cfg) rvfi_probes_instr_t;
  typedef `RVFI_PROBES_CSR_T(CVA6Cfg) rvfi_probes_csr_t;
  typedef struct packed {
    rvfi_probes_csr_t   csr;
    rvfi_probes_instr_t instr;
  } rvfi_probes_t;

  rvfi_probes_t probes[NR_CORES];

  // Debug
  typedef struct packed {
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
  } dcache_req_i_t;
  typedef struct packed {
    logic                                 data_gnt;
    logic                                 data_rvalid;
    logic [CVA6Cfg.DcacheIdWidth-1:0]     data_rid;
    logic [CVA6Cfg.XLEN-1:0]              data_rdata;
    logic [CVA6Cfg.DCACHE_USER_WIDTH-1:0] data_ruser;
  } dcache_req_o_t;

  typedef struct packed {
    logic [CVA6Cfg.XLEN-1:0] cause;  // cause of exception
    logic [CVA6Cfg.XLEN-1:0] tval;  // additional information of causing exception (e.g.: instruction causing it),
    // address of LD/ST fault
    logic [CVA6Cfg.GPLEN-1:0] tval2;  // additional information when the causing exception in a guest exception
    logic [31:0] tinst;  // transformed instruction information
    logic gva;  // signals when a guest virtual address is written to tval
    logic valid;
  } exception_t;

  dcache_req_o_t [NR_CORES-1:0][3:0] dcache_req_from_cache;
  dcache_req_i_t [NR_CORES-1:0][3:0] dcache_req_to_cache;
  wire           [NR_CORES-1:0]      page_offset_matches_all;
  exception_t    [NR_CORES-1:0]      exec;
  wire           [NR_CORES-1:0][3:0] state_mc;

  logic          [NR_CORES-1:0][2:0] lsu_id;
  logic          [NR_CORES-1:0][2:0] commit_id;

  ariane_multicore #(
      .CVA6Cfg(CVA6Cfg),
      .rvfi_probes_instr_t(rvfi_probes_instr_t),
      .rvfi_probes_csr_t(rvfi_probes_csr_t),
      .rvfi_probes_t(rvfi_probes_t),
      .exception_t(exception_t),
      .dcache_req_i_t(dcache_req_i_t),
      .dcache_req_o_t(dcache_req_o_t),
      .NrHarts(NR_CORES)
  ) i_ariane (
      .clk_i                (aclk),
      .rst_ni               (aresetn),
      .boot_addr_i          (ariane_soc::ROMBase),      // start fetching from ROM
      .irq_i                (irqs_in),
      .ipi_i                (ipi_in),
      .time_irq_i           (timer_irq_i),
      .debug_req_i          (debug_req_irq),
      .rvfi_probes_o        (probes),
      .noc_req_o            (axi_ariane_req),
      .noc_resp_i           (axi_ariane_resp),
      .dcache_req_from_cache(dcache_req_from_cache),
      .dcache_req_to_cache  (dcache_req_to_cache),
      .page_offset_matches  (page_offset_matches_all),
      .arb_req_gnt_d        (arb_req_gnt_d),
      .cva6_mmu_exception   (exec),
      .state_o              (state_mc),
      .lsu_id,
      .commit_id
  );

  assign pc0[0] = probes[0].instr.commit_instr_pc[0];
  assign pc0[1] = probes[0].instr.commit_instr_pc[1];
  assign pc1[0] = probes[1].instr.commit_instr_pc[0];
  assign pc1[1] = probes[1].instr.commit_instr_pc[1];
  assign instr0 = probes[0].instr.instruction[0];
  assign instr1 = probes[1].instr.instruction[0];
  assign valid0 = probes[0].instr.commit_instr_valid;
  assign valid1 = probes[1].instr.commit_instr_valid;
  assign lsu_ctrl_be1 = probes[1].instr.lsu_ctrl_be;
  assign lsu_ctrl_fu1 = probes[1].instr.lsu_ctrl_fu;
  assign lsu_ctrl_trans_id1 = probes[1].instr.lsu_ctrl_trans_id;
  assign lsu_ctrl_vaddr1 = probes[1].instr.lsu_ctrl_vaddr;
  assign mem_paddr1 = probes[1].instr.mem_paddr;
  assign flush1 = probes[1].instr.flush;
  assign mcause1 = probes[1].csr.mcause_q;
  assign req_from_cache_valid1 = dcache_req_from_cache[1][1].data_rvalid;
  assign req_from_cache_gnt1 = dcache_req_from_cache[1][1].data_gnt;
  assign req_to_cache_valid1 = dcache_req_to_cache[1][1].tag_valid;
  assign req_to_cache_data_wdata1 = dcache_req_to_cache[1][1].data_wdata;
  assign req_to_cache_data_wuser1 = dcache_req_to_cache[1][1].data_wuser;
  assign req_to_cache_tag1 = dcache_req_to_cache[1][1].address_tag;
  assign req_to_cache_data_req1 = dcache_req_to_cache[1][1].data_req;
  assign req_to_cache_data_we1 = dcache_req_to_cache[1][1].data_we;
  assign req_to_cache_data_be1 = dcache_req_to_cache[1][1].data_be;
  assign req_to_cache_data_size1 = dcache_req_to_cache[1][1].data_size;
  assign req_to_cache_data_id1 = dcache_req_to_cache[1][1].data_id;
  assign req_to_cache_kill_req1 = dcache_req_to_cache[1][1].kill_req;


  assign exc_cause1 = exec[1].cause;
  assign exc_tval1_1 = exec[1].tval;
  assign exc_tval2_1 = exec[1].tval2;
  assign exc_tinst1 = exec[1].tinst;
  assign exc_gva1 = exec[1].gva;
  assign exc_valid1 = exec[1].valid;

  assign state1 = state_mc[1];

  assign lsu_id1 = lsu_id[1];
  assign commit_id1 = commit_id[1];

  assign page_offset_matches1 = page_offset_matches_all[1];

  `AXI_ASSIGN_FROM_REQ(cpu_bus, axi_ariane_req)
  `AXI_ASSIGN_TO_RESP(axi_ariane_resp, cpu_bus)

  axi_cut_intf #(
      .ADDR_WIDTH(AXI_ADDR_WIDTH),
      .DATA_WIDTH(AXI_DATA_WIDTH),
      .ID_WIDTH(AXI_ID_WIDTH),
      .USER_WIDTH(AXI_USER_WIDTH),
      .BYPASS(AXI_CUT_BYPASS)
  ) i_axi_cut (
      .clk_i (aclk),
      .rst_ni(aresetn),
      .in    (cpu_bus),
      .out   (tmp_bus)
  );

  `ASSIGN_XLNX_INTERFACE_FROM_ARIANE_STYLE_INPUTS(m_axi_cpu, tmp_bus)
endmodule
