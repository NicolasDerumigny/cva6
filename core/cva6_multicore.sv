`include "rvfi_types.svh"
`include "cvxif_types.svh"
`include "ypb_types.svh"

module cva6_multicore
  import ariane_pkg::*;
#(
    // CVA6 config
    parameter config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(
        cva6_config_pkg::cva6_cfg
    ),

    // RVFI PROBES
    parameter type rvfi_probes_instr_t = `RVFI_PROBES_INSTR_T(CVA6Cfg),
    parameter type rvfi_probes_csr_t = `RVFI_PROBES_CSR_T(CVA6Cfg),
    parameter type rvfi_probes_t = struct packed {
      rvfi_probes_csr_t   csr;
      rvfi_probes_instr_t instr;
    },

    // Exceptions
    parameter type exception_t = struct packed {
      logic [CVA6Cfg.XLEN-1:0] cause;  // cause of exception
      logic [CVA6Cfg.XLEN-1:0] tval;  // additional information of causing exception
      // (e.g.: instruction causing it), address of LD/ST fault
      logic [CVA6Cfg.GPLEN-1:0] tval2;  // additional information when the causing
      // exception in a guest exception
      logic [31:0] tinst;  // transformed instruction information
      logic gva;  // signals when a guest virtual address is written to tval
      logic valid;
      //timing of exception, timing = 0 : break immediately or timing = 1 break immediatemy AFTER (let current instruction commit but only this one)
      logic timing;
    },

    // CVXIF Types
    parameter type readregflags_t = `READREGFLAGS_T(CVA6Cfg),
    parameter type writeregflags_t = `WRITEREGFLAGS_T(CVA6Cfg),
    parameter type id_t = `ID_T(CVA6Cfg),
    parameter type hartid_t = `HARTID_T(CVA6Cfg),
    parameter type x_compressed_req_t = `X_COMPRESSED_REQ_T(CVA6Cfg, hartid_t),
    parameter type x_compressed_resp_t = `X_COMPRESSED_RESP_T(CVA6Cfg),
    parameter type x_issue_req_t = `X_ISSUE_REQ_T(CVA6Cfg, hartid_t, id_t),
    parameter type x_issue_resp_t = `X_ISSUE_RESP_T(CVA6Cfg, writeregflags_t, readregflags_t),
    parameter type x_register_t = `X_REGISTER_T(CVA6Cfg, hartid_t, id_t, readregflags_t),
    parameter type x_commit_t = `X_COMMIT_T(CVA6Cfg, hartid_t, id_t),
    parameter type x_result_t = `X_RESULT_T(CVA6Cfg, hartid_t, id_t, writeregflags_t),
    parameter type cvxif_req_t =
    `CVXIF_REQ_T(CVA6Cfg, x_compressed_req_t, x_issue_req_t, x_register_t, x_commit_t),
    parameter type cvxif_resp_t =
    `CVXIF_RESP_T(CVA6Cfg, x_compressed_resp_t, x_issue_resp_t, x_result_t),

    // AXI Types
    parameter int unsigned AxiAddrWidth = CVA6Cfg.AxiAddrWidth,
    parameter int unsigned AxiDataWidth = CVA6Cfg.AxiDataWidth,
    parameter int unsigned AxiIdWidth = CVA6Cfg.AxiIdWidth,
    parameter int unsigned NrHarts = 1,

    // ----- Cache types -----
    // cache request ports
    // I$ address translation requests
    localparam type icache_areq_t = struct packed {
      logic                    fetch_valid;      // address translation valid
      logic [CVA6Cfg.PLEN-1:0] fetch_paddr;      // physical address in
      exception_t              fetch_exception;  // exception occurred during fetch
    },
    localparam type icache_arsp_t = struct packed {
      logic                    fetch_req;    // address translation request
      logic [CVA6Cfg.VLEN-1:0] fetch_vaddr;  // virtual address out
    },

    // I$ data requests
    localparam type icache_dreq_t = struct packed {
      logic                    req;      // we request a new word
      logic                    kill_s1;  // kill the current request
      logic                    kill_s2;  // kill the last request
      logic                    spec;     // request is speculative
      logic [CVA6Cfg.VLEN-1:0] vaddr;    // 1st cycle: 12 bit index is taken for lookup
    },
    localparam type icache_drsp_t = struct packed {
      logic                                ready;  // icache is ready
      logic                                valid;  // signals a valid read
      logic [CVA6Cfg.FETCH_WIDTH-1:0]      data;   // 2+ cycle out: tag
      logic [CVA6Cfg.FETCH_USER_WIDTH-1:0] user;   // User bits
      logic [CVA6Cfg.VLEN-1:0]             vaddr;  // virtual address out
      exception_t                          ex;     // we've encountered an exception
    },

    // Fetch requests/responses of the hpicache L1 instruction cache (YPB)
    localparam type ypb_fetch_req_t = `YPB_REQ_T(CVA6Cfg, CVA6Cfg.FETCH_WIDTH),
    localparam type ypb_fetch_rsp_t = `YPB_RSP_T(CVA6Cfg, CVA6Cfg.FETCH_WIDTH),

    //  AXI identifiers of the memory interfaces
    //  {{{
    //  The NoC multiplexer prepends $clog2(NOC_MUX_PORTS) bits to the identifiers
    //  to route the responses back to the shared L1d cache or to one of the
    //  private hpicache L1i caches.  Those bits are not available to the caches:
    //  the identifiers they put on their memory interface must fit in the
    //  remaining ones, or the prepending cuts the most significant bits off.  It
    //  matters for HPDcache in particular: it recognizes the responses of its
    //  uncacheable (device) accesses by an identifier of all ones.  Truncated,
    //  such a response is taken for one of the write buffer and is lost, which
    //  blocks the uncacheable handler and, through it, the whole data cache.
    localparam int unsigned NOC_MUX_PORTS = NrHarts + 1,
    localparam int unsigned NOC_MUX_SLV_ID_WIDTH = CVA6Cfg.AxiIdWidth
        - $clog2(NOC_MUX_PORTS),
    //  The two kinds of port do not need the same number of them.  The arbiter of
    //  an instruction cache port tells the requests of its cache from the ones it
    //  issues itself with the most significant identifier of the port, which
    //  leaves one less to that cache; the arbiter of the shared data cache puts
    //  the reads and the writes on separate channels and needs none of it.
    localparam int unsigned ICACHE_MEM_ID_WIDTH = NOC_MUX_SLV_ID_WIDTH - 1,
    localparam int unsigned DCACHE_MEM_ID_WIDTH = NOC_MUX_SLV_ID_WIDTH,
    //  }}}

    //  Width of the thread id of the cache request structs.  The localparam of
    //  the OpenPiton interface which used to carry it is compiled out of the
    //  package outside of the OpenPiton build, and the configuration scheme of
    //  the rebase has no field for it: the multicore SoC defines it.  It is the
    //  identifier a cache puts on its memory interface, and the response table of
    //  an arbiter has one slot per value of it, so the shared data cache, which
    //  has the widest identifiers, is what sets it.  HPDcache checks on its own
    //  that they are enough for its refill, write buffer and device accesses.
    localparam int unsigned MemTidWidth = DCACHE_MEM_ID_WIDTH,

    // I$ requests
    localparam type icache_req_t = struct packed {
      logic [CVA6Cfg.ICACHE_SET_ASSOC_WIDTH-1:0] way;  // way to replace
      logic [CVA6Cfg.PLEN-1:0] paddr;  // physical address
      logic nc;  // noncacheable
      logic [MemTidWidth-1:0] tid;  // thread id (used as transaction id in Ariane)
    },
    localparam type icache_rtrn_t = struct packed {
      wt_cache_pkg::icache_in_t rtype;  // see definitions above
      logic [CVA6Cfg.ICACHE_LINE_WIDTH-1:0] data;  // full cache line width
      logic [CVA6Cfg.ICACHE_USER_LINE_WIDTH-1:0] user;  // user bits
      struct packed {
        logic                                      vld;  // invalidate only affected way
        logic                                      all;  // invalidate all ways
        logic [CVA6Cfg.ICACHE_INDEX_WIDTH-1:0]     idx;  // physical address to invalidate
        logic [CVA6Cfg.ICACHE_SET_ASSOC_WIDTH-1:0] way;  // way to invalidate
      } inv;  // invalidation vector
      logic [MemTidWidth-1:0] tid;  // thread id (used as transaction id in Ariane)
    },

    localparam type cbo_t = logic [7:0],

    // D$ data requests
    localparam type dcache_req_i_t = struct packed {
      logic [CVA6Cfg.DCACHE_INDEX_WIDTH-1:0] address_index;
      logic [CVA6Cfg.DCACHE_TAG_WIDTH-1:0]   address_tag;
      logic [CVA6Cfg.XLEN-1:0]               data_wdata;
      logic [CVA6Cfg.DCACHE_USER_WIDTH-1:0]  data_wuser;
      logic                                  data_req;
      logic                                  data_we;
      logic [(CVA6Cfg.XLEN/8)-1:0]           data_be;
      logic [1:0]                            data_size;
      logic [CVA6Cfg.DcacheIdWidth-1:0]      data_id;
      logic                                  kill_req;
      logic                                  tag_valid;
      cbo_t                                  cbo_op;
    },
    localparam type dcache_req_o_t = struct packed {
      logic                                 data_gnt;
      logic                                 data_rvalid;
      logic [CVA6Cfg.DcacheIdWidth-1:0]     data_rid;
      logic [CVA6Cfg.XLEN-1:0]              data_rdata;
      logic [CVA6Cfg.DCACHE_USER_WIDTH-1:0] data_ruser;
      logic                                 data_error;
    },

    // AXI types
    parameter type axi_ar_chan_t = struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      logic [CVA6Cfg.AxiAddrWidth-1:0] addr;
      axi_pkg::len_t                   len;
      axi_pkg::size_t                  size;
      axi_pkg::burst_t                 burst;
      logic                            lock;
      axi_pkg::cache_t                 cache;
      axi_pkg::prot_t                  prot;
      axi_pkg::qos_t                   qos;
      axi_pkg::region_t                region;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    },
    parameter type axi_aw_chan_t = struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      logic [CVA6Cfg.AxiAddrWidth-1:0] addr;
      axi_pkg::len_t                   len;
      axi_pkg::size_t                  size;
      axi_pkg::burst_t                 burst;
      logic                            lock;
      axi_pkg::cache_t                 cache;
      axi_pkg::prot_t                  prot;
      axi_pkg::qos_t                   qos;
      axi_pkg::region_t                region;
      axi_pkg::atop_t                  atop;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    },
    parameter type axi_w_chan_t = struct packed {
      logic [CVA6Cfg.AxiDataWidth-1:0]     data;
      logic [(CVA6Cfg.AxiDataWidth/8)-1:0] strb;
      logic                                last;
      logic [CVA6Cfg.AxiUserWidth-1:0]     user;
    },
    parameter type b_chan_t = struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      axi_pkg::resp_t                  resp;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    },
    parameter type r_chan_t = struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      logic [CVA6Cfg.AxiDataWidth-1:0] data;
      axi_pkg::resp_t                  resp;
      logic                            last;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    },
    parameter type noc_req_t = struct packed {
      axi_aw_chan_t aw;
      logic         aw_valid;
      axi_w_chan_t  w;
      logic         w_valid;
      logic         b_ready;
      axi_ar_chan_t ar;
      logic         ar_valid;
      logic         r_ready;
    },
    parameter type noc_resp_t = struct packed {
      logic    aw_ready;
      logic    ar_ready;
      logic    w_ready;
      logic    b_valid;
      b_chan_t b;
      logic    r_valid;
      r_chan_t r;
    }
) (
    input logic                    clk_i,
    input logic                    rst_ni,
    // Core ID, Cluster ID and boot address are considered more or less static
    input logic [CVA6Cfg.VLEN-1:0] boot_addr_i, // reset boot address

    // Interrupt inputs
    input logic [NrHarts-1:0][1:0] irq_i,  // level sensitive IR lines, mip & sip (async)
    input logic [NrHarts-1:0] ipi_i,  // inter-processor interrupts (async)
    // Timer facilities
    input logic [NrHarts-1:0] time_irq_i,  // timer interrupt in (async)
    input logic [NrHarts-1:0] debug_req_i,  // debug request (async)
    // Probes to build RVFI, can be left open when not used - RVFI
    output rvfi_probes_t rvfi_probes_o[NrHarts],
    // CVXIF request - SUBSYSTEM
    output cvxif_req_t cvxif_req_o[NrHarts],
    // CVXIF response - SUBSYSTEM
    input cvxif_resp_t cvxif_resp_i[NrHarts],
    // memory side
    output noc_req_t noc_req_o,
    input noc_resp_t noc_resp_i,
    // User bits of the write data issued by the data caches - SUBSYSTEM
    output logic [CVA6Cfg.AxiUserWidth-1:0] dcache_user_o
);
  localparam unsigned NUM_CACHE_PORTS = 4;
  localparam unsigned NUM_HW_PREFETCHERS = 4;

  //  AXI identifiers of the memory interfaces
  //  {{{
  //  The widths themselves are in the parameter list, where the thread id of the
  //  cache request structs is defined with them.
  //
  //  The identifiers of the shared data cache are shared between its D$ refills,
  //  which take [0, mshrSets*mshrWays-1] and the uncacheable requests of HPDcache,
  //  which take the identifier of all ones.  The private instruction caches, on
  //  their own port, number their misses from ICACHE_RDTXID.
  localparam unsigned ICACHE_RDTXID = (1 << ICACHE_MEM_ID_WIDTH) - NrHarts - 1;

  //  The view of the configuration the AXI arbiters of the instruction cache
  //  ports are built with.  Their AXI port carries the identifiers of their own
  //  port only, so for them the identifier of all ones, which is the one that
  //  tells a request of the cache from one of the arbiter, is the bit just below
  //  the ones the multiplexer prepends.  Built with the width of the whole cluster
  //  instead, that bit lands below the ones the multiplexer overwrites: the
  //  responses of the caches of a port whose index has it clear are then handed to
  //  the read output of the arbiter, which nothing listens to, and the cache waits
  //  for a refill which never comes.
  function automatic config_pkg::cva6_cfg_t memSetConfig();
    config_pkg::cva6_cfg_t cfg = CVA6Cfg;
    cfg.AxiIdWidth = NOC_MUX_SLV_ID_WIDTH;
    return cfg;
  endfunction
  localparam config_pkg::cva6_cfg_t MemCfg = memSetConfig();
  //  }}}


  // The shared cache does not drive the AXI user bits of its write data
  assign dcache_user_o = '0;

  logic [NrHarts-1:0] dcache_en_csr;
  logic [NrHarts-1:0] dcache_flush_ctrl_cache;
  logic [NrHarts-1:0] dcache_flush_ack_cache_ctrl;
  // D$ scrubber control / ECC error feedback (shared D$, see cva6_multicore_hpdcache_subsystem)
  logic [NrHarts-1:0] dcache_scrub_en;
  logic [NrHarts-1:0][5:0] dcache_scrub_period;
  logic [NrHarts-1:0] dcache_scrub_cycle;
  logic [NrHarts-1:0] dcache_dat_cor_err;
  logic [NrHarts-1:0] dcache_dat_unc_err;
  logic [NrHarts-1:0] dcache_dir_cor_err;
  logic [NrHarts-1:0] dcache_dir_unc_err;
  dcache_req_o_t [NrHarts-1:0][NUM_CACHE_PORTS-1:0] dcache_req_from_cache;
  dcache_req_i_t [NrHarts-1:0][NUM_CACHE_PORTS-1:0] dcache_req_to_cache;
  logic [NrHarts-1:0] dcache_commit_wbuffer_empty;
  logic [NrHarts-1:0] dcache_commit_wbuffer_not_ni;

  //  hpicache L1 instruction cache configuration
  //  {{{
  //  The AXI identifiers of the private instruction caches are narrowed by the
  //  number of bits the NoC multiplexer prepends (see NOC_MUX_SLV_ID_WIDTH).

  `include "hpdcache_typedef.svh"

  function int unsigned __minu(int unsigned x, int unsigned y);
    return x < y ? x : y;
  endfunction

  function int unsigned __maxu(int unsigned x, int unsigned y);
    return y < x ? x : y;
  endfunction

  function automatic hpdcache_pkg::hpdcache_user_cfg_t hpicacheSetConfig();
    hpdcache_pkg::hpdcache_user_cfg_t userCfg = '0;
    userCfg.nRequesters = 1;
    userCfg.paWidth = CVA6Cfg.PLEN;
    userCfg.wordWidth = 32;
    userCfg.sets = 2 ** (CVA6Cfg.ICACHE_INDEX_WIDTH - $clog2(CVA6Cfg.ICACHE_LINE_WIDTH / 8));
    userCfg.ways = CVA6Cfg.ICACHE_SET_ASSOC;
    userCfg.clWords = CVA6Cfg.ICACHE_LINE_WIDTH / userCfg.wordWidth;
    userCfg.reqWords = CVA6Cfg.FETCH_WIDTH / userCfg.wordWidth;
    userCfg.reqTransIdWidth = 1;
    userCfg.reqSrcIdWidth = 1;
    userCfg.victimSel = hpdcache_pkg::HPDCACHE_VICTIM_RANDOM;
    userCfg.dataWaysPerRamWord = __minu(CVA6Cfg.ICACHE_SET_ASSOC, 128 / userCfg.wordWidth);
    userCfg.dataSetsPerRam = userCfg.sets;
    userCfg.accessWords = __maxu(CVA6Cfg.AxiDataWidth / userCfg.wordWidth, userCfg.reqWords);
    userCfg.mshrSets = 1;
    userCfg.mshrWays = 1;
    userCfg.mshrWaysPerRamWord = userCfg.mshrWays;
    userCfg.mshrSetsPerRam = userCfg.mshrSets;
    userCfg.mshrRamByteEnable = 1'b0;
    userCfg.mshrUseRegbank = 1'b1;
    userCfg.refillCoreRspFeedthrough = 1'b1;
    userCfg.refillFifoDepth = 2 * (userCfg.clWords / userCfg.accessWords);
    userCfg.wbufDirEntries = 0;
    userCfg.wbufDataEntries = 0;
    userCfg.wbufWords = 0;
    userCfg.wbufTimecntWidth = 3;
    userCfg.rtabEntries = 1;
    userCfg.flushEntries = 0;
    userCfg.flushFifoDepth = 0;
    userCfg.memAddrWidth = CVA6Cfg.AxiAddrWidth;
    userCfg.memIdWidth = ICACHE_MEM_ID_WIDTH;
    userCfg.memDataWidth = CVA6Cfg.AxiDataWidth;
    userCfg.wtEn = 1'b0;
    userCfg.wbEn = 1'b0;
    userCfg.lowLatency = 1'b1;
    return userCfg;
  endfunction

  localparam hpdcache_pkg::hpdcache_user_cfg_t HPIcacheUserCfg = hpicacheSetConfig();
  localparam hpdcache_pkg::hpdcache_cfg_t HPIcacheCfg = hpdcache_pkg::hpdcacheBuildConfig(
      HPIcacheUserCfg
  );

  `HPDCACHE_TYPEDEF_MEM_ATTR_T(hpdcache_mem_addr_t, hpdcache_mem_id_t, hpdcache_mem_data_t,
                               hpdcache_mem_be_t, HPIcacheCfg);
  `HPDCACHE_TYPEDEF_MEM_REQ_T(hpdcache_mem_req_t, hpdcache_mem_addr_t, hpdcache_mem_id_t);
  `HPDCACHE_TYPEDEF_MEM_RESP_R_T(hpdcache_mem_resp_r_t, hpdcache_mem_id_t, hpdcache_mem_data_t);
  `HPDCACHE_TYPEDEF_MEM_REQ_W_T(hpdcache_mem_req_w_t, hpdcache_mem_data_t, hpdcache_mem_be_t);
  `HPDCACHE_TYPEDEF_MEM_RESP_W_T(hpdcache_mem_resp_w_t, hpdcache_mem_id_t);

  `HPDCACHE_TYPEDEF_REQ_ATTR_T(hpdcache_req_offset_t, hpdcache_data_word_t, hpdcache_data_be_t,
                               hpdcache_req_data_t, hpdcache_req_be_t, hpdcache_req_sid_t,
                               hpdcache_req_tid_t, hpdcache_tag_t, HPIcacheCfg);
  `HPDCACHE_TYPEDEF_REQ_T(hpdcache_req_t, hpdcache_req_offset_t, hpdcache_req_data_t,
                          hpdcache_req_be_t, hpdcache_req_sid_t, hpdcache_req_tid_t,
                          hpdcache_tag_t);
  `HPDCACHE_TYPEDEF_RSP_T(hpdcache_rsp_t, hpdcache_req_data_t, hpdcache_req_sid_t,
                          hpdcache_req_tid_t);

  typedef logic [HPIcacheCfg.u.wbufTimecntWidth-1:0] hpdcache_wbuf_timecnt_t;
  //  }}}

  // I$->AXI: private hpicache L1 instruction caches
  ypb_fetch_req_t [NrHarts-1:0] ypb_fetch_req;
  ypb_fetch_rsp_t [NrHarts-1:0] ypb_fetch_rsp;


  // NoC multiplexer: port 0 is the shared L1d subsystem, 1..NrHarts the L1i
  noc_req_t  [NOC_MUX_PORTS-1:0] noc_mux_req;
  noc_resp_t [NOC_MUX_PORTS-1:0] noc_mux_resp;

  // I$ miss responses of the shared subsystem (inputs tied off)
  icache_rtrn_t [NrHarts-1:0] icache_miss_resp;
  logic [NrHarts-1:0] icache_miss_ready;
  logic [NrHarts-1:0] icache_miss_resp_valid;

  // AMO
  amo_req_t [NrHarts-1:0] amo_req;
  amo_resp_t [NrHarts-1:0] amo_resp;

  // Perf counters
  logic [NrHarts-1:0] dcache_miss_cache_perf;
  logic [NrHarts-1:0][NUM_CACHE_PORTS-1:0][CVA6Cfg.DCACHE_SET_ASSOC-1:0] miss_vld_bits;

  // Accelerator
  logic [NrHarts-1:0][63:0] inval_addr;
  logic [NrHarts-1:0] inval_valid;
  logic [NrHarts-1:0] inval_ready;

  // Data-endian-ness
  logic [NrHarts-1:0] mbe;


  // Cores + (private) I$
  generate
    for (genvar HartId = 0; HartId < NrHarts; HartId++) begin : gen_one_core

      // I$ signals
      logic icache_en_csr;
      logic icache_flush_ctrl_cache;
      icache_areq_t icache_areq_ex_cache;
      icache_arsp_t icache_areq_cache_ex;
      icache_dreq_t icache_dreq_if_cache;
      icache_drsp_t icache_dreq_cache_if;

      // Perf counters
      logic icache_miss_cache_perf;

      cva6_cacheless #(
          .CVA6Cfg(CVA6Cfg),
          .rvfi_probes_instr_t(rvfi_probes_instr_t),
          .rvfi_probes_csr_t(rvfi_probes_csr_t),
          .rvfi_probes_t(rvfi_probes_t),
          .exception_t(exception_t),
          .icache_areq_t(icache_areq_t),
          .icache_arsp_t(icache_arsp_t),
          .icache_dreq_t(icache_dreq_t),
          .icache_drsp_t(icache_drsp_t),
          .cbo_t(cbo_t),
          .dcache_req_i_t(dcache_req_i_t),
          .dcache_req_o_t(dcache_req_o_t),
          .readregflags_t(readregflags_t),
          .writeregflags_t(writeregflags_t),
          .id_t(id_t),
          .hartid_t(hartid_t),
          .x_compressed_req_t(x_compressed_req_t),
          .x_compressed_resp_t(x_compressed_resp_t),
          .x_issue_req_t(x_issue_req_t),
          .x_issue_resp_t(x_issue_resp_t),
          .x_register_t(x_register_t),
          .x_commit_t(x_commit_t),
          .x_result_t(x_result_t),
          .NumCachePorts(NUM_CACHE_PORTS)
      ) i_cva6 (
          .clk_i                         (clk_i),
          .rst_ni                        (rst_ni),
          .boot_addr_i                   (boot_addr_i),
          .hart_id_i                     (HartId),
          .irq_i                         (irq_i[HartId]),
          .ipi_i                         (ipi_i[HartId]),
          .time_irq_i                    (time_irq_i[HartId]),
          .debug_req_i                   (debug_req_i[HartId]),
          .rvfi_probes_o                 (rvfi_probes_o[HartId]),
          .cvxif_req_o                   (cvxif_req_o[HartId]),
          .cvxif_resp_i                  (cvxif_resp_i[HartId]),
          .icache_en_csr_o               (icache_en_csr),
          .icache_flush_ctrl_cache_o     (icache_flush_ctrl_cache),
          .dcache_miss_cache_perf_i      (dcache_miss_cache_perf[HartId]),
          .icache_miss_cache_perf_i      (icache_miss_cache_perf),
          .icache_areq_ex_cache_o        (icache_areq_ex_cache),
          .icache_areq_cache_ex_i        (icache_areq_cache_ex),
          .icache_dreq_if_cache_o        (icache_dreq_if_cache),
          .icache_dreq_cache_if_i        (icache_dreq_cache_if),
          .dcache_en_csr_o               (dcache_en_csr[HartId]),
          .dcache_flush_ctrl_cache_o     (dcache_flush_ctrl_cache[HartId]),
          .dcache_flush_ack_cache_ctrl_i (dcache_flush_ack_cache_ctrl[HartId]),
          .dcache_scrub_en_o             (dcache_scrub_en[HartId]),
          .dcache_scrub_period_o         (dcache_scrub_period[HartId]),
          .dcache_scrub_cycle_i          (dcache_scrub_cycle[HartId]),
          .dcache_dat_cor_err_i          (dcache_dat_cor_err[HartId]),
          .dcache_dat_unc_err_i          (dcache_dat_unc_err[HartId]),
          .dcache_dir_cor_err_i          (dcache_dir_cor_err[HartId]),
          .dcache_dir_unc_err_i          (dcache_dir_unc_err[HartId]),
          .dcache_commit_wbuffer_empty_i (dcache_commit_wbuffer_empty[HartId]),
          .dcache_commit_wbuffer_not_ni_i(dcache_commit_wbuffer_not_ni[HartId]),
          .dcache_req_from_cache_i       (dcache_req_from_cache[HartId]),
          .dcache_req_to_cache_o         (dcache_req_to_cache[HartId]),
          .amo_req_o                     (amo_req[HartId]),
          .amo_resp_i                    (amo_resp[HartId]),
          .miss_vld_bits_i               (miss_vld_bits[HartId]),
          .inval_ready_i                 (inval_ready[HartId]),
          .inval_addr_o                  (inval_addr[HartId]),
          .inval_valid_o                 (inval_valid[HartId]),
          .mbe_o                         (mbe[HartId])
      );

      cva6_fetch_bridge #(
          .CVA6Cfg(CVA6Cfg),
          .icache_areq_t(icache_areq_t),
          .icache_arsp_t(icache_arsp_t),
          .icache_dreq_t(icache_dreq_t),
          .icache_drsp_t(icache_drsp_t),
          .ypb_fetch_req_t(ypb_fetch_req_t),
          .ypb_fetch_rsp_t(ypb_fetch_rsp_t)
      ) i_fetch_bridge (
          .clk_i          (clk_i),
          .rst_ni         (rst_ni),
          .flush_i        (icache_flush_ctrl_cache),
          .en_i           (icache_en_csr),
          .areq_i         (icache_areq_ex_cache),
          .areq_o         (icache_areq_cache_ex),
          .dreq_i         (icache_dreq_if_cache),
          .dreq_o         (icache_dreq_cache_if),
          .ypb_fetch_req_o(ypb_fetch_req[HartId]),
          .ypb_fetch_rsp_i(ypb_fetch_rsp[HartId])
      );

      //  The memory interface between the L1 instruction cache of the hart and
      //  the AXI arbiter which puts its reads on the NoC
      logic icache_mem_req_valid;
      logic icache_mem_req_ready;
      hpdcache_mem_req_t icache_mem_req;
      logic icache_mem_resp_valid;
      logic icache_mem_resp_ready;
      hpdcache_mem_resp_r_t icache_mem_resp;

      //  The invalidations of the OpenPiton L15 do not reach the private
      //  instruction caches of the multicore top: the L15 adapter of the shared
      //  data cache, the only source of them, is not part of this SoC.
      logic icache_resp_inval;
      logic [HPIcacheCfg.nlineWidth-1:0] icache_resp_inval_nline;
      assign icache_resp_inval       = 1'b0;
      assign icache_resp_inval_nline = '0;

      cva6_hpicache_wrapper #(
          .CVA6Cfg(CVA6Cfg),
          .HPDcacheCfg(HPIcacheCfg),
          .ypb_fetch_req_t(ypb_fetch_req_t),
          .ypb_fetch_rsp_t(ypb_fetch_rsp_t),
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
      ) i_cva6_hpicache (
          .clk_i (clk_i),
          .rst_ni(rst_ni),

          .icache_enable_i   (icache_en_csr),
          .icache_flush_i    (icache_flush_ctrl_cache),
          .icache_flush_ack_o(  /* unused */),
          .icache_miss_o     (icache_miss_cache_perf),

          .ypb_fetch_req_i(ypb_fetch_req[HartId]),
          .ypb_fetch_rsp_o(ypb_fetch_rsp[HartId]),

          .icache_mem_req_read_ready_i(icache_mem_req_ready),
          .icache_mem_req_read_valid_o(icache_mem_req_valid),
          .icache_mem_req_read_o      (icache_mem_req),

          .icache_mem_resp_read_ready_o(icache_mem_resp_ready),
          .icache_mem_resp_read_valid_i(icache_mem_resp_valid),
          .icache_mem_resp_read_i      (icache_mem_resp),
          .icache_mem_resp_read_inval_i(icache_resp_inval),
          .icache_mem_resp_read_inval_nline_i(icache_resp_inval_nline)
      );

      cva6_hpdcache_subsystem_axi_arbiter #(
          .CVA6Cfg(MemCfg),
          .hpdcache_mem_addr_t(hpdcache_mem_addr_t),
          .hpdcache_mem_id_t(hpdcache_mem_id_t),
          .hpdcache_mem_data_t(hpdcache_mem_data_t),
          .hpdcache_mem_be_t(hpdcache_mem_be_t),
          .hpdcache_mem_req_t(hpdcache_mem_req_t),
          .hpdcache_mem_req_w_t(hpdcache_mem_req_w_t),
          .hpdcache_mem_resp_r_t(hpdcache_mem_resp_r_t),
          .hpdcache_mem_resp_w_t(hpdcache_mem_resp_w_t),
          .AxiAddrWidth (CVA6Cfg.AxiAddrWidth),
          .AxiDataWidth (CVA6Cfg.AxiDataWidth),
          .AxiIdWidth   (MemCfg.AxiIdWidth),
          .AxiUserWidth (CVA6Cfg.AxiUserWidth),
          .axi_ar_chan_t(axi_ar_chan_t),
          .axi_aw_chan_t(axi_aw_chan_t),
          .axi_w_chan_t (axi_w_chan_t),
          .axi_b_chan_t(b_chan_t),
          .axi_r_chan_t(r_chan_t),
          .axi_req_t(noc_req_t),
          .axi_rsp_t(noc_resp_t)
      ) i_icache_axi_arbiter (
          .clk_i (clk_i),
          .rst_ni(rst_ni),

          //  The hpicache L1 serves its own misses: classic relay tied off
          .icache_miss_valid_i     (1'b0),
          .icache_miss_ready_o     (  /* unused */),
          .icache_miss_i           ('0),
          .icache_miss_resp_valid_o(  /* unused */),
          .icache_miss_resp_ready_i(1'b1),
          .icache_miss_resp_o      (  /* unused */),

          .dcache_read_ready_o(icache_mem_req_ready),
          .dcache_read_valid_i(icache_mem_req_valid),
          .dcache_read_i      (icache_mem_req),

          .dcache_read_resp_ready_i(icache_mem_resp_ready),
          .dcache_read_resp_valid_o(icache_mem_resp_valid),
          .dcache_read_resp_o      (icache_mem_resp),

          //  Read-only cache: write channel tied off
          .dcache_write_ready_o     (  /* unused */),
          .dcache_write_valid_i     (1'b0),
          .dcache_write_i           ('0),
          .dcache_write_data_ready_o(  /* unused */),
          .dcache_write_data_valid_i(1'b0),
          .dcache_write_data_i      ('0),
          .dcache_write_resp_ready_i(1'b1),
          .dcache_write_resp_valid_o(  /* unused */),
          .dcache_write_resp_o      (  /* unused */),

          .axi_req_o (noc_mux_req[HartId+1]),
          .axi_resp_i(noc_mux_resp[HartId+1])
      );

      //  Assertions
      //  {{{
      //  pragma translate_off
      a_invalid_instruction_fetch :
      assert property (
      @(posedge clk_i) disable iff (!rst_ni) icache_dreq_cache_if.valid |-> (|icache_dreq_cache_if.data) !== 1'hX)
      else
        $warning(
            1,
            "[l1 dcache] reading invalid instructions: vaddr=%08X, data=%08X",
            icache_dreq_cache_if.vaddr,
            icache_dreq_cache_if.data
        );

      a_invalid_write_data :
      assert property (
      @(posedge clk_i) disable iff (!rst_ni) dcache_req_to_cache[HartId][2].data_req |-> |dcache_req_to_cache[HartId][2].data_be |-> (|dcache_req_to_cache[HartId][2].data_wdata) !== 1'hX)
      else
        $warning(
            1,
            "[l1 dcache] writing invalid data: paddr=%016X, be=%02X, data=%016X",
            {
              dcache_req_to_cache[HartId][2].address_tag,
              dcache_req_to_cache[HartId][2].address_index
            },
            dcache_req_to_cache[HartId][2].data_be,
            dcache_req_to_cache[HartId][2].data_wdata
        );

      for (genvar j = 0; j < 2; j++) begin : gen_assertion
        a_invalid_read_data :
        assert property (
        @(posedge clk_i) disable iff (!rst_ni) dcache_req_from_cache[HartId][j].data_rvalid && ~dcache_req_to_cache[HartId][j].kill_req |-> (|dcache_req_from_cache[HartId][j].data_rdata) !== 1'hX)
        else
          $warning(
              1,
              "[l1 dcache] reading invalid data on port %01d: data=%016X",
              j,
              dcache_req_from_cache[HartId][j].data_rdata
          );
      end
      //  pragma translate_on
      //  }}}

    end
  endgenerate


  //  The shared L1d of the multicore SoC is the high performance cache: the
  //  write-through subsystem upstream folded into the write policy of that
  //  cache never had a multicore version, and the OpenPiton fabric reaches the
  //  top through the L15 adapter of the same cache.
  if (
        CVA6Cfg.MemSubsystem == config_pkg::MEM_HPDCACHE_AXI ||
        CVA6Cfg.MemSubsystem == config_pkg::MEM_HPDCACHE_L15
    ) begin : gen_cache_hpd
    cva6_multicore_hpdcache_subsystem #(
        .CVA6Cfg(CVA6Cfg),
        .icache_req_t(icache_req_t),
        .icache_rtrn_t(icache_rtrn_t),
        .dcache_req_i_t(dcache_req_i_t),
        .dcache_req_o_t(dcache_req_o_t),
        .NrHarts(NrHarts),
        .NumPorts(NUM_CACHE_PORTS),
        .MemTidWidth(MemTidWidth),
        .MemIdWidth(DCACHE_MEM_ID_WIDTH),
        .ICacheRdtxid(ICACHE_RDTXID),
        .axi_ar_chan_t(axi_ar_chan_t),
        .axi_aw_chan_t(axi_aw_chan_t),
        .axi_w_chan_t(axi_w_chan_t),
        .axi_b_chan_t(b_chan_t),
        .axi_r_chan_t(r_chan_t),
        .noc_req_t(noc_req_t),
        .noc_resp_t(noc_resp_t)
    ) i_cva6_hpdcache_subsystem (
        .clk_i (clk_i),
        .rst_ni(rst_ni),

        .icache_miss_valid_i     ('0),
        .icache_miss_ready_o     (icache_miss_ready),
        .icache_miss_i           ('0),
        .icache_miss_resp_valid_o(icache_miss_resp_valid),
        .icache_miss_resp_o      (icache_miss_resp),

        .dcache_enable_i   (dcache_en_csr),
        .dcache_flush_i    (dcache_flush_ctrl_cache),
        .dcache_flush_ack_o(dcache_flush_ack_cache_ctrl),
        .dcache_miss_o     (dcache_miss_cache_perf),

        .dcache_scrub_enable_i(dcache_scrub_en),
        .dcache_scrub_period_i(dcache_scrub_period),
        .dcache_scrub_cycle_o (dcache_scrub_cycle),
        .dcache_dat_cor_err_o (dcache_dat_cor_err),
        .dcache_dat_unc_err_o (dcache_dat_unc_err),
        .dcache_dir_cor_err_o (dcache_dir_cor_err),
        .dcache_dir_unc_err_o (dcache_dir_unc_err),

        .dcache_amo_req_i (amo_req),
        .dcache_amo_resp_o(amo_resp),

        .dcache_req_ports_i(dcache_req_to_cache),
        .dcache_req_ports_o(dcache_req_from_cache),

        .wbuffer_empty_o (dcache_commit_wbuffer_empty),
        .wbuffer_not_ni_o(dcache_commit_wbuffer_not_ni),

        .hwpf_base_set_i    ('0  /*FIXME*/),
        .hwpf_base_i        ('0  /*FIXME*/),
        .hwpf_base_o        (  /*FIXME*/),
        .hwpf_param_set_i   ('0  /*FIXME*/),
        .hwpf_param_i       ('0  /*FIXME*/),
        .hwpf_param_o       (  /*FIXME*/),
        .hwpf_throttle_set_i('0  /*FIXME*/),
        .hwpf_throttle_i    ('0  /*FIXME*/),
        .hwpf_throttle_o    (  /*FIXME*/),
        .hwpf_status_o      (  /*FIXME*/),


        .noc_req_o (noc_mux_req[0]),
        .noc_resp_i(noc_mux_resp[0])
    );
    assign inval_ready = 1'b1;

  end else begin : gen_unsupported_cache_subsystem
    //  No data cache for those harts: the configuration asks for a memory
    //  subsystem the multicore top does not wire the cores to.
    initial begin : check_mem_subsystem
      assert (0)
      else $fatal(
          1,
          "cva6_multicore: MemSubsystem %0s is not supported, the multicore SoC needs MEM_HPDCACHE_AXI or MEM_HPDCACHE_L15",
          CVA6Cfg.MemSubsystem.name()
      );
    end
    assign noc_mux_req[0]               = '0;
    assign icache_miss_ready            = '0;
    assign icache_miss_resp_valid       = '0;
    assign icache_miss_resp             = '0;
    assign dcache_flush_ack_cache_ctrl  = '0;
    assign dcache_miss_cache_perf       = '0;
    assign miss_vld_bits                = '0;
    assign dcache_req_from_cache        = '0;
    assign dcache_commit_wbuffer_empty  = '0;
    assign dcache_commit_wbuffer_not_ni = '0;
    assign amo_resp                     = '0;
    assign inval_ready                  = '0;
    assign dcache_scrub_cycle           = '0;
    assign dcache_dat_cor_err           = '0;
    assign dcache_dat_unc_err           = '0;
    assign dcache_dir_cor_err           = '0;
    assign dcache_dir_unc_err           = '0;
  end

  //  NoC multiplexer: merge the shared L1d subsystem and the private hpicache
  //  L1i instruction caches into the single NoC master port
  //  {{{
  axi_mux #(
      .SlvAxiIDWidth(NOC_MUX_SLV_ID_WIDTH),
      .slv_aw_chan_t(axi_aw_chan_t),
      .mst_aw_chan_t(axi_aw_chan_t),
      .w_chan_t     (axi_w_chan_t),
      .slv_b_chan_t (b_chan_t),
      .mst_b_chan_t (b_chan_t),
      .slv_ar_chan_t(axi_ar_chan_t),
      .mst_ar_chan_t(axi_ar_chan_t),
      .slv_r_chan_t (r_chan_t),
      .mst_r_chan_t (r_chan_t),
      .slv_req_t    (noc_req_t),
      .slv_resp_t   (noc_resp_t),
      .mst_req_t    (noc_req_t),
      .mst_resp_t   (noc_resp_t),
      .NoSlvPorts   (NOC_MUX_PORTS),
      .MaxWTrans    (8),
      .FallThrough  (1'b0),
      .SpillAw      (1'b1),
      .SpillW       (1'b0),
      .SpillB       (1'b0),
      .SpillAr      (1'b1),
      .SpillR       (1'b0)
  ) i_noc_axi_mux (
      .clk_i      (clk_i),
      .rst_ni     (rst_ni),
      .test_i     (1'b0),
      .slv_reqs_i (noc_mux_req),
      .slv_resps_o(noc_mux_resp),
      .mst_req_o  (noc_req_o),
      .mst_resp_i (noc_resp_i)
  );
  //  }}}

endmodule
