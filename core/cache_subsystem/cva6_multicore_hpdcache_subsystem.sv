`include "hpdcache_typedef.svh"

module cva6_multicore_hpdcache_subsystem
//  Parameters
//  {{{
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type icache_req_t = logic,
    parameter type icache_rtrn_t = logic,
    parameter type dcache_req_i_t = logic,
    parameter type dcache_req_o_t = logic,
    parameter unsigned NrHarts = 1,
    parameter unsigned NumPorts = 4,
    parameter unsigned NrHwPrefetchers = 4,
    parameter unsigned ICacheRdtxid = 1 << (CVA6Cfg.MEM_TID_WIDTH - 1),
    // AXI types
    parameter type axi_ar_chan_t = logic,
    parameter type axi_aw_chan_t = logic,
    parameter type axi_w_chan_t = logic,
    parameter type axi_b_chan_t = logic,
    parameter type axi_r_chan_t = logic,
    parameter type noc_req_t = logic,
    parameter type noc_resp_t = logic,
    parameter type cmo_req_t = logic,
    parameter type cmo_rsp_t = logic
)
//  }}}

//  Ports
//  {{{
(
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,

    //  AXI port to upstream memory/peripherals
    //  {{{
    // noc request, can be AXI or OpenPiton - SUBSYSTEM
    output noc_req_t  noc_req_o,
    // noc response, can be AXI or OpenPiton - SUBSYSTEM
    input  noc_resp_t noc_resp_i,
    //  }}}

    //  I$
    //  {{{
    input logic [NrHarts-1:0] icache_miss_valid_i,
    output logic [NrHarts-1:0] icache_miss_ready_o,
    input icache_req_t [NrHarts-1:0] icache_miss_i,

    output logic [NrHarts-1:0] icache_miss_resp_valid_o,
    output icache_rtrn_t [NrHarts-1:0] icache_miss_resp_o,
    //   }}}

    //  D$
    //  {{{
    //    Cache management
    // Data cache enable - CSR_REGFILE
    input  logic [NrHarts-1:0] dcache_enable_i,
    // Data cache flush - CONTROLLER
    input  logic [NrHarts-1:0] dcache_flush_i,
    // Flush acknowledge - CONTROLLER
    output logic [NrHarts-1:0] dcache_flush_ack_o,
    // Load or store miss - PERF_COUNTERS
    output logic [NrHarts-1:0] dcache_miss_o,

    // AMO request - EX_STAGE
    input  ariane_pkg::amo_req_t  [NrHarts-1:0]               dcache_amo_req_i,
    // AMO response - EX_STAGE
    output ariane_pkg::amo_resp_t [NrHarts-1:0]               dcache_amo_resp_o,
    // Data cache input request ports - EX_STAGE
    input  dcache_req_i_t         [NrHarts-1:0][NumPorts-1:0] dcache_req_ports_i,
    // Data cache output request ports - EX_STAGE
    output dcache_req_o_t         [NrHarts-1:0][NumPorts-1:0] dcache_req_ports_o,
    // Write buffer status to know if empty - EX_STAGE
    output logic                  [NrHarts-1:0]               wbuffer_empty_o,
    // Write buffer status to know if not non idempotent - EX_STAGE
    output logic                  [NrHarts-1:0]               wbuffer_not_ni_o
);
  function int unsigned __minu(input int unsigned x, input int unsigned y);
    return x < y ? x : y;
  endfunction

  function int unsigned __maxu(input int unsigned x, input int unsigned y);
    return y < x ? x : y;
  endfunction

  //  D$ instantiation
  //  {{{

  //    0: Page-Table Walk (PTW)
  //    1: Load unit
  //    2: Accelerator load
  //    3: Store/AMO
  //    .
  //    .
  //    .
  //    NumPorts: CMO
  //    NumPorts + 1: Hardware Memory Prefetcher (hwpf)
  localparam int HPDCACHE_NREQUESTERS = NumPorts + 2;

  function automatic hpdcache_pkg::hpdcache_user_cfg_t hpdcacheSetConfig();
    hpdcache_pkg::hpdcache_user_cfg_t userCfg;
    userCfg.nRequesters = HPDCACHE_NREQUESTERS;
    userCfg.paWidth = CVA6Cfg.PLEN;
    userCfg.wordWidth = CVA6Cfg.XLEN;
    userCfg.sets = CVA6Cfg.DCACHE_NUM_WORDS;
    userCfg.ways = CVA6Cfg.DCACHE_SET_ASSOC;
    userCfg.clWords = CVA6Cfg.DCACHE_LINE_WIDTH / CVA6Cfg.XLEN;
    userCfg.reqWords = 1;
    userCfg.reqTransIdWidth = CVA6Cfg.DcacheIdWidth;
    userCfg.reqSrcIdWidth = 3;  // Up to 8 requesters
    userCfg.victimSel = hpdcache_pkg::HPDCACHE_VICTIM_RANDOM;
    userCfg.dataWaysPerRamWord = __minu(CVA6Cfg.DCACHE_SET_ASSOC, 128 / CVA6Cfg.XLEN);
    userCfg.dataSetsPerRam = CVA6Cfg.DCACHE_NUM_WORDS;
    userCfg.dataRamByteEnable = 1'b1;
    userCfg.accessWords = __maxu(CVA6Cfg.AxiDataWidth / CVA6Cfg.XLEN, userCfg.reqWords);
    userCfg.mshrSets = CVA6Cfg.NrLoadBufEntries < 16 ? 1 : CVA6Cfg.NrLoadBufEntries / 2;
    userCfg.mshrWays = CVA6Cfg.NrLoadBufEntries < 16 ? CVA6Cfg.NrLoadBufEntries : 2;
    userCfg.mshrWaysPerRamWord = CVA6Cfg.NrLoadBufEntries < 16 ? CVA6Cfg.NrLoadBufEntries : 2;
    userCfg.mshrSetsPerRam = CVA6Cfg.NrLoadBufEntries < 16 ? 1 : CVA6Cfg.NrLoadBufEntries / 2;
    userCfg.mshrRamByteEnable = 1'b1;
    userCfg.mshrUseRegbank = (CVA6Cfg.NrLoadBufEntries < 16);
    userCfg.refillCoreRspFeedthrough = 1'b1;
    userCfg.refillFifoDepth = 2 * (CVA6Cfg.DCACHE_LINE_WIDTH / CVA6Cfg.AxiDataWidth);
    userCfg.wbufDirEntries = CVA6Cfg.WtDcacheWbufDepth;
    userCfg.wbufDataEntries = CVA6Cfg.WtDcacheWbufDepth;
    userCfg.wbufWords = 1;
    userCfg.wbufTimecntWidth = 3;
    userCfg.rtabEntries = 4;
    /*FIXME we should add additional CVA6 config parameters (flushEntries)*/
    userCfg.flushEntries = CVA6Cfg.WtDcacheWbufDepth;
    /*FIXME we should add additional CVA6 config parameters (flushFifoDepth)*/
    userCfg.flushFifoDepth = CVA6Cfg.WtDcacheWbufDepth;
    userCfg.memAddrWidth = CVA6Cfg.AxiAddrWidth;
    userCfg.memIdWidth = CVA6Cfg.MEM_TID_WIDTH;
    userCfg.memDataWidth = CVA6Cfg.AxiDataWidth;
    userCfg.wtEn =
        (CVA6Cfg.DCacheType == config_pkg::HPDCACHE_WT) ||
        (CVA6Cfg.DCacheType == config_pkg::HPDCACHE_WT_WB);
    userCfg.wbEn =
        (CVA6Cfg.DCacheType == config_pkg::HPDCACHE_WB) ||
        (CVA6Cfg.DCacheType == config_pkg::HPDCACHE_WT_WB);
    return userCfg;
  endfunction

  localparam hpdcache_pkg::hpdcache_user_cfg_t HPDCACHE_USER_CFG = hpdcacheSetConfig();
  localparam hpdcache_pkg::hpdcache_cfg_t HPDCACHE_CFG = hpdcache_pkg::hpdcacheBuildConfig(
      HPDCACHE_USER_CFG
  );

  `HPDCACHE_TYPEDEF_MEM_ATTR_T(hpdcache_mem_addr_t, hpdcache_mem_id_t, hpdcache_mem_data_t,
                               hpdcache_mem_be_t, HPDCACHE_CFG);
  `HPDCACHE_TYPEDEF_MEM_REQ_T(hpdcache_mem_req_t, hpdcache_mem_addr_t, hpdcache_mem_id_t);
  `HPDCACHE_TYPEDEF_MEM_RESP_R_T(hpdcache_mem_resp_r_t, hpdcache_mem_id_t, hpdcache_mem_data_t);
  `HPDCACHE_TYPEDEF_MEM_REQ_W_T(hpdcache_mem_req_w_t, hpdcache_mem_data_t, hpdcache_mem_be_t);
  `HPDCACHE_TYPEDEF_MEM_RESP_W_T(hpdcache_mem_resp_w_t, hpdcache_mem_id_t);

  `HPDCACHE_TYPEDEF_REQ_ATTR_T(hpdcache_req_offset_t, hpdcache_data_word_t, hpdcache_data_be_t,
                               hpdcache_req_data_t, hpdcache_req_be_t, hpdcache_req_sid_t,
                               hpdcache_req_tid_t, hpdcache_tag_t, HPDCACHE_CFG);
  `HPDCACHE_TYPEDEF_REQ_T(hpdcache_req_t, hpdcache_req_offset_t, hpdcache_req_data_t,
                          hpdcache_req_be_t, hpdcache_req_sid_t, hpdcache_req_tid_t,
                          hpdcache_tag_t);
  `HPDCACHE_TYPEDEF_RSP_T(hpdcache_rsp_t, hpdcache_req_data_t, hpdcache_req_sid_t,
                          hpdcache_req_tid_t);

  logic                                         icache_miss_valid;
  logic                                         icache_miss_ready;
  icache_req_t                                  icache_miss;

  logic                                         icache_miss_resp_valid;
  icache_rtrn_t                                 icache_miss_resp;


  logic                                         dcache_enable;
  logic                                         dcache_flush;
  logic                                         dcache_flush_ack;
  logic                                         dcache_miss;

  ariane_pkg::amo_req_t                         dcache_amo_req;
  ariane_pkg::amo_resp_t                        dcache_amo_resp;
  dcache_req_i_t         [NumPorts*NrHarts-1:0] dcache_req_ports_to_cache;
  dcache_req_o_t         [NumPorts*NrHarts-1:0] dcache_req_ports_from_cache;
  logic                                         wbuffer_empty;
  logic                                         wbuffer_not_ni;

  cva6_multicore_cache_arbitrer #(
      .CVA6Cfg(CVA6Cfg),
      .icache_req_t(icache_req_t),
      .icache_rtrn_t(icache_rtrn_t),
      .dcache_req_i_t(dcache_req_i_t),
      .dcache_req_o_t(dcache_req_o_t),
      .NrHarts(NrHarts),
      .NumPorts(NumPorts)
  ) i_cva6_multicore_cache_arbitrer (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .cores_icache_miss_valid_i(icache_miss_valid_i),
      .cores_icache_miss_ready_o(icache_miss_ready_o),
      .cores_icache_miss_i(icache_miss_i),
      .cores_icache_miss_resp_valid_o(icache_miss_resp_valid_o),
      .cores_icache_miss_resp_o(icache_miss_resp_o),
      .cores_dcache_enable_i(dcache_enable_i),
      .cores_dcache_flush_i(dcache_flush_i),
      .cores_dcache_flush_ack_o(dcache_flush_ack_o),
      .cores_dcache_miss_o(dcache_miss_o),
      .cores_dcache_amo_req_i(dcache_amo_req_i),
      .cores_dcache_amo_resp_o(dcache_amo_resp_o),
      .cores_dcache_req_ports_i(dcache_req_ports_i),
      .cores_dcache_req_ports_o(dcache_req_ports_o),
      .cores_wbuffer_empty_o(wbuffer_empty_o),
      .cores_wbuffer_not_ni_o(wbuffer_not_ni_o),

      .cache_icache_miss_valid_o(icache_miss_valid),
      .cache_icache_miss_ready_i(icache_miss_ready),
      .cache_icache_miss_o(icache_miss),
      .cache_icache_miss_resp_valid_i(icache_miss_resp_valid),
      .cache_icache_miss_resp_i(icache_miss_resp),
      .cache_dcache_enable_o(dcache_enable),
      .cache_dcache_flush_o(dcache_flush),
      .cache_dcache_flush_ack_i(dcache_flush_ack),
      .cache_dcache_miss_i(dcache_miss),
      .cache_dcache_amo_req_o(dcache_amo_req),
      .cache_dcache_amo_resp_i(dcache_amo_resp),
      .cache_dcache_req_ports_o(dcache_req_ports_to_cache),
      .cache_dcache_req_ports_i(dcache_req_ports_from_cache),
      .cache_wbuffer_empty_i(wbuffer_empty),
      .cache_wbuffer_not_ni_i(wbuffer_not_ni)
  );



  typedef logic [HPDCACHE_CFG.u.wbufTimecntWidth-1:0] hpdcache_wbuf_timecnt_t;

  logic                 dcache_read_ready;
  logic                 dcache_read_valid;
  hpdcache_mem_req_t    dcache_read;

  logic                 dcache_read_resp_ready;
  logic                 dcache_read_resp_valid;
  hpdcache_mem_resp_r_t dcache_read_resp;

  logic                 dcache_write_ready;
  logic                 dcache_write_valid;
  hpdcache_mem_req_t    dcache_write;

  logic                 dcache_write_data_ready;
  logic                 dcache_write_data_valid;
  hpdcache_mem_req_w_t  dcache_write_data;

  logic                 dcache_write_resp_ready;
  logic                 dcache_write_resp_valid;
  hpdcache_mem_resp_w_t dcache_write_resp;

  cva6_hpdcache_wrapper #(
      .CVA6Cfg(CVA6Cfg),
      .HPDcacheCfg(HPDCACHE_CFG),
      .dcache_req_i_t(dcache_req_i_t),
      .dcache_req_o_t(dcache_req_o_t),
      .NumPorts(NumPorts * NrHarts),
      .NrHwPrefetchers(NrHwPrefetchers),
      .cmo_req_t(cmo_req_t),
      .cmo_rsp_t(cmo_rsp_t),
      .hpdcache_mem_addr_t(hpdcache_mem_addr_t),
      .hpdcache_mem_id_t(hpdcache_mem_id_t),
      .hpdcache_mem_data_t(hpdcache_mem_data_t),
      .hpdcache_mem_be_t(hpdcache_mem_be_t),
      .hpdcache_mem_req_t(hpdcache_mem_req_t),
      .hpdcache_mem_req_w_t(hpdcache_mem_req_w_t),
      .hpdcache_mem_resp_r_t(hpdcache_mem_resp_r_t),
      .hpdcache_mem_resp_w_t(hpdcache_mem_resp_w_t),
      .hpdcache_req_offset_t(hpdcache_req_offset_t),
      .hpdcache_data_word_t(hpdcache_data_word_t),
      .hpdcache_req_data_t(hpdcache_req_data_t),
      .hpdcache_req_be_t(hpdcache_req_be_t),
      .hpdcache_req_sid_t(hpdcache_req_sid_t),
      .hpdcache_req_tid_t(hpdcache_req_tid_t),
      .hpdcache_tag_t(hpdcache_tag_t),
      .hpdcache_req_t(hpdcache_req_t),
      .hpdcache_rsp_t(hpdcache_rsp_t),
      .hpdcache_wbuf_timecnt_t(hpdcache_wbuf_timecnt_t),
      .hpdcache_data_be_t(hpdcache_data_be_t)
  ) i_dcache (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .dcache_enable_i(dcache_enable),
      .dcache_flush_i(dcache_flush),
      .dcache_flush_ack_o(dcache_flush_ack),
      .dcache_miss_o(dcache_miss),
      .dcache_amo_req_i(dcache_amo_req),
      .dcache_amo_resp_o(dcache_amo_resp),
      .dcache_cmo_req_i('0  /*FIXME*/),
      .dcache_cmo_resp_o(  /*FIXME*/),
      .dcache_req_ports_i(dcache_req_ports_to_cache),
      .dcache_req_ports_o(dcache_req_ports_from_cache),

      .wbuffer_empty_o (wbuffer_empty),
      .wbuffer_not_ni_o(wbuffer_not_ni),

      .hwpf_base_set_i('0  /*FIXME*/),
      .hwpf_base_i('0  /*FIXME*/),
      .hwpf_base_o(  /*FIXME*/),
      .hwpf_param_set_i('0  /*FIXME*/),
      .hwpf_param_i('0  /*FIXME*/),
      .hwpf_param_o(  /*FIXME*/),
      .hwpf_throttle_set_i('0  /*FIXME*/),
      .hwpf_throttle_i('0  /*FIXME*/),
      .hwpf_throttle_o(  /*FIXME*/),
      .hwpf_status_o(  /*FIXME*/),

      .dcache_mem_req_read_ready_i(dcache_read_ready),
      .dcache_mem_req_read_valid_o(dcache_read_valid),
      .dcache_mem_req_read_o(dcache_read),

      .dcache_mem_resp_read_ready_o(dcache_read_resp_ready),
      .dcache_mem_resp_read_valid_i(dcache_read_resp_valid),
      .dcache_mem_resp_read_i(dcache_read_resp),

      .dcache_mem_req_write_ready_i(dcache_write_ready),
      .dcache_mem_req_write_valid_o(dcache_write_valid),
      .dcache_mem_req_write_o(dcache_write),

      .dcache_mem_req_write_data_ready_i(dcache_write_data_ready),
      .dcache_mem_req_write_data_valid_o(dcache_write_data_valid),
      .dcache_mem_req_write_data_o(dcache_write_data),

      .dcache_mem_resp_write_ready_o(dcache_write_resp_ready),
      .dcache_mem_resp_write_valid_i(dcache_write_resp_valid),
      .dcache_mem_resp_write_i(dcache_write_resp)
  );

  //  AXI arbiter instantiation
  //  {{{
  cva6_hpdcache_subsystem_axi_arbiter #(
      .CVA6Cfg              (CVA6Cfg),
      .hpdcache_mem_id_t    (hpdcache_mem_id_t),
      .hpdcache_mem_req_t   (hpdcache_mem_req_t),
      .hpdcache_mem_req_w_t (hpdcache_mem_req_w_t),
      .hpdcache_mem_resp_r_t(hpdcache_mem_resp_r_t),
      .hpdcache_mem_resp_w_t(hpdcache_mem_resp_w_t),
      .icache_req_t         (icache_req_t),
      .icache_rtrn_t        (icache_rtrn_t),

      .AxiAddrWidth (CVA6Cfg.AxiAddrWidth),
      .AxiDataWidth (CVA6Cfg.AxiDataWidth),
      .AxiIdWidth   (CVA6Cfg.AxiIdWidth),
      .AxiUserWidth (CVA6Cfg.AxiUserWidth),
      .axi_ar_chan_t(axi_ar_chan_t),
      .axi_aw_chan_t(axi_aw_chan_t),
      .axi_w_chan_t (axi_w_chan_t),
      .axi_b_chan_t (axi_b_chan_t),
      .axi_r_chan_t (axi_r_chan_t),
      .axi_req_t    (noc_req_t),
      .axi_rsp_t    (noc_resp_t)
  ) i_axi_arbiter (
      .clk_i,
      .rst_ni,

      .icache_miss_valid_i(icache_miss_valid),
      .icache_miss_ready_o(icache_miss_ready),
      .icache_miss_i      (icache_miss),
      .icache_miss_id_i   (hpdcache_mem_id_t'(ICacheRdtxid)),

      .icache_miss_resp_valid_o(icache_miss_resp_valid),
      .icache_miss_resp_o      (icache_miss_resp),

      .dcache_read_ready_o(dcache_read_ready),
      .dcache_read_valid_i(dcache_read_valid),
      .dcache_read_i      (dcache_read),

      .dcache_read_resp_ready_i(dcache_read_resp_ready),
      .dcache_read_resp_valid_o(dcache_read_resp_valid),
      .dcache_read_resp_o      (dcache_read_resp),

      .dcache_write_ready_o(dcache_write_ready),
      .dcache_write_valid_i(dcache_write_valid),
      .dcache_write_i      (dcache_write),

      .dcache_write_data_ready_o(dcache_write_data_ready),
      .dcache_write_data_valid_i(dcache_write_data_valid),
      .dcache_write_data_i      (dcache_write_data),

      .dcache_write_resp_ready_i(dcache_write_resp_ready),
      .dcache_write_resp_valid_o(dcache_write_resp_valid),
      .dcache_write_resp_o      (dcache_write_resp),

      .axi_req_o (noc_req_o),
      .axi_resp_i(noc_resp_i)
  );
  //  }}}

  //  Assertions
  //  {{{
  //  pragma translate_off
  initial begin : initial_assertions
    assert (HPDCACHE_CFG.u.reqSrcIdWidth >= $clog2(HPDCACHE_CFG.u.nRequesters))
    else $fatal(1, "HPDCACHE_REQ_SRC_ID_WIDTH is not wide enough");
    assert (CVA6Cfg.MEM_TID_WIDTH <= CVA6Cfg.AxiIdWidth)
    else $fatal(1, "MEM_TID_WIDTH shall be less or equal to the AxiIdWidth");
    assert (CVA6Cfg.MEM_TID_WIDTH >= ($clog2(
        HPDCACHE_CFG.u.mshrSets * HPDCACHE_CFG.u.mshrWays
    ) + 1))
    else $fatal(1, "MEM_TID_WIDTH shall allow to uniquely identify all D$ and I$ miss requests ");
    assert (CVA6Cfg.MEM_TID_WIDTH >= ($clog2(HPDCACHE_CFG.u.wbufDirEntries) + 1))
    else $fatal(1, "MEM_TID_WIDTH shall allow to uniquely identify all D$ write requests ");
  end
  //  pragma translate_on
  //  }}}

endmodule
