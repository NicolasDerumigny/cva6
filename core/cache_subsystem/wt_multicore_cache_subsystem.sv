module multicore_wt_cache_subsystem
  import ariane_pkg::*;
  import wt_cache_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg        = config_pkg::cva6_cfg_empty,
    parameter type                   dcache_req_i_t = logic,
    parameter type                   dcache_req_o_t = logic,
    parameter type                   noc_req_t      = logic,
    parameter type                   noc_resp_t     = logic,
    parameter type                   icache_req_t   = logic,
    parameter type                   icache_rtrn_t  = logic,
    parameter unsigned               NumPorts       = 4
) (
    input logic clk_i,
    input logic rst_ni,

    // I$
    input logic icache_miss_valid_i,
    output logic icache_miss_ready_o,
    input icache_req_t icache_miss_i,
    output logic icache_miss_resp_valid_o,
    output icache_rtrn_t icache_miss_resp_o,

    // D$
    // Cache management
    input logic dcache_enable_i,  // from CSR
    input logic dcache_flush_i,  // high until acknowledged
    output logic dcache_flush_ack_o,     // send a single cycle acknowledge signal when the cache is flushed
    output logic dcache_miss_o,  // we missed on a ld/st
    // For Performance Counter
    output logic [NumPorts-1:0][CVA6Cfg.DCACHE_SET_ASSOC-1:0] miss_vld_bits_o,
    // AMO interface
    input amo_req_t dcache_amo_req_i,
    output amo_resp_t dcache_amo_resp_o,
    // Request ports
    input dcache_req_i_t [NumPorts-1:0] dcache_req_ports_i,  // to/from LSU
    output dcache_req_o_t [NumPorts-1:0] dcache_req_ports_o,  // to/from LSU
    // writebuffer status
    output logic wbuffer_empty_o,
    output logic wbuffer_not_ni_o,
    // memory side
    output noc_req_t noc_req_o,
    input noc_resp_t noc_resp_i,
    // Invalidations
    input logic [63:0] inval_addr_i,
    input logic inval_valid_i,
    output logic inval_ready_o

);

  localparam type dcache_inval_t = struct packed {
    logic                                      vld;  // invalidate only affected way
    logic                                      all;  // invalidate all ways
    logic [CVA6Cfg.DCACHE_INDEX_WIDTH-1:0]     idx;  // physical address to invalidate
    logic [CVA6Cfg.DCACHE_SET_ASSOC_WIDTH-1:0] way;  // way to invalidate
  };
  localparam type dcache_req_t = struct packed {
    wt_cache_pkg::dcache_out_t rtype;  // see definitions above
    logic [2:0]                                      size;        // transaction size: 000=Byte 001=2Byte; 010=4Byte; 011=8Byte; 111=Cache line (16/32Byte)
    logic [CVA6Cfg.DCACHE_SET_ASSOC_WIDTH-1:0] way;  // way to replace
    logic [CVA6Cfg.PLEN-1:0] paddr;  // physical address
    logic [CVA6Cfg.XLEN-1:0] data;  // word width of processor (no block stores at the moment)
    logic [CVA6Cfg.DCACHE_USER_WIDTH-1:0]          user;        // user width of processor (no block stores at the moment)
    logic nc;  // noncacheable
    logic [CVA6Cfg.MEM_TID_WIDTH-1:0] tid;  // thread id (used as transaction id in Ariane)
    ariane_pkg::amo_t amo_op;  // amo opcode
  };
  localparam type dcache_rtrn_t = struct packed {
    wt_cache_pkg::dcache_in_t rtype;  // see definitions above
    logic [CVA6Cfg.DCACHE_LINE_WIDTH-1:0] data;  // full cache line width
    logic [CVA6Cfg.DCACHE_USER_LINE_WIDTH-1:0] user;  // user bits
    dcache_inval_t inv;  // invalidation vector
    logic [CVA6Cfg.MEM_TID_WIDTH-1:0] tid;  // thread id (used as transaction id in Ariane)
  };

  logic dcache_adapter_data_req, adapter_dcache_data_ack, adapter_dcache_rtrn_vld;
  dcache_req_t  dcache_adapter;
  dcache_rtrn_t adapter_dcache;

  wt_dcache #(
      .CVA6Cfg   (CVA6Cfg),
      .dcache_req_i_t(dcache_req_i_t),
      .dcache_req_o_t(dcache_req_o_t),
      .dcache_req_t(dcache_req_t),
      .dcache_rtrn_t(dcache_rtrn_t),
      .RdAmoTxId(1)
  ) i_wt_dcache (
      .clk_i           (clk_i),
      .rst_ni          (rst_ni),
      .enable_i        (dcache_enable_i),
      .flush_i         (dcache_flush_i),
      .flush_ack_o     (dcache_flush_ack_o),
      .amo_req_i       (dcache_amo_req_i),
      .amo_resp_o      (dcache_amo_resp_o),
      .miss_o          (dcache_miss_o),
      .miss_vld_bits_o (miss_vld_bits_o),
      .req_ports_i     (dcache_req_ports_i),
      .req_ports_o     (dcache_req_ports_o),
      .wbuffer_empty_o (wbuffer_empty_o),
      .wbuffer_not_ni_o(wbuffer_not_ni_o),
      .mem_rtrn_vld_i  (adapter_dcache_rtrn_vld),
      .mem_rtrn_i      (adapter_dcache),
      .mem_data_req_o  (dcache_adapter_data_req),
      .mem_data_ack_i  (adapter_dcache_data_ack),
      .mem_data_o      (dcache_adapter)
  );

  wt_axi_adapter #(
      .CVA6Cfg(CVA6Cfg),
      .axi_req_t(noc_req_t),
      .axi_rsp_t(noc_resp_t),
      .dcache_req_t(dcache_req_t),
      .dcache_rtrn_t(dcache_rtrn_t),
      .dcache_inval_t(dcache_inval_t),
      .icache_req_t(icache_req_t),
      .icache_rtrn_t(icache_rtrn_t)
  ) i_adapter (
      .clk_i            (clk_i),
      .rst_ni           (rst_ni),
      .icache_data_req_i(icache_miss_valid_i),
      .icache_data_ack_o(icache_miss_ready_o),
      .icache_data_i    (icache_miss_i),
      .icache_rtrn_vld_o(icache_miss_resp_valid_o),
      .icache_rtrn_o    (icache_miss_resp_o),
      .dcache_data_req_i(dcache_adapter_data_req),
      .dcache_data_ack_o(adapter_dcache_data_ack),
      .dcache_data_i    (dcache_adapter),
      .dcache_rtrn_vld_o(adapter_dcache_rtrn_vld),
      .dcache_rtrn_o    (adapter_dcache),
      .axi_req_o        (noc_req_o),
      .axi_resp_i       (noc_resp_i),
      .inval_addr_i     (inval_addr_i),
      .inval_valid_i    (inval_valid_i),
      .inval_ready_o    (inval_ready_o)
  );

endmodule
