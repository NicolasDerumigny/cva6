`include "ariane_xlnx_mapper.svh"
`include "register_interface/typedef.svh"
`include "register_interface/assign.svh"

module ariane_peripherals_wrapper#(
    parameter AXI_ID_WIDTH   = 10,
    parameter AXI_ADDR_WIDTH = 64,
    parameter AXI_DATA_WIDTH = 64,
    parameter AXI_USER_WIDTH = 1,
    parameter NR_CORES       = 1
)
(
    input logic aclk,
    input logic aresetn,
    input wire uart_irq_i,
    input wire spi_irq_i,
    input wire eth_irq_i,
    input wire [ariane_soc::NumSources-1:7] irq_i,
    `AXI_INTERFACE_MODULE_INPUT(s_axi_plic, AXI_ID_WIDTH),
    `AXI_INTERFACE_MODULE_INPUT(s_axi_timer, AXI_ID_WIDTH),
    output logic [NR_CORES*2-1:0] irq_out
);

  AXI_BUS #(
      .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
      .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
      .AXI_ID_WIDTH  (AXI_ID_WIDTH),
      .AXI_USER_WIDTH(AXI_USER_WIDTH)
  ) plic(), timer();

  `ASSIGN_ARIANE_INTERFACE_FROM_XLNX_STYLE_INPUTS(s_axi_plic,plic)
  `ASSIGN_ARIANE_INTERFACE_FROM_XLNX_STYLE_INPUTS(s_axi_timer,timer)

  // PLIC
  logic [ariane_soc::NumSources-1:0] irq_sources;

  // External interrupt sources
  assign irq_sources[0] = uart_irq_i;
  assign irq_sources[1] = spi_irq_i;
  assign irq_sources[2] = eth_irq_i;
  assign irq_sources[ariane_soc::NumSources-1:7] = irq_i[ariane_soc::NumSources-1:7];

  REG_BUS #(
      .ADDR_WIDTH ( 32 ),
      .DATA_WIDTH ( 32 )
  ) reg_bus (aclk);

  logic         plic_penable;
  logic         plic_pwrite;
  logic [31:0]  plic_paddr;
  logic         plic_psel;
  logic [31:0]  plic_pwdata;
  logic [31:0]  plic_prdata;
  logic         plic_pready;
  logic         plic_pslverr;

  axi2apb_64_32 #(
      .AXI4_ADDRESS_WIDTH ( AXI_ADDR_WIDTH ),
      .AXI4_RDATA_WIDTH   ( AXI_DATA_WIDTH ),
      .AXI4_WDATA_WIDTH   ( AXI_DATA_WIDTH ),
      .AXI4_ID_WIDTH      ( AXI_ID_WIDTH   ),
      .AXI4_USER_WIDTH    ( AXI_USER_WIDTH ),
      .BUFF_DEPTH_SLAVE   ( 2              ),
      .APB_ADDR_WIDTH     ( 32             )
  ) i_axi2apb_64_32_plic (
      .ACLK      ( aclk          ),
      .ARESETn   ( aresetn         ),
      .test_en_i ( 1'b0           ),
      .AWID_i    ( plic.aw_id     ),
      .AWADDR_i  ( plic.aw_addr   ),
      .AWLEN_i   ( plic.aw_len    ),
      .AWSIZE_i  ( plic.aw_size   ),
      .AWBURST_i ( plic.aw_burst  ),
      .AWLOCK_i  ( plic.aw_lock   ),
      .AWCACHE_i ( plic.aw_cache  ),
      .AWPROT_i  ( plic.aw_prot   ),
      .AWREGION_i( plic.aw_region ),
      .AWUSER_i  ( plic.aw_user   ),
      .AWQOS_i   ( plic.aw_qos    ),
      .AWVALID_i ( plic.aw_valid  ),
      .AWREADY_o ( plic.aw_ready  ),
      .WDATA_i   ( plic.w_data    ),
      .WSTRB_i   ( plic.w_strb    ),
      .WLAST_i   ( plic.w_last    ),
      .WUSER_i   ( plic.w_user    ),
      .WVALID_i  ( plic.w_valid   ),
      .WREADY_o  ( plic.w_ready   ),
      .BID_o     ( plic.b_id      ),
      .BRESP_o   ( plic.b_resp    ),
      .BVALID_o  ( plic.b_valid   ),
      .BUSER_o   ( plic.b_user    ),
      .BREADY_i  ( plic.b_ready   ),
      .ARID_i    ( plic.ar_id     ),
      .ARADDR_i  ( plic.ar_addr   ),
      .ARLEN_i   ( plic.ar_len    ),
      .ARSIZE_i  ( plic.ar_size   ),
      .ARBURST_i ( plic.ar_burst  ),
      .ARLOCK_i  ( plic.ar_lock   ),
      .ARCACHE_i ( plic.ar_cache  ),
      .ARPROT_i  ( plic.ar_prot   ),
      .ARREGION_i( plic.ar_region ),
      .ARUSER_i  ( plic.ar_user   ),
      .ARQOS_i   ( plic.ar_qos    ),
      .ARVALID_i ( plic.ar_valid  ),
      .ARREADY_o ( plic.ar_ready  ),
      .RID_o     ( plic.r_id      ),
      .RDATA_o   ( plic.r_data    ),
      .RRESP_o   ( plic.r_resp    ),
      .RLAST_o   ( plic.r_last    ),
      .RUSER_o   ( plic.r_user    ),
      .RVALID_o  ( plic.r_valid   ),
      .RREADY_i  ( plic.r_ready   ),
      .PENABLE   ( plic_penable   ),
      .PWRITE    ( plic_pwrite    ),
      .PADDR     ( plic_paddr     ),
      .PSEL      ( plic_psel      ),
      .PWDATA    ( plic_pwdata    ),
      .PRDATA    ( plic_prdata    ),
      .PREADY    ( plic_pready    ),
      .PSLVERR   ( plic_pslverr   )
  );

  apb_to_reg i_apb_to_reg (
      .clk_i     ( aclk         ),
      .rst_ni    ( aresetn      ),
      .penable_i ( plic_penable ),
      .pwrite_i  ( plic_pwrite  ),
      .paddr_i   ( plic_paddr   ),
      .psel_i    ( plic_psel    ),
      .pwdata_i  ( plic_pwdata  ),
      .prdata_o  ( plic_prdata  ),
      .pready_o  ( plic_pready  ),
      .pslverr_o ( plic_pslverr ),
      .reg_o     ( reg_bus      )
  );

  // define reg type according to REG_BUS above
  `REG_BUS_TYPEDEF_ALL(plic, logic[31:0], logic[31:0], logic[3:0])
  plic_req_t plic_req;
  plic_rsp_t plic_rsp;

  // assign REG_BUS.out to (req_t, rsp_t) pair
  `REG_BUS_ASSIGN_TO_REQ(plic_req, reg_bus)
  `REG_BUS_ASSIGN_FROM_RSP(reg_bus, plic_rsp)

  plic_top #(
    .N_SOURCE    ( ariane_soc::NumSources  ),
    .N_TARGET    ( NR_CORES*2              ),
    .MAX_PRIO    ( ariane_soc::MaxPriority ),
    .reg_req_t   ( plic_req_t              ),
    .reg_rsp_t   ( plic_rsp_t              )
  ) i_plic (
    .clk_i         ( aclk        ),
    .rst_ni        ( aresetn     ),
    .req_i         ( plic_req    ),
    .resp_o        ( plic_rsp    ),
    .le_i          ( '0          ), // 0:level 1:edge
    .irq_sources_i ( irq_sources ),
    .eip_targets_o ( irq_out     )
  );

  // Timer
  begin : gen_timer
      logic         timer_penable;
      logic         timer_pwrite;
      logic [31:0]  timer_paddr;
      logic         timer_psel;
      logic [31:0]  timer_pwdata;
      logic [31:0]  timer_prdata;
      logic         timer_pready;
      logic         timer_pslverr;

      axi2apb_64_32 #(
          .AXI4_ADDRESS_WIDTH ( AXI_ADDR_WIDTH ),
          .AXI4_RDATA_WIDTH   ( AXI_DATA_WIDTH ),
          .AXI4_WDATA_WIDTH   ( AXI_DATA_WIDTH ),
          .AXI4_ID_WIDTH      ( AXI_ID_WIDTH   ),
          .AXI4_USER_WIDTH    ( AXI_USER_WIDTH ),
          .BUFF_DEPTH_SLAVE   ( 2              ),
          .APB_ADDR_WIDTH     ( 32             )
      ) i_axi2apb_64_32_timer (
          .ACLK      ( aclk           ),
          .ARESETn   ( aresetn          ),
          .test_en_i ( 1'b0            ),
          .AWID_i    ( timer.aw_id     ),
          .AWADDR_i  ( timer.aw_addr   ),
          .AWLEN_i   ( timer.aw_len    ),
          .AWSIZE_i  ( timer.aw_size   ),
          .AWBURST_i ( timer.aw_burst  ),
          .AWLOCK_i  ( timer.aw_lock   ),
          .AWCACHE_i ( timer.aw_cache  ),
          .AWPROT_i  ( timer.aw_prot   ),
          .AWREGION_i( timer.aw_region ),
          .AWUSER_i  ( timer.aw_user   ),
          .AWQOS_i   ( timer.aw_qos    ),
          .AWVALID_i ( timer.aw_valid  ),
          .AWREADY_o ( timer.aw_ready  ),
          .WDATA_i   ( timer.w_data    ),
          .WSTRB_i   ( timer.w_strb    ),
          .WLAST_i   ( timer.w_last    ),
          .WUSER_i   ( timer.w_user    ),
          .WVALID_i  ( timer.w_valid   ),
          .WREADY_o  ( timer.w_ready   ),
          .BID_o     ( timer.b_id      ),
          .BRESP_o   ( timer.b_resp    ),
          .BVALID_o  ( timer.b_valid   ),
          .BUSER_o   ( timer.b_user    ),
          .BREADY_i  ( timer.b_ready   ),
          .ARID_i    ( timer.ar_id     ),
          .ARADDR_i  ( timer.ar_addr   ),
          .ARLEN_i   ( timer.ar_len    ),
          .ARSIZE_i  ( timer.ar_size   ),
          .ARBURST_i ( timer.ar_burst  ),
          .ARLOCK_i  ( timer.ar_lock   ),
          .ARCACHE_i ( timer.ar_cache  ),
          .ARPROT_i  ( timer.ar_prot   ),
          .ARREGION_i( timer.ar_region ),
          .ARUSER_i  ( timer.ar_user   ),
          .ARQOS_i   ( timer.ar_qos    ),
          .ARVALID_i ( timer.ar_valid  ),
          .ARREADY_o ( timer.ar_ready  ),
          .RID_o     ( timer.r_id      ),
          .RDATA_o   ( timer.r_data    ),
          .RRESP_o   ( timer.r_resp    ),
          .RLAST_o   ( timer.r_last    ),
          .RUSER_o   ( timer.r_user    ),
          .RVALID_o  ( timer.r_valid   ),
          .RREADY_i  ( timer.r_ready   ),
          .PENABLE   ( timer_penable   ),
          .PWRITE    ( timer_pwrite    ),
          .PADDR     ( timer_paddr     ),
          .PSEL      ( timer_psel      ),
          .PWDATA    ( timer_pwdata    ),
          .PRDATA    ( timer_prdata    ),
          .PREADY    ( timer_pready    ),
          .PSLVERR   ( timer_pslverr   )
      );

      apb_timer #(
              .APB_ADDR_WIDTH ( 32 ),
              .TIMER_CNT      ( 2  )
      ) i_timer (
          .HCLK    ( aclk             ),
          .HRESETn ( aresetn           ),
          .PSEL    ( timer_psel       ),
          .PENABLE ( timer_penable    ),
          .PWRITE  ( timer_pwrite     ),
          .PADDR   ( timer_paddr      ),
          .PWDATA  ( timer_pwdata     ),
          .PRDATA  ( timer_prdata     ),
          .PREADY  ( timer_pready     ),
          .PSLVERR ( timer_pslverr    ),
          .irq_o   ( irq_sources[6:3] )
      );
  end

endmodule
