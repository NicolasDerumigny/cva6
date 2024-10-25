`include "ariane_xlnx_mapper.svh"
module ariane_peripherals_wrapper_verilog
#(
    parameter AXI_ID_WIDTH=10,
    parameter AXI_ADDR_WIDTH=64,
    parameter AXI_DATA_WIDTH=64,
    parameter AXI_USER_WIDTH=1
)
(
    input wire aclk,
    input wire aresetn,
    input wire [2:0] irqs_in,
    `AXI_INTERFACE_MODULE_INPUT(s_axi_plic),
    `AXI_INTERFACE_MODULE_INPUT(s_axi_timer),
    output wire [1:0] irq_out
);

// Can't have SystemVerilog modules in a Vivado Block Design
// thus, need to wrap the module that does the actual conversion in a Verilog file
ariane_peripherals_wrapper
#(
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_USER_WIDTH(AXI_USER_WIDTH)
)
i_peripherals_mapper
(
    .aclk(aclk),
    .aresetn(aresetn),
    .irqs_in(irqs_in),
    `AXI_INTERFACE_FORWARD(s_axi_plic),
    `AXI_INTERFACE_FORWARD(s_axi_timer),
    .irq_out(irq_out)
);

endmodule