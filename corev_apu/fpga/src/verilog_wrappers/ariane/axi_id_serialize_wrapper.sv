// Copyright 2025 INRIA and Telecom SudParis.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Nicolas Derumigny <nicolas.derumigny@inria.fr>
//
// Date: 25.08.2025
// Description: Wrapper for `axi_id_serialize`

`include "axi/assign.svh"
`include "axi/typedef.svh"

module axi_id_serialize_interface #(
    parameter AXI_SLV_PORT_ID_WIDTH = 32'd0,
    parameter AXI_SLV_PORT_MAX_TXNS = 32'd0,
    parameter AXI_MST_PORT_ID_WIDTH = 32'd0,
    parameter AXI_MST_PORT_MAX_UNIQ_IDS = 32'd0,
    parameter AXI_MST_PORT_MAX_TXNS_PER_ID = 32'd0,
    parameter AXI_ADDR_WIDTH = 32'd0,
    parameter AXI_DATA_WIDTH = 32'd0,
    parameter AXI_USER_WIDTH = 32'd0
) (
    /** Input AXI **/
    /* AW Channel  */
    input wire [AXI_SLV_PORT_ID_WIDTH - 1 : 0] s_axi_awid,
    input wire [AXI_ADDR_WIDTH - 1 : 0] s_axi_awaddr,
    input wire [7:0] s_axi_awlen,
    input wire [2:0] s_axi_awsize,
    input wire [1:0] s_axi_awburst,
    input wire s_axi_awlock,
    input wire [3:0] s_axi_awcache,
    input wire [2:0] s_axi_awprot,
    input wire [3:0] s_axi_awqos,
    input wire [5:0] s_axi_awatop,
    input wire [3:0] s_axi_awregion,
    input wire [AXI_USER_WIDTH-1:0] s_axi_awuser,
    input wire s_axi_awvalid,
    output wire s_axi_awready,
    /* W Channel */
    input wire [AXI_DATA_WIDTH - 1 : 0] s_axi_wdata,
    input wire [AXI_DATA_WIDTH/8 - 1 : 0] s_axi_wstrb,
    input wire s_axi_wlast,
    input wire [AXI_USER_WIDTH-1:0] s_axi_wuser,
    input wire s_axi_wvalid,
    output wire s_axi_wready,
    /* B Channel */
    output wire [AXI_SLV_PORT_ID_WIDTH - 1 : 0] s_axi_bid,
    output wire [1 : 0] s_axi_bresp,
    output wire [AXI_USER_WIDTH-1:0] s_axi_buser,
    output wire s_axi_bvalid,
    input wire s_axi_bready,
    /* AR Channel*/
    input wire [AXI_SLV_PORT_ID_WIDTH - 1 : 0] s_axi_arid,
    input wire [AXI_ADDR_WIDTH - 1 : 0] s_axi_araddr,
    input wire [7:0] s_axi_arlen,
    input wire [2:0] s_axi_arsize,
    input wire [1:0] s_axi_arburst,
    input wire s_axi_arlock,
    input wire [3:0] s_axi_arcache,
    input wire [2:0] s_axi_arprot,
    input wire [3:0] s_axi_arqos,
    input wire [3:0] s_axi_arregion,
    input wire [AXI_USER_WIDTH-1:0] s_axi_aruser,
    input wire s_axi_arvalid,
    output wire s_axi_arready,
    /* R Channel */
    output wire [AXI_DATA_WIDTH - 1 : 0] s_axi_rdata,
    output wire [1 : 0] s_axi_rresp,
    output wire s_axi_rlast,
    output wire [AXI_SLV_PORT_ID_WIDTH - 1 : 0] s_axi_rid,
    output wire [AXI_USER_WIDTH-1:0] s_axi_ruser,
    output wire s_axi_rvalid,
    input wire s_axi_rready,

    /** Output AXI **/
    /* AW Channel  */
    output wire [AXI_MST_PORT_ID_WIDTH - 1 : 0] m_axi_awid,
    output wire [AXI_ADDR_WIDTH - 1 : 0] m_axi_awaddr,
    output wire [7:0] m_axi_awlen,
    output wire [2:0] m_axi_awsize,
    output wire [1:0] m_axi_awburst,
    output wire m_axi_awlock,
    output wire [3:0] m_axi_awcache,
    output wire [2:0] m_axi_awprot,
    output wire [3:0] m_axi_awqos,
    output wire [5:0] m_axi_awatop,
    output wire [3:0] m_axi_awregion,
    output wire [AXI_USER_WIDTH-1:0] m_axi_awuser,
    output wire m_axi_awvalid,
    input wire m_axi_awready,
    /* W Channel */
    output wire [AXI_DATA_WIDTH - 1 : 0] m_axi_wdata,
    output wire [AXI_DATA_WIDTH/8 - 1 : 0] m_axi_wstrb,
    output wire m_axi_wlast,
    output wire [AXI_USER_WIDTH-1:0] m_axi_wuser,
    output wire m_axi_wvalid,
    input wire m_axi_wready,
    /* B Channel */
    input wire [AXI_MST_PORT_ID_WIDTH - 1 : 0] m_axi_bid,
    input wire [1 : 0] m_axi_bresp,
    input wire [AXI_USER_WIDTH-1:0] m_axi_buser,
    input wire m_axi_bvalid,
    output wire m_axi_bready,
    /* AR Channel*/
    output wire [AXI_MST_PORT_ID_WIDTH - 1 : 0] m_axi_arid,
    output wire [AXI_ADDR_WIDTH - 1 : 0] m_axi_araddr,
    output wire [7:0] m_axi_arlen,
    output wire [2:0] m_axi_arsize,
    output wire [1:0] m_axi_arburst,
    output wire m_axi_arlock,
    output wire [3:0] m_axi_arcache,
    output wire [2:0] m_axi_arprot,
    output wire [3:0] m_axi_arqos,
    output wire [3:0] m_axi_arregion,
    output wire [AXI_USER_WIDTH-1:0] m_axi_aruser,
    output wire m_axi_arvalid,
    input wire [AXI_USER_WIDTH-1:0] m_axi_arready,
    /* R Channel */
    input wire [AXI_DATA_WIDTH - 1 : 0] m_axi_rdata,
    input wire [1 : 0] m_axi_rresp,
    input wire m_axi_rlast,
    input wire [AXI_MST_PORT_ID_WIDTH - 1 : 0] m_axi_rid,
    input wire [AXI_USER_WIDTH-1:0] m_axi_ruser,
    input wire m_axi_rvalid,
    output wire m_axi_rready,

    /*Clock, unused but avoid Vivado errors*/
    input wire  aclk,
    input logic rstn
);

  /** Input AXI **/
  AXI_BUS #(
      .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
      .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
      .AXI_ID_WIDTH  (AXI_SLV_PORT_ID_WIDTH),
      .AXI_USER_WIDTH(AXI_USER_WIDTH)
  ) slv ();
  `ASSIGN_ARIANE_INTERFACE_FROM_XLNX_STYLE_INPUTS(s_axi, slv)

  /** Output AXI **/
  AXI_BUS #(
      .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
      .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
      .AXI_ID_WIDTH  (AXI_MST_PORT_ID_WIDTH),
      .AXI_USER_WIDTH(AXI_USER_WIDTH)
  ) mst ();
  `ASSIGN_XLNX_INTERFACE_FROM_ARIANE_STYLE_INPUTS(m_axi, mst)

  axi_id_serialize_intf #(
      .AXI_SLV_PORT_ID_WIDTH       (AXI_SLV_PORT_ID_WIDTH),
      .AXI_SLV_PORT_MAX_TXNS       (AXI_SLV_PORT_MAX_TXNS),
      .AXI_MST_PORT_ID_WIDTH       (AXI_MST_PORT_ID_WIDTH),
      .AXI_MST_PORT_MAX_UNIQ_IDS   (AXI_MST_PORT_MAX_UNIQ_IDS),
      .AXI_MST_PORT_MAX_TXNS_PER_ID(AXI_MST_PORT_MAX_TXNS_PER_ID),
      .AXI_ADDR_WIDTH              (AXI_ADDR_WIDTH),
      .AXI_DATA_WIDTH              (AXI_DATA_WIDTH),
      .AXI_USER_WIDTH              (AXI_USER_WIDTH)
  ) i_axi_id_serialize_intf (
      .clk_i (aclk),
      .rst_ni(rstn),

      .slv(slv),
      .mst(mst)
  );

endmodule
