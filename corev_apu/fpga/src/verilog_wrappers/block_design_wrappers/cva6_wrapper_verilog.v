`include "ariane_xlnx_mapper.svh"

module cva6_wrapper_verilog #(
    parameter AXI_ADDR_WIDTH = 64,
    parameter AXI_DATA_WIDTH = 64,
    parameter AXI_ID_WIDTH   = 4,
    parameter AXI_USER_WIDTH = 1,
    parameter AXI_CUT_BYPASS = 1,
    parameter NR_CORES       = 1
) (
    input wire aclk,
    input wire aresetn,
    (*X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 irqs_in INTERRUPT", X_INTERFACE_PARAMETER = "SENSITIVITY EDGE_RISING" *)
    input wire [NR_CORES-1:0][1:0] irqs_in,
    (*X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 ipi_in INTERRUPT", X_INTERFACE_PARAMETER = "SENSITIVITY EDGE_RISING" *)
    input wire [NR_CORES-1:0] ipi_in,
    (*X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 timer_irq_i INTERRUPT", X_INTERFACE_PARAMETER = "SENSITIVITY EDGE_RISING" *)
    input wire [NR_CORES-1:0] timer_irq_i,
    (*X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 debug_req_irq INTERRUPT", X_INTERFACE_PARAMETER = "SENSITIVITY EDGE_RISING" *)
    input wire [NR_CORES-1:0] debug_req_irq,

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

  cva6_wrapper #(
      .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
      .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
      .AXI_ID_WIDTH(AXI_ID_WIDTH),
      .AXI_USER_WIDTH(AXI_USER_WIDTH),
      .AXI_CUT_BYPASS(AXI_CUT_BYPASS),
      .NR_CORES(NR_CORES)
  ) i_cva6_wrapper (
      .aclk         (aclk),
      .aresetn      (aresetn),
      .irqs_in      (irqs_in),
      .ipi_in       (ipi_in),
      .timer_irq_i  (timer_irq_i),
      .debug_req_irq(debug_req_irq),
      .pc0          (pc0),
      .pc1          (pc1),
      .instr0       (instr0),
      .instr1       (instr1),
      .valid0       (valid0),
      .valid1       (valid1),

      .lsu_ctrl_be1(lsu_ctrl_be1),
      .lsu_ctrl_fu1(lsu_ctrl_fu1),
      .lsu_ctrl_trans_id1(lsu_ctrl_trans_id1),
      .lsu_ctrl_vaddr1(lsu_ctrl_vaddr1),
      .mem_paddr1(mem_paddr1),
      .flush1(flush1),
      .mcause1(mcause1),

      `AXI_INTERFACE_FORWARD(m_axi_cpu)
  );

endmodule
