`include "ariane_xlnx_mapper.svh"
module axi_riscv_atomics_wrapper_verilog
#(
    parameter AXI_ADDR_WIDTH = 64,
    parameter AXI_DATA_WIDTH = 64,
    parameter AXI_ID_WIDTH = 10,
    parameter AXI_USER_WIDTH = 1,
    // Maximum number of AXI write bursts outstanding at the same time
    parameter AXI_MAX_WRITE_TXNS = 1,
    // Word width of the widest RISC-V processor that can issue requests to this module.
    // 32 for RV32; 64 for RV64, where both 32-bit (.W suffix) and 64-bit (.D suffix) AMOs are
    // supported if `aw_strb` is set correctly.
    parameter RISCV_WORD_WIDTH = 64
)(
     // TODO if this port is not named CLK, device tree generation in Vitis fails...
    (*X_INTERFACE_PARAMETER = "FREQ_HZ 50000000"*)
    input wire CLK,
    input wire aresetn,
    // TODO dummy interrupt for device tree generation in Vitis
    (*X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 dummy_irq_in INTERRUPT", X_INTERFACE_PARAMETER = "SENSITIVITY EDGE_RISING" *)
    input wire [1 : 0] dummy_irq_in,

    `AXI_INTERFACE_MODULE_INPUT(s_axi_in),
    `AXI_INTERFACE_MODULE_OUTPUT(m_axi_out)
);

axi_riscv_atomics #(
        .AXI_ADDR_WIDTH     (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH     (AXI_DATA_WIDTH),
        .AXI_ID_WIDTH       (AXI_ID_WIDTH),
        .AXI_USER_WIDTH     (AXI_USER_WIDTH),
        .AXI_MAX_WRITE_TXNS (AXI_MAX_WRITE_TXNS),
        .RISCV_WORD_WIDTH   (RISCV_WORD_WIDTH)
    ) i_atomics (
        .clk_i           ( CLK          ),
        .rst_ni          ( aresetn       ),
        .slv_aw_addr_i   ( s_axi_in_awaddr   ),
        .slv_aw_prot_i   ( s_axi_in_awprot   ),
        .slv_aw_region_i ( s_axi_in_awregion ),
        .slv_aw_atop_i   ( s_axi_in_awatop   ),
        .slv_aw_len_i    ( s_axi_in_awlen    ),
        .slv_aw_size_i   ( s_axi_in_awsize   ),
        .slv_aw_burst_i  ( s_axi_in_awburst  ),
        .slv_aw_lock_i   ( s_axi_in_awlock   ),
        .slv_aw_cache_i  ( s_axi_in_awcache  ),
        .slv_aw_qos_i    ( s_axi_in_awqos    ),
        .slv_aw_id_i     ( s_axi_in_awid     ),
        .slv_aw_user_i   ( s_axi_in_awuser   ),
        .slv_aw_ready_o  ( s_axi_in_awready  ),
        .slv_aw_valid_i  ( s_axi_in_awvalid  ),
        .slv_ar_addr_i   ( s_axi_in_araddr   ),
        .slv_ar_prot_i   ( s_axi_in_arprot   ),
        .slv_ar_region_i ( s_axi_in_arregion ),
        .slv_ar_len_i    ( s_axi_in_arlen    ),
        .slv_ar_size_i   ( s_axi_in_arsize   ),
        .slv_ar_burst_i  ( s_axi_in_arburst  ),
        .slv_ar_lock_i   ( s_axi_in_arlock   ),
        .slv_ar_cache_i  ( s_axi_in_arcache  ),
        .slv_ar_qos_i    ( s_axi_in_arqos    ),
        .slv_ar_id_i     ( s_axi_in_arid     ),
        .slv_ar_user_i   ( s_axi_in_aruser   ),
        .slv_ar_ready_o  ( s_axi_in_arready  ),
        .slv_ar_valid_i  ( s_axi_in_arvalid  ),
        .slv_w_data_i    ( s_axi_in_wdata    ),
        .slv_w_strb_i    ( s_axi_in_wstrb    ),
        .slv_w_user_i    ( s_axi_in_wuser    ),
        .slv_w_last_i    ( s_axi_in_wlast    ),
        .slv_w_ready_o   ( s_axi_in_wready   ),
        .slv_w_valid_i   ( s_axi_in_wvalid   ),
        .slv_r_data_o    ( s_axi_in_rdata    ),
        .slv_r_resp_o    ( s_axi_in_rresp    ),
        .slv_r_last_o    ( s_axi_in_rlast    ),
        .slv_r_id_o      ( s_axi_in_rid      ),
        .slv_r_user_o    ( s_axi_in_ruser    ),
        .slv_r_ready_i   ( s_axi_in_rready   ),
        .slv_r_valid_o   ( s_axi_in_rvalid   ),
        .slv_b_resp_o    ( s_axi_in_bresp    ),
        .slv_b_id_o      ( s_axi_in_bid      ),
        .slv_b_user_o    ( s_axi_in_buser    ),
        .slv_b_ready_i   ( s_axi_in_bready   ),
        .slv_b_valid_o   ( s_axi_in_bvalid   ),
        .mst_aw_addr_o   ( m_axi_out_awaddr   ),
        .mst_aw_prot_o   ( m_axi_out_awprot   ),
        .mst_aw_region_o ( m_axi_out_awregion ),
        .mst_aw_atop_o   ( m_axi_out_awatop   ),
        .mst_aw_len_o    ( m_axi_out_awlen    ),
        .mst_aw_size_o   ( m_axi_out_awsize   ),
        .mst_aw_burst_o  ( m_axi_out_awburst  ),
        .mst_aw_lock_o   ( m_axi_out_awlock   ),
        .mst_aw_cache_o  ( m_axi_out_awcache  ),
        .mst_aw_qos_o    ( m_axi_out_awqos    ),
        .mst_aw_id_o     ( m_axi_out_awid     ),
        .mst_aw_user_o   ( m_axi_out_awuser   ),
        .mst_aw_ready_i  ( m_axi_out_awready  ),
        .mst_aw_valid_o  ( m_axi_out_awvalid  ),
        .mst_ar_addr_o   ( m_axi_out_araddr   ),
        .mst_ar_prot_o   ( m_axi_out_arprot   ),
        .mst_ar_region_o ( m_axi_out_arregion ),
        .mst_ar_len_o    ( m_axi_out_arlen    ),
        .mst_ar_size_o   ( m_axi_out_arsize   ),
        .mst_ar_burst_o  ( m_axi_out_arburst  ),
        .mst_ar_lock_o   ( m_axi_out_arlock   ),
        .mst_ar_cache_o  ( m_axi_out_arcache  ),
        .mst_ar_qos_o    ( m_axi_out_arqos    ),
        .mst_ar_id_o     ( m_axi_out_arid     ),
        .mst_ar_user_o   ( m_axi_out_aruser   ),
        .mst_ar_ready_i  ( m_axi_out_arready  ),
        .mst_ar_valid_o  ( m_axi_out_arvalid  ),
        .mst_w_data_o    ( m_axi_out_wdata    ),
        .mst_w_strb_o    ( m_axi_out_wstrb    ),
        .mst_w_user_o    ( m_axi_out_wuser    ),
        .mst_w_last_o    ( m_axi_out_wlast    ),
        .mst_w_ready_i   ( m_axi_out_wready   ),
        .mst_w_valid_o   ( m_axi_out_wvalid   ),
        .mst_r_data_i    ( m_axi_out_rdata    ),
        .mst_r_resp_i    ( m_axi_out_rresp    ),
        .mst_r_last_i    ( m_axi_out_rlast    ),
        .mst_r_id_i      ( m_axi_out_rid      ),
        .mst_r_user_i    ( m_axi_out_ruser    ),
        .mst_r_ready_o   ( m_axi_out_rready   ),
        .mst_r_valid_i   ( m_axi_out_rvalid   ),
        .mst_b_resp_i    ( m_axi_out_bresp    ),
        .mst_b_id_i      ( m_axi_out_bid      ),
        .mst_b_user_i    ( m_axi_out_buser    ),
        .mst_b_ready_o   ( m_axi_out_bready   ),
        .mst_b_valid_i   ( m_axi_out_bvalid   )
    );

endmodule