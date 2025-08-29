`include "rvfi_types.svh"
`include "cvxif_types.svh"

module cva6_multicore_cache_arbitrer #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type icache_req_t = logic,
    parameter type icache_rtrn_t = logic,
    parameter type dcache_req_i_t = logic,
    parameter type dcache_req_o_t = logic,
    parameter unsigned NrHarts = 1,
    parameter unsigned NumPorts = 4
) (
    input logic clk_i,
    input logic rst_ni,

    /// Signals to/from cores
    //  I$
    input logic [NrHarts-1:0] cores_icache_miss_valid_i,
    output logic [NrHarts-1:0] cores_icache_miss_ready_o,
    input icache_req_t [NrHarts-1:0] cores_icache_miss_i,

    output logic [NrHarts-1:0] cores_icache_miss_resp_valid_o,
    output icache_rtrn_t [NrHarts-1:0] cores_icache_miss_resp_o,

    //  D$
    // Data cache enable - CSR_REGFILE
    input  logic [NrHarts-1:0] cores_dcache_enable_i,
    // Data cache flush - CONTROLLER
    input  logic [NrHarts-1:0] cores_dcache_flush_i,
    // Flush acknowledge - CONTROLLER
    output logic [NrHarts-1:0] cores_dcache_flush_ack_o,
    // Load or store miss - PERF_COUNTERS
    output logic [NrHarts-1:0] cores_dcache_miss_o,

    // AMO request - EX_STAGE
    input  ariane_pkg::amo_req_t  [NrHarts-1:0]               cores_dcache_amo_req_i,
    // AMO response - EX_STAGE
    output ariane_pkg::amo_resp_t [NrHarts-1:0]               cores_dcache_amo_resp_o,
    // Data cache input request ports - EX_STAGE
    input  dcache_req_i_t         [NrHarts-1:0][NumPorts-1:0] cores_dcache_req_ports_i,
    // Data cache output request ports - EX_STAGE
    output dcache_req_o_t         [NrHarts-1:0][NumPorts-1:0] cores_dcache_req_ports_o,
    // Write buffer status to know if empty - EX_STAGE
    output logic                  [NrHarts-1:0]               cores_wbuffer_empty_o,
    // Write buffer status to know if not non idempotent - EX_STAGE
    output logic                  [NrHarts-1:0]               cores_wbuffer_not_ni_o,

    /// Signals to/from cache
    output logic cache_icache_miss_valid_o,
    input logic cache_icache_miss_ready_i,
    output icache_req_t cache_icache_miss_o,

    input logic cache_icache_miss_resp_valid_i,
    input icache_rtrn_t cache_icache_miss_resp_i,

    //  D$
    // Data cache enable
    output logic cache_dcache_enable_o,
    // Data cache flush
    output logic cache_dcache_flush_o,
    // Flush acknowledge
    input  logic cache_dcache_flush_ack_i,
    // Load or store miss
    input  logic cache_dcache_miss_i,

    // AMO request
    output ariane_pkg::amo_req_t                         cache_dcache_amo_req_o,
    // AMO response
    input  ariane_pkg::amo_resp_t                        cache_dcache_amo_resp_i,
    // Data cache input request ports
    output dcache_req_i_t         [NumPorts*NrHarts-1:0] cache_dcache_req_ports_o,
    // Data cache output request ports
    input  dcache_req_o_t         [NumPorts*NrHarts-1:0] cache_dcache_req_ports_i,
    // Write buffer status to know if empty
    input  logic                                         cache_wbuffer_empty_i,
    // Write buffer status to know if not non idempotent
    input  logic                                         cache_wbuffer_not_ni_i
);
  logic unsigned [$clog2(NrHarts):0] flush_serviced_hart = '0;
  logic unsigned [$clog2(NrHarts):0] amo_serviced_hart = '0;
  logic unsigned [$clog2(NrHarts):0] icache_serviced_hart = '0;

  // Globally
  assign cache_dcache_enable_o = &cores_dcache_enable_i;
  assign cache_dcache_flush_o = |cores_dcache_flush_i;

  assign cache_icache_miss_valid_o = |cores_icache_miss_valid_i;
  assign cache_icache_miss_o = cores_icache_miss_i[icache_serviced_hart];

  // Dispatched depending on serviced core
  // FIXME: this needs to be clocked and buffered
  genvar HartId, PortId;
  generate
    for (HartId = 0; HartId < NrHarts; HartId++) begin : gen_cores_cache_signals
      assign cores_dcache_amo_resp_o[HartId] = (amo_serviced_hart == HartId) ?
                                               cache_dcache_amo_resp_i :
                                               '0;

      assign cores_dcache_flush_ack_o[HartId] = (flush_serviced_hart == HartId) ?
                                                cache_dcache_flush_ack_i :
                                                1'b0;
      assign cores_dcache_miss_o[HartId] = cache_dcache_miss_i;

      assign cores_wbuffer_empty_o[HartId] = cache_wbuffer_empty_i;
      assign cores_wbuffer_not_ni_o[HartId] = cache_wbuffer_not_ni_i;

      assign cores_icache_miss_resp_o[HartId] = (HartId == icache_serviced_hart)?
                                                cache_icache_miss_resp_i:
                                                '0;
      assign cores_icache_miss_resp_valid_o[HartId] = (HartId == icache_serviced_hart)?
                                                      cache_icache_miss_resp_valid_i:
                                                      '0;
      assign cores_icache_miss_ready_o[HartId] = (HartId == icache_serviced_hart)?
                                                 cache_icache_miss_ready_i:
                                                 '0;

      for (PortId = 0; PortId < NumPorts; PortId++) begin : gen_dispatch_cores_ports
        assign cache_dcache_req_ports_o[HartId*NumPorts + PortId] =
          cores_dcache_req_ports_i[HartId][PortId];
        assign cores_dcache_req_ports_o[HartId][PortId] =
          cache_dcache_req_ports_i[HartId*NumPorts + PortId];
      end
    end
  endgenerate

  // Chosing which hart to service
  // TODO

endmodule
