

module axi_xbar_wrapper #(
    /*FIXME: parameter axi_pkg::xbar_cfg_t Cfg           = '0,
    parameter bit                 ATOPs         = 1'b1,
    parameter type                slv_aw_chan_t = logic,
    parameter type                mst_aw_chan_t = logic,
    parameter type                w_chan_t      = logic,
    parameter type                slv_b_chan_t  = logic,
    parameter type                mst_b_chan_t  = logic,
    parameter type                slv_ar_chan_t = logic,
    parameter type                mst_ar_chan_t = logic,
    parameter type                slv_r_chan_t  = logic,
    parameter type                mst_r_chan_t  = logic,
    parameter type                slv_req_t     = logic,
    parameter type                slv_resp_t    = logic,
    parameter type                mst_req_t     = logic,
    parameter type                mst_resp_t    = logic
    parameter type                rule_t        = axi_pkg::xbar_rule_64_t */
    parameter NB_MASTER_PORTS = 1,
    parameter NB_SLAVE_PORTS = 2,
    parameter NB_ADDR_RULES = 2
) (
    input  wire                                                  clk_i,
    input  wire                                                  rst_ni,
    input  wire                                                  test_i,
    input  wire[NB_MASTER_PORTS-1:0]                             slv_ports_req_i,
    output wire[NB_SLAVE_PORTS-1:0]                              slv_ports_resp_o,
    output wire[NB_MASTER_PORTS-1:0]                             mst_ports_req_o,
    input  wire[NB_MASTER_PORTS-1:0]                             mst_ports_resp_i,
    input  wire[NB_ADDR_RULES-1:0]                               addr_map_i,
    input  wire[NB_SLAVE_PORTS-1:0]                              en_default_mst_port_i,
    input  wire[NB_SLAVE_PORTS-1:0][$clog2(NB_MASTER_PORTS)-1:0] default_mst_port_i
);

  axi_xbar #(
      /*FIXME: .ATOPs        (ATOPs),
      .slv_aw_chan_t(slv_aw_chan_t),
      .mst_aw_chan_t(mst_aw_chan_t),
      .w_chan_t     (w_chan_t),
      .slv_b_chan_t (slv_b_chan_t),
      .mst_b_chan_t (mst_b_chan_t),
      .slv_ar_chan_t(slv_ar_chan_t),
      .mst_ar_chan_t(mst_ar_chan_t),
      .slv_r_chan_t (slv_r_chan_t),
      .mst_r_chan_t (mst_r_chan_t),
      .slv_req_t    (slv_req_t),
      .slv_resp_t   (slv_resp_t),
      .mst_req_t    (mst_req_t),
      .mst_resp_t   (mst_resp_t),
      .rule_t       (rule_t)*/
  ) i_axi_xbar (
      .clk_i                (clk_i),
      .rst_ni               (rst_ni),
      .test_i               (test_i),
      .slv_ports_req_i      (slv_ports_req_i),
      .slv_ports_resp_o     (slv_ports_resp_o),
      .mst_ports_req_o      (mst_ports_req_o),
      .mst_ports_resp_i     (mst_ports_resp_i),
      .addr_map_i           (addr_map_i),
      .en_default_mst_port_i(en_default_mst_port_i),
      .default_mst_port_i   (default_mst_port_i)
  );

endmodule
