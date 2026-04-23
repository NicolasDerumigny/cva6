`include "ariane_xlnx_mapper.svh"

module ariane_peripherals_wrapper_verilog
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
    // Should be EDGE_RISING
    (*X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 uart_irq_i INTERRUPT", X_INTERFACE_PARAMETER = "SENSITIVITY LEVEL_HIGH" *)
    input wire uart_irq_i,
    (*X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 spi_irq_i INTERRUPT", X_INTERFACE_PARAMETER = "SENSITIVITY EDGE_RISING" *)
    input wire spi_irq_i,
    // Should be EDGE_RISING
    (*X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 eth_irq_i INTERRUPT", X_INTERFACE_PARAMETER = "SENSITIVITY LEVEL_HIGH" *)
    input wire eth_irq_i,
    (*X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 irq_i INTERRUPT", X_INTERFACE_PARAMETER = "SENSITIVITY EDGE_RISING" *)
    input wire[29:7] irq_i,
    `AXI_INTERFACE_MODULE_INPUT(s_axi_plic, AXI_ID_WIDTH),
    `AXI_INTERFACE_MODULE_INPUT(s_axi_timer, AXI_ID_WIDTH),
    (*X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 irq_out INTERRUPT", X_INTERFACE_PARAMETER = "SENSITIVITY LEVEL_HIGH" *)
    output wire [NR_CORES*2-1:0] irq_out
);

// Can't have SystemVerilog modules in a Vivado Block Design
// thus, need to wrap the module that does the actual conversion in a Verilog file
ariane_peripherals_wrapper
#(
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_USER_WIDTH(AXI_USER_WIDTH),
    .NR_CORES(NR_CORES)
)
i_peripherals_mapper
(
    .aclk(aclk),
    .aresetn(aresetn),
    `AXI_INTERFACE_FORWARD(s_axi_plic),
    `AXI_INTERFACE_FORWARD(s_axi_timer),
    .uart_irq_i(uart_irq_i),
    .spi_irq_i(spi_irq_i),
    .eth_irq_i(eth_irq_i),
    .irq_i(irq_i),
    .irq_out(irq_out)
);

endmodule
