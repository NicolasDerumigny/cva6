`include "ariane_xlnx_mapper.svh"

module axi_xbar_interface_verilog
#(
    parameter AXI_ADDR_WIDTH = 64,
    parameter AXI_DATA_WIDTH = 64,
    parameter AXI_MST_ID_WIDTH = 4,
    parameter AXI_SLV_ID_WIDTH = 6,
    parameter AXI_USER_WIDTH = 1
) (
    input wire aclk,
    input wire aresetn,

    `AXI_INTERFACE_MODULE_INPUT(s_axi_cpu, AXI_SLV_ID_WIDTH),
    `AXI_INTERFACE_MODULE_INPUT(s_axi_debug, AXI_SLV_ID_WIDTH),
    //`AXI_INTERFACE_MODULE_INPUT(s_axi_eth_dma_sg, AXI_SLV_ID_WIDTH),
    //`AXI_INTERFACE_MODULE_INPUT(s_axi_eth_dma, AXI_SLV_ID_WIDTH),

    `AXI_INTERFACE_MODULE_OUTPUT(m_axi_ram, AXI_MST_ID_WIDTH),
    `AXI_INTERFACE_MODULE_OUTPUT(m_axi_uart, AXI_MST_ID_WIDTH),
    `AXI_INTERFACE_MODULE_OUTPUT(m_axi_clint, AXI_MST_ID_WIDTH),
    `AXI_INTERFACE_MODULE_OUTPUT(m_axi_timer, AXI_MST_ID_WIDTH),
    `AXI_INTERFACE_MODULE_OUTPUT(m_axi_bootrom, AXI_MST_ID_WIDTH),
    `AXI_INTERFACE_MODULE_OUTPUT(m_axi_sdcard, AXI_MST_ID_WIDTH),
    `AXI_INTERFACE_MODULE_OUTPUT(m_axi_debug, AXI_MST_ID_WIDTH),
    `AXI_INTERFACE_MODULE_OUTPUT(m_axi_plic, AXI_MST_ID_WIDTH),
    `AXI_INTERFACE_MODULE_OUTPUT(m_axi_gpio, AXI_MST_ID_WIDTH)
//    `AXI_INTERFACE_MODULE_OUTPUT(m_axi_eth_dma, AXI_MST_ID_WIDTH),
//    `AXI_INTERFACE_MODULE_OUTPUT(m_axi_eth, AXI_MST_ID_WIDTH),
//    `AXI_INTERFACE_MODULE_OUTPUT(m_axi_eth_leds, AXI_MST_ID_WIDTH)
);

axi_xbar_interface_wrapper #(
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_MST_ID_WIDTH(AXI_MST_ID_WIDTH),
    .AXI_SLV_ID_WIDTH(AXI_SLV_ID_WIDTH),
    .AXI_USER_WIDTH(AXI_USER_WIDTH)
) i_xbar_interface_wrapper (
    .aclk(aclk),
    .aresetn(aresetn),

    `AXI_INTERFACE_FORWARD(s_axi_cpu),
    `AXI_INTERFACE_FORWARD(s_axi_debug),
    //`AXI_INTERFACE_FORWARD(s_axi_eth_dma),
    //`AXI_INTERFACE_FORWARD(s_axi_eth_dma_sg),

    `AXI_INTERFACE_FORWARD(m_axi_ram),
    `AXI_INTERFACE_FORWARD(m_axi_uart),
    `AXI_INTERFACE_FORWARD(m_axi_clint),
    `AXI_INTERFACE_FORWARD(m_axi_timer),
    `AXI_INTERFACE_FORWARD(m_axi_bootrom),
    `AXI_INTERFACE_FORWARD(m_axi_sdcard),
    `AXI_INTERFACE_FORWARD(m_axi_debug),
    `AXI_INTERFACE_FORWARD(m_axi_plic),
    `AXI_INTERFACE_FORWARD(m_axi_gpio)
//    `AXI_INTERFACE_FORWARD(m_axi_eth_dma),
//    `AXI_INTERFACE_FORWARD(m_axi_eth),
//    `AXI_INTERFACE_FORWARD(m_axi_eth_leds)
);

endmodule
