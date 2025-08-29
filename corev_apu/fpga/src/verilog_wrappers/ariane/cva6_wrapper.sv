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

  ariane_multicore #(
      .CVA6Cfg(CVA6Cfg),
      .rvfi_probes_instr_t(rvfi_probes_instr_t),
      .rvfi_probes_csr_t(rvfi_probes_csr_t),
      .rvfi_probes_t(rvfi_probes_t),
      .NrHarts(NR_CORES)
  ) i_ariane (
      .clk_i        (aclk),
      .rst_ni       (aresetn),
      .boot_addr_i  (ariane_soc::ROMBase),  // start fetching from ROM
      .irq_i        (irqs_in),
      .ipi_i        (ipi_in),
      .time_irq_i   (timer_irq_i),
      .debug_req_i  (debug_req_irq),
      .rvfi_probes_o(probes),
      .noc_req_o    (axi_ariane_req),
      .noc_resp_i   (axi_ariane_resp)
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
