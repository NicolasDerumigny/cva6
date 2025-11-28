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

    output wire        req_from_cache_valid1,
    output wire        req_from_cache_gnt1,
    output wire [63:0] req_to_cache_data_wdata1,
    output wire [63:0] req_to_cache_data_wuser1,
    output wire [43:0] req_to_cache_tag1,
    output wire        req_to_cache_data_req1,
    output wire        req_to_cache_data_we1,
    output wire [ 7:0] req_to_cache_data_be1,
    output wire [ 1:0] req_to_cache_data_size1,
    output wire [ 2:0] req_to_cache_data_id1,
    output wire        req_to_cache_kill_req1,
    output wire        req_to_cache_valid1,
    output wire        page_offset_matches1,
    output wire [10:0] arb_req_gnt_d,
    output wire [63:0] exc_cause1,
    output wire [63:0] exc_tval1_1,
    output wire [40:0] exc_tval2_1,
    output wire [31:0] exc_tinst,
    output wire        exc_gva1,
    output wire        exc_valid1,
    output wire [ 3:0] state1,
    output wire [ 2:0] lsu_id1,
    output wire [ 2:0] commit_id1,

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

      .lsu_ctrl_be1         (lsu_ctrl_be1),
      .lsu_ctrl_fu1         (lsu_ctrl_fu1),
      .lsu_ctrl_trans_id1   (lsu_ctrl_trans_id1),
      .lsu_ctrl_vaddr1      (lsu_ctrl_vaddr1),
      .mem_paddr1           (mem_paddr1),
      .flush1               (flush1),
      .mcause1              (mcause1),
      .req_from_cache_valid1(req_from_cache_valid1),
      .req_from_cache_gnt1  (req_from_cache_gnt1),

      .req_to_cache_data_wdata1(req_to_cache_data_wdata1),
      .req_to_cache_data_wuser1(req_to_cache_data_wuser1),
      .req_to_cache_tag1(req_to_cache_tag1),
      .req_to_cache_data_req1(req_to_cache_data_req1),
      .req_to_cache_data_we1(req_to_cache_data_we1),
      .req_to_cache_data_be1(req_to_cache_data_be1),
      .req_to_cache_data_size1(req_to_cache_data_size1),
      .req_to_cache_data_id1(req_to_cache_data_id1),
      .req_to_cache_kill_req1(req_to_cache_kill_req1),
      .req_to_cache_valid1(req_to_cache_valid1),

      .page_offset_matches1(page_offset_matches1),
      .arb_req_gnt_d       (arb_req_gnt_d),
      .exc_cause1          (exc_cause1),
      .exc_tval1_1         (exc_tval1_1),
      .exc_tval2_1         (exc_tval2_1),
      .exc_tinst1          (exc_tinst1),
      .exc_gva1            (exc_gva1),
      .exc_valid1          (exc_valid1),
      .state1              (state1),
      .lsu_id1             (lsu_id1),
      .commit_id1          (commit_id1),

      `AXI_INTERFACE_FORWARD(m_axi_cpu)
  );

endmodule
