module shared_fpu
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type exception_t = logic,
    parameter type fu_data_t = logic,
    parameter unsigned NrHarts = 1
) (
    input logic clk_i,
    input logic rst_ni,

    input logic     [NrHarts-1:0]                           flush_i,
    input logic     [NrHarts-1:0][CVA6Cfg.NrIssuePorts-1:0] fpu_valid_i,
    input fu_data_t [NrHarts-1:0][CVA6Cfg.NrIssuePorts-1:0] fu_data_i,
    input logic     [NrHarts-1:0][                     1:0] fpu_fmt_i,
    input logic     [NrHarts-1:0][                     2:0] fpu_rm_i,
    input logic     [NrHarts-1:0][                     2:0] fpu_frm_i,
    input logic     [NrHarts-1:0][                     6:0] fpu_prec_i,
    // input logic     [CVA6Cfg.XLEN-1:0]                           hart_id_i,

    output logic [NrHarts-1:0][CVA6Cfg.TRANS_ID_BITS-1:0] fpu_trans_id_o,
    output logic [NrHarts-1:0][CVA6Cfg.XLEN-1:0] result_o,

    output exception_t [NrHarts-1:0] fpu_exception_o,
    output logic       [NrHarts-1:0] fpu_ready_o,
    output logic       [NrHarts-1:0] fpu_valid_o,
    output logic       [NrHarts-1:0] fpu_early_valid_o
);

  // logic last_port;
  logic                                   internal_flush_i;
  logic       [ CVA6Cfg.NrIssuePorts-1:0] internal_fpu_valid_i;
  fu_data_t   [ CVA6Cfg.NrIssuePorts-1:0] internal_fu_data_i;
  logic       [                      1:0] internal_fpu_fmt_i;
  logic       [                      2:0] internal_fpu_rm_i;
  logic       [                      2:0] internal_fpu_frm_i;
  logic       [                      6:0] internal_fpu_prec_i;

  logic       [CVA6Cfg.TRANS_ID_BITS-1:0] internal_fpu_trans_id_o;
  logic       [         CVA6Cfg.XLEN-1:0] internal_result_o;
  exception_t                             internal_fpu_exception_o;
  logic                                   internal_fpu_ready_o;
  logic                                   internal_fpu_valid_o;
  logic                                   internal_fpu_early_valid_o;

  if (NrHarts == unsigned'(1)) begin : gen_single_core_fpu
    assign internal_flush_i = flush_i[0];
    assign internal_fpu_valid_i = fpu_valid_i[0];
    assign internal_fu_data_i = fu_data_i[0];
    assign internal_fpu_fmt_i = fpu_fmt_i[0];
    assign internal_fpu_rm_i = fpu_rm_i[0];
    assign internal_fpu_frm_i = fpu_frm_i[0];
    assign internal_fpu_prec_i = fpu_prec_i[0];

    logic fpu_valid;
    logic [CVA6Cfg.TRANS_ID_BITS-1:0] fpu_trans_id;
    logic [CVA6Cfg.XLEN-1:0] fpu_result;

    if (CVA6Cfg.FpPresent) begin : fpu_active_block
      fu_data_t fpu_data;
      always_comb begin
        fpu_data = internal_fpu_valid_i[0] ? internal_fu_data_i[0] : '0;
      end
      fpu_wrap #(
          .CVA6Cfg(CVA6Cfg),
          .exception_t(exception_t),
          .fu_data_t(fu_data_t)
      ) fpu_i (
          .clk_i,
          .rst_ni,
          .flush_i(internal_flush_i),
          .fpu_valid_i(|internal_fpu_valid_i),
          .fpu_ready_o(internal_fpu_ready_o),
          .fu_data_i(fpu_data),
          .fpu_fmt_i(internal_fpu_fmt_i),
          .fpu_rm_i(internal_fpu_rm_i),
          .fpu_frm_i(internal_fpu_frm_i),
          .fpu_prec_i(internal_fpu_prec_i),
          .fpu_trans_id_o(fpu_trans_id),
          .result_o(fpu_result),
          .fpu_valid_o(fpu_valid),
          .fpu_exception_o(internal_fpu_exception_o),
          .fpu_early_valid_o(internal_fpu_early_valid_o)
      );
    end else begin : no_fpu_gen
      assign fpu_result                 = '0;
      assign fpu_valid                  = '0;
      assign fpu_trans_id               = '0;
      assign internal_fpu_ready_o       = '0;
      assign internal_fpu_exception_o   = '0;
      assign internal_fpu_early_valid_o = '0;
    end
    if (CVA6Cfg.FpPresent) begin
      assign internal_fpu_valid_o = fpu_valid;
      assign internal_result_o = fpu_result;
      assign internal_fpu_trans_id_o = fpu_trans_id;
    end else begin
      assign internal_fpu_valid_o = '0;
      assign internal_result_o = '0;
      assign internal_fpu_trans_id_o = '0;
    end

    assign fpu_trans_id_o[0] = internal_fpu_trans_id_o;
    assign result_o[0] = internal_result_o;
    assign fpu_exception_o[0] = internal_fpu_exception_o;
    assign fpu_ready_o[0] = internal_fpu_ready_o;
    assign fpu_valid_o[0] = internal_fpu_valid_o;
    assign fpu_early_valid_o[0] = internal_fpu_early_valid_o;
  end
  // always_ff @(posedge clk_i or negedge rst_ni) begin : fp_rr_arb
  //   if (~rst_ni) begin
  //   end
  // end


endmodule
