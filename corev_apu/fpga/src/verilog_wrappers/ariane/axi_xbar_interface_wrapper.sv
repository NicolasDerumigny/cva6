`include "register_interface/assign.svh"
`include "rvfi_types.svh"

`include "ariane_xlnx_mapper.svh"

module axi_xbar_interface_wrapper #(
    parameter unsigned AXI_ADDR_WIDTH = 64,
    parameter unsigned AXI_DATA_WIDTH = 64,
    parameter unsigned AXI_MST_ID_WIDTH = 4,
    parameter unsigned AXI_SLV_ID_WIDTH = 6,
    parameter unsigned AXI_USER_WIDTH = 1
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
    //`AXI_INTERFACE_MODULE_OUTPUT(m_axi_eth_dma, AXI_MST_ID_WIDTH),
    //`AXI_INTERFACE_MODULE_OUTPUT(m_axi_eth, AXI_MST_ID_WIDTH),
    //`AXI_INTERFACE_MODULE_OUTPUT(m_axi_eth_leds, AXI_MST_ID_WIDTH)
);
  localparam config_pkg::cva6_cfg_t CVA6Cfg = build_fpga_config_pkg::build_fpga_config(
      cva6_config_pkg::cva6_cfg
  );
  localparam NrSlave = 2; // 4;
  localparam NrMaster = 9; //12;

  localparam axi_pkg::xbar_cfg_t AXI_XBAR_CFG = '{
      NoSlvPorts: NrSlave,
      NoMstPorts: NrMaster,
      MaxMstTrans: 9,  // Probably requires update
      MaxSlvTrans: 9,  // Probably requires update
      FallThrough: 1'b0,
      LatencyMode: axi_pkg::CUT_ALL_PORTS,
      AxiIdWidthSlvPorts: AXI_SLV_ID_WIDTH,
      AxiIdUsedSlvPorts: AXI_SLV_ID_WIDTH,
      UniqueIds: 1'b0,
      AxiAddrWidth: AXI_ADDR_WIDTH,
      AxiDataWidth: AXI_DATA_WIDTH,
      NoAddrRules: NrMaster
  };

  axi_pkg::xbar_rule_64_t [NrMaster-1:0] addr_map;
  assign addr_map = '{
    // RAM
    '{
        idx: 0,
        start_addr: 'h8000_0000,
        end_addr:   'hC000_0000
    },
    // UART
    '{
        idx: 1,
        start_addr: 'h1000_0000,
        end_addr:   'h1001_0000
    },
    // CLINT
    '{
        idx: 2,
        start_addr: 'h200_0000,
        end_addr:   'h204_0000
    },
    // TIMER
    '{
        idx: 3,
        start_addr: 'h1800_0000,
        end_addr:   'h1801_0000
    },
    // BOOTROM
    '{
        idx: 4,
        start_addr: 'h1_0000,
        end_addr:   'h2_0000
    },
    // SD CARD
    '{
        idx: 5,
        start_addr: 'h2000_0000,
        end_addr:   'h2001_0000
    },
    // DEBUG
    '{
        idx: 6,
        start_addr: 'h0_0000,
        end_addr:   'h1_0000
    },
    // PLIC
    '{
        idx: 7,
        start_addr: 'h0C00_0000,
        end_addr:   'h1000_0000
    },
    // GPIO
    '{
        idx: 8,
        start_addr: 'h4000_0000,
        end_addr:   'h4001_0000
    }/*
    // ETH_DMA
    '{
        idx: 9,
        start_addr: 'h41E0_0000,
        end_addr:   'h41E1_0000
    },
    // ETH
    '{
        idx: 10,
        start_addr: 'h40C0_0000,
        end_addr:   'h40C4_0000
    },
    // ETH_LEDS
    '{
        idx: 11,
        start_addr: 'h4001_0000,
        end_addr:   'h4002_0000
    }*/
 };

AXI_BUS #(
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ID_WIDTH  (AXI_MST_ID_WIDTH),
    .AXI_USER_WIDTH(AXI_USER_WIDTH)
) master[NrMaster-1:0] ();

AXI_BUS #(
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ID_WIDTH  (AXI_SLV_ID_WIDTH),
    .AXI_USER_WIDTH(AXI_USER_WIDTH)
) slave[NrSlave-1:0] ();

`ASSIGN_ARIANE_INTERFACE_FROM_XLNX_STYLE_INPUTS(s_axi_cpu, slave[0])
`ASSIGN_ARIANE_INTERFACE_FROM_XLNX_STYLE_INPUTS(s_axi_debug, slave[1])
//`ASSIGN_ARIANE_INTERFACE_FROM_XLNX_STYLE_INPUTS(s_axi_eth_dma_sg, slave[2])
//`ASSIGN_ARIANE_INTERFACE_FROM_XLNX_STYLE_INPUTS(s_axi_eth_dma, slave[3])

`ASSIGN_XLNX_INTERFACE_FROM_ARIANE_STYLE_INPUTS(m_axi_ram, master[0])
`ASSIGN_XLNX_INTERFACE_FROM_ARIANE_STYLE_INPUTS(m_axi_uart, master[1])
`ASSIGN_XLNX_INTERFACE_FROM_ARIANE_STYLE_INPUTS(m_axi_clint, master[2])
`ASSIGN_XLNX_INTERFACE_FROM_ARIANE_STYLE_INPUTS(m_axi_timer, master[3])
`ASSIGN_XLNX_INTERFACE_FROM_ARIANE_STYLE_INPUTS(m_axi_bootrom, master[4])
`ASSIGN_XLNX_INTERFACE_FROM_ARIANE_STYLE_INPUTS(m_axi_sdcard, master[5])
`ASSIGN_XLNX_INTERFACE_FROM_ARIANE_STYLE_INPUTS(m_axi_debug, master[6])
`ASSIGN_XLNX_INTERFACE_FROM_ARIANE_STYLE_INPUTS(m_axi_plic, master[7])
`ASSIGN_XLNX_INTERFACE_FROM_ARIANE_STYLE_INPUTS(m_axi_gpio, master[8])
//`ASSIGN_XLNX_INTERFACE_FROM_ARIANE_STYLE_INPUTS(m_axi_eth_dma, master[9])
//`ASSIGN_XLNX_INTERFACE_FROM_ARIANE_STYLE_INPUTS(m_axi_eth, master[10])
//`ASSIGN_XLNX_INTERFACE_FROM_ARIANE_STYLE_INPUTS(m_axi_eth_leds, master[11])

axi_xbar_intf #(
    .AXI_USER_WIDTH(AXI_USER_WIDTH),
    .Cfg           (AXI_XBAR_CFG),
    .rule_t        (axi_pkg::xbar_rule_64_t)
) i_axi_xbar_intf (
    .clk_i                (aclk),
    .rst_ni               (aresetn),
    .test_i               ('0),
    .slv_ports            (slave),
    .mst_ports            (master),
    .addr_map_i           (addr_map),
    .en_default_mst_port_i('0),
    .default_mst_port_i   ('0)
);

endmodule
