`include "rvfi_types.svh"
`include "cvxif_types.svh"

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

    // I$ requests
    localparam type icache_req_t = struct packed {
      logic [CVA6Cfg.ICACHE_SET_ASSOC_WIDTH-1:0] way;  // way to replace
      logic [CVA6Cfg.PLEN-1:0] paddr;  // physical address
      logic nc;  // noncacheable
      logic [CVA6Cfg.MEM_TID_WIDTH-1:0] tid;  // thread id (used as transaction id in Ariane)
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
      logic [CVA6Cfg.MEM_TID_WIDTH-1:0] tid;  // thread id (used as transaction id in Ariane)
    },

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
    },
    localparam type dcache_req_o_t = struct packed {
      logic                                 data_gnt;
      logic                                 data_rvalid;
      logic [CVA6Cfg.DcacheIdWidth-1:0]     data_rid;
      logic [CVA6Cfg.XLEN-1:0]              data_rdata;
      logic [CVA6Cfg.DCACHE_USER_WIDTH-1:0] data_ruser;
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
    input logic [NrHarts*2-1:0] irq_i,  // level sensitive IR lines, mip & sip (async)
    input logic [NrHarts-1:0] ipi_i,  // inter-processor interrupts (async)
    // Timer facilities
    input logic [NrHarts-1:0] time_irq_i,  // timer interrupt in (async)
    input logic [NrHarts-1:0] debug_req_i,  // debug request (async)
    // Probes to build RVFI, can be left open when not used - RVFI
    output rvfi_probes_t [NrHarts-1:0] rvfi_probes_o,
    // CVXIF request - SUBSYSTEM
    output cvxif_req_t [NrHarts-1:0] cvxif_req_o,
    // CVXIF response - SUBSYSTEM
    input cvxif_resp_t [NrHarts-1:0] cvxif_resp_i,
    // memory side
    output noc_req_t noc_req_o,
    input noc_resp_t noc_resp_i
);
  localparam unsigned NUM_CACHE_PORTS = 4;
  localparam unsigned NUM_HW_PREFETCHERS = 4;
  localparam unsigned ICACHE_RDTXID = 1 << (CVA6Cfg.MEM_TID_WIDTH - 1);

  logic [NrHarts-1:0] dcache_en_csr_nbdcache;
  logic [NrHarts-1:0] dcache_flush_ctrl_cache;
  logic [NrHarts-1:0] dcache_flush_ack_cache_ctrl;
  dcache_req_o_t [NrHarts-1:0][NUM_CACHE_PORTS-1:0] dcache_req_from_cache;
  dcache_req_i_t [NrHarts-1:0][NUM_CACHE_PORTS-1:0] dcache_req_to_cache;
  logic [NrHarts-1:0] dcache_commit_wbuffer_empty;
  logic [NrHarts-1:0] dcache_commit_wbuffer_not_ni;

  // I$->HPD$
  icache_req_t [NrHarts-1:0] icache_miss;
  icache_rtrn_t [NrHarts-1:0] icache_miss_resp;
  logic [NrHarts-1:0] icache_miss_valid;
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


  // Cores + (private) I$
  genvar HartId;
  generate
    for (HartId = 0; HartId < NrHarts; HartId++) begin : gen_one_core

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
          .exception_t(exception_t),
          .icache_areq_t(icache_areq_t),
          .icache_arsp_t(icache_arsp_t),
          .icache_dreq_t(icache_dreq_t),
          .icache_drsp_t(icache_drsp_t),
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
          .irq_i                         (irq_i[2*HartId+1:2*HartId]),
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
          .dcache_en_csr_nbdcache_o      (dcache_en_csr_nbdcache[HartId]),
          .dcache_flush_ctrl_cache_o     (dcache_flush_ctrl_cache[HartId]),
          .dcache_flush_ack_cache_ctrl_i (dcache_flush_ack_cache_ctrl[HartId]),
          .dcache_commit_wbuffer_empty_i (dcache_commit_wbuffer_empty[HartId]),
          .dcache_commit_wbuffer_not_ni_i(dcache_commit_wbuffer_not_ni[HartId]),
          .dcache_req_from_cache_i       (dcache_req_from_cache[HartId]),
          .dcache_req_to_cache_o         (dcache_req_to_cache[HartId]),
          .amo_req_o                     (amo_req[HartId]),
          .amo_resp_i                    (amo_resp[HartId]),
          .miss_vld_bits_i               (miss_vld_bits[HartId]),
          .inval_ready_i                 (inval_ready[HartId]),
          .inval_addr_o                  (inval_addr[HartId]),
          .inval_valid_o                 (inval_valid[HartId])
      );

      cva6_icache #(
          .CVA6Cfg(CVA6Cfg),
          .icache_areq_t(icache_areq_t),
          .icache_arsp_t(icache_arsp_t),
          .icache_dreq_t(icache_dreq_t),
          .icache_drsp_t(icache_drsp_t),
          .icache_req_t(icache_req_t),
          .icache_rtrn_t(icache_rtrn_t),
          .RdTxId(ICACHE_RDTXID)
      ) i_cva6_icache (
          .clk_i         (clk_i),
          .rst_ni        (rst_ni),
          .flush_i       (icache_flush_ctrl_cache),
          .en_i          (icache_en_csr),
          .miss_o        (icache_miss_cache_perf),
          .areq_i        (icache_areq_ex_cache),
          .areq_o        (icache_areq_cache_ex),
          .dreq_i        (icache_dreq_if_cache),
          .dreq_o        (icache_dreq_cache_if),
          .mem_rtrn_vld_i(icache_miss_resp_valid[HartId]),
          .mem_rtrn_i    (icache_miss_resp[HartId]),
          .mem_data_req_o(icache_miss_valid[HartId]),
          .mem_data_ack_i(icache_miss_ready[HartId]),
          .mem_data_o    (icache_miss[HartId])
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


  if (CVA6Cfg.DCacheType == config_pkg::WT) begin : gen_cache_wt
    initial begin : WT_single_core
      assert (NrHarts == 1)
      else $error("WT Cache only works in single-core mode");
    end

    multicore_wt_cache_subsystem #(
        .CVA6Cfg(CVA6Cfg),
        .dcache_req_i_t(dcache_req_i_t),
        .dcache_req_o_t(dcache_req_o_t),
        .noc_req_t(noc_req_t),
        .noc_resp_t(noc_resp_t),
        .icache_req_t(icache_req_t),
        .icache_rtrn_t(icache_rtrn_t),
        .NumPorts(NUM_CACHE_PORTS)
    ) i_multicore_wt_cache_subsystem (
        .clk_i                   (clk_i),
        .rst_ni                  (rst_ni),
        .icache_miss_valid_i     (icache_miss_valid),
        .icache_miss_ready_o     (icache_miss_ready),
        .icache_miss_i           (icache_miss),
        .icache_miss_resp_valid_o(icache_miss_resp_valid),
        .icache_miss_resp_o      (icache_miss_resp),
        .dcache_enable_i         (dcache_en_csr_nbdcache),
        .dcache_flush_i          (dcache_flush_ctrl_cache),
        .dcache_flush_ack_o      (dcache_flush_ack_cache_ctrl),
        .dcache_miss_o           (dcache_miss_cache_perf),
        .miss_vld_bits_o         (miss_vld_bits),
        .dcache_amo_req_i        (amo_req),
        .dcache_amo_resp_o       (amo_resp),
        .dcache_req_ports_i      (dcache_req_to_cache),
        .dcache_req_ports_o      (dcache_req_from_cache),
        .wbuffer_empty_o         (dcache_commit_wbuffer_empty),
        .wbuffer_not_ni_o        (dcache_commit_wbuffer_not_ni),
        .noc_req_o               (noc_req_o),
        .noc_resp_i              (noc_resp_i),
        .inval_addr_i            (inval_addr),
        .inval_valid_i           (inval_valid),
        .inval_ready_o           (inval_ready)
    );
  end else if (
        CVA6Cfg.DCacheType == config_pkg::HPDCACHE_WT ||
        CVA6Cfg.DCacheType == config_pkg::HPDCACHE_WB ||
        CVA6Cfg.DCacheType == config_pkg::HPDCACHE_WT_WB
  )
  begin : gen_cache_hpd
    cva6_multicore_hpdcache_subsystem #(
        .CVA6Cfg(CVA6Cfg),
        .icache_req_t(icache_req_t),
        .icache_rtrn_t(icache_rtrn_t),
        .dcache_req_i_t(dcache_req_i_t),
        .dcache_req_o_t(dcache_req_o_t),
        .NrHarts(NrHarts),
        .NumPorts(NUM_CACHE_PORTS),
        .axi_ar_chan_t(axi_ar_chan_t),
        .axi_aw_chan_t(axi_aw_chan_t),
        .axi_w_chan_t(axi_w_chan_t),
        .axi_b_chan_t(b_chan_t),
        .axi_r_chan_t(r_chan_t),
        .noc_req_t(noc_req_t),
        .noc_resp_t(noc_resp_t),
        .cmo_req_t(logic  /*FIXME*/),
        .cmo_rsp_t(logic  /*FIXME*/)
    ) i_cva6_hpdcache_subsystem (
        .clk_i                   (clk_i),
        .rst_ni                  (rst_ni),
        .icache_miss_valid_i     (icache_miss_valid),
        .icache_miss_ready_o     (icache_miss_ready),
        .icache_miss_i           (icache_miss),
        .icache_miss_resp_valid_o(icache_miss_resp_valid),
        .icache_miss_resp_o      (icache_miss_resp),
        .dcache_enable_i         (dcache_en_csr_nbdcache),
        .dcache_flush_i          (dcache_flush_ctrl_cache),
        .dcache_flush_ack_o      (dcache_flush_ack_cache_ctrl),
        .dcache_miss_o           (dcache_miss_cache_perf),
        .dcache_amo_req_i        (amo_req),
        .dcache_amo_resp_o       (amo_resp),
        .dcache_req_ports_i      (dcache_req_to_cache),
        .dcache_req_ports_o      (dcache_req_from_cache),
        .wbuffer_empty_o         (dcache_commit_wbuffer_empty),
        .wbuffer_not_ni_o        (dcache_commit_wbuffer_not_ni),
        .noc_req_o               (noc_req_o),
        .noc_resp_i              (noc_resp_i)
    );
    assign inval_ready = 1'b1;
  end

endmodule
