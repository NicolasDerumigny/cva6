`include "ariane_xlnx_mapper.svh"
module clint_wrapper_verilog
#(
    parameter AXI_ADDR_WIDTH = 64,
    parameter AXI_DATA_WIDTH = 64,
    parameter AXI_ID_WIDTH   = 6,
    parameter AXI_USER_WIDTH = 1,
    parameter NR_CORES       = 1
)
(
    input wire aclk,
    input wire aresetn,

    `AXI_INTERFACE_MODULE_INPUT(s_axi_clint, AXI_ID_WIDTH),

    output wire [NR_CORES-1:0] timer_irq_o,
    output wire [NR_CORES-1:0] ipi_o
);

clint_wrapper #(
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_USER_WIDTH(AXI_USER_WIDTH),
    .NR_CORES(NR_CORES)
)
i_clint_wrapper(
    .aclk(aclk),
    .aresetn(aresetn),

    `AXI_INTERFACE_FORWARD(s_axi_clint),

    .timer_irq_o(timer_irq_o),
    .ipi_o(ipi_o)
);

endmodule
