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
    input fu_data_t [NrHarts-1:0]                           fu_data_i,
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

  // fu_data with an extra bit in id
  typedef struct packed {
    fu_t                            fu;
    fu_op                           operation;
    logic [CVA6Cfg.XLEN-1:0]        operand_a;
    logic [CVA6Cfg.XLEN-1:0]        operand_b;
    logic [CVA6Cfg.XLEN-1:0]        imm;
    logic [CVA6Cfg.TRANS_ID_BITS:0] trans_id;
  } fu_data_sf_t;

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

  end else begin : gen_multicore_fpu

    fu_data_sf_t                           fpu_ready_data_port_0;
    fu_data_sf_t                           fpu_ready_data_port_1;
    fu_data_sf_t                           fpu_data_mod;
    logic        [CVA6Cfg.TRANS_ID_BITS:0] id_mask_port_0 = '0;
    logic        [CVA6Cfg.TRANS_ID_BITS:0] id_mask_port_1 = (1'b1 << CVA6Cfg.TRANS_ID_BITS);
    logic                                  next_core;
    logic                                  current_core;
    logic        [            NrHarts-1:0] valid_inputs;

    typedef enum logic [1:0] {
      EMPTY,
      WAIT_DOWNSTREAM,
      DRAIN_BUFFER
    } buffer_state_t;

    buffer_state_t                            arb_buff_status;
    logic                                     arb_buff_flush_i;
    logic          [CVA6Cfg.NrIssuePorts-1:0] arb_buff_fpu_valid_i;
    fu_data_sf_t                              arb_buff_fu_data_i;
    logic          [                     1:0] arb_buff_fpu_fmt_i;
    logic          [                     2:0] arb_buff_fpu_rm_i;
    logic          [                     2:0] arb_buff_fpu_frm_i;
    logic          [                     6:0] arb_buff_fpu_prec_i;
    logic          [             NrHarts-1:0] arb_ready_out;

    always_comb begin
      fpu_ready_data_port_0.fu        = fu_data_i[0].fu;
      fpu_ready_data_port_0.operation = fu_data_i[0].operation;
      fpu_ready_data_port_0.operand_a = fu_data_i[0].operand_a;
      fpu_ready_data_port_0.operand_b = fu_data_i[0].operand_b;
      fpu_ready_data_port_0.imm       = fu_data_i[0].imm;
      fpu_ready_data_port_0.trans_id  = id_mask_port_0 | fu_data_i[0].trans_id;

      fpu_ready_data_port_1.fu        = fu_data_i[1].fu;
      fpu_ready_data_port_1.operation = fu_data_i[1].operation;
      fpu_ready_data_port_1.operand_a = fu_data_i[1].operand_a;
      fpu_ready_data_port_1.operand_b = fu_data_i[1].operand_b;
      fpu_ready_data_port_1.imm       = fu_data_i[1].imm;
      fpu_ready_data_port_1.trans_id  = id_mask_port_1 | fu_data_i[1].trans_id;

      valid_inputs[0]                 = fpu_valid_i[0][0];
      valid_inputs[1]                 = fpu_valid_i[1][0];
    end

    always_comb begin
      next_core            = current_core;
      arb_ready_out        = 2'b11;
      internal_flush_i     = flush_i[0] | flush_i[1];

      internal_fpu_valid_i = '0;
      fpu_data_mod         = '0;
      internal_fpu_fmt_i   = '0;
      internal_fpu_rm_i    = '0;
      internal_fpu_frm_i   = '0;
      internal_fpu_prec_i  = '0;

      case (arb_buff_status)
        WAIT_DOWNSTREAM: begin
          case (valid_inputs)
            2'b01: begin
              internal_flush_i     = flush_i[0];
              internal_fpu_valid_i = fpu_valid_i[0];
              internal_fpu_fmt_i   = fpu_fmt_i[0];
              internal_fpu_rm_i    = fpu_rm_i[0];
              internal_fpu_frm_i   = fpu_frm_i[0];
              internal_fpu_prec_i  = fpu_prec_i[0];
              fpu_data_mod         = fpu_ready_data_port_0;
              arb_ready_out[1]     = 1'b0;
            end
            2'b10: begin
              internal_flush_i     = flush_i[1];
              internal_fpu_valid_i = fpu_valid_i[1];
              internal_fpu_fmt_i   = fpu_fmt_i[1];
              internal_fpu_rm_i    = fpu_rm_i[1];
              internal_fpu_frm_i   = fpu_frm_i[1];
              internal_fpu_prec_i  = fpu_prec_i[1];
              fpu_data_mod         = fpu_ready_data_port_1;
              arb_ready_out[0]     = 1'b0;
            end
            2'b11: begin
              if (current_core) begin
                internal_flush_i     = flush_i[0];
                internal_fpu_valid_i = fpu_valid_i[0];
                fpu_data_mod         = fpu_ready_data_port_0;
                internal_fpu_fmt_i   = fpu_fmt_i[0];
                internal_fpu_rm_i    = fpu_rm_i[0];
                internal_fpu_frm_i   = fpu_frm_i[0];
                internal_fpu_prec_i  = fpu_prec_i[0];
                arb_ready_out[1]     = 1'b0;
                arb_ready_out[0]     = 1'b0;
              end else begin
                internal_flush_i     = flush_i[1];
                internal_fpu_valid_i = fpu_valid_i[1];
                fpu_data_mod         = fpu_ready_data_port_1;
                internal_fpu_fmt_i   = fpu_fmt_i[1];
                internal_fpu_rm_i    = fpu_rm_i[1];
                internal_fpu_frm_i   = fpu_frm_i[1];
                internal_fpu_prec_i  = fpu_prec_i[1];
                arb_ready_out[0]     = 1'b0;
                arb_ready_out[1]     = 1'b0;
              end
            end
            default: begin
              arb_ready_out = '0;
            end
          endcase
        end
        DRAIN_BUFFER: begin
          internal_flush_i     = arb_buff_flush_i;
          internal_fpu_valid_i = arb_buff_fpu_valid_i;
          fpu_data_mod         = arb_buff_fu_data_i;
          internal_fpu_fmt_i   = arb_buff_fpu_fmt_i;
          internal_fpu_rm_i    = arb_buff_fpu_rm_i;
          internal_fpu_frm_i   = arb_buff_fpu_frm_i;
          internal_fpu_prec_i  = arb_buff_fpu_prec_i;
          arb_ready_out        = '0;
        end
        default: begin
          case (valid_inputs)
            2'b01: begin
              internal_flush_i     = flush_i[0];
              internal_fpu_valid_i = fpu_valid_i[0];
              internal_fpu_fmt_i   = fpu_fmt_i[0];
              internal_fpu_rm_i    = fpu_rm_i[0];
              internal_fpu_frm_i   = fpu_frm_i[0];
              internal_fpu_prec_i  = fpu_prec_i[0];
              fpu_data_mod         = fpu_ready_data_port_0;
            end
            2'b10: begin
              internal_flush_i     = flush_i[1];
              internal_fpu_valid_i = fpu_valid_i[1];
              internal_fpu_fmt_i   = fpu_fmt_i[1];
              internal_fpu_rm_i    = fpu_rm_i[1];
              internal_fpu_frm_i   = fpu_frm_i[1];
              internal_fpu_prec_i  = fpu_prec_i[1];
              fpu_data_mod         = fpu_ready_data_port_1;
            end
            2'b11: begin
              if (current_core) begin
                internal_flush_i     = flush_i[0];
                internal_fpu_valid_i = fpu_valid_i[0];
                fpu_data_mod         = fpu_ready_data_port_0;
                internal_fpu_fmt_i   = fpu_fmt_i[0];
                internal_fpu_rm_i    = fpu_rm_i[0];
                internal_fpu_frm_i   = fpu_frm_i[0];
                internal_fpu_prec_i  = fpu_prec_i[0];
                arb_ready_out[1]     = 1'b0;
                arb_ready_out[0]     = 1'b0;
              end else begin
                internal_flush_i     = flush_i[1];
                internal_fpu_valid_i = fpu_valid_i[1];
                fpu_data_mod         = fpu_ready_data_port_1;
                internal_fpu_fmt_i   = fpu_fmt_i[1];
                internal_fpu_rm_i    = fpu_rm_i[1];
                internal_fpu_frm_i   = fpu_frm_i[1];
                internal_fpu_prec_i  = fpu_prec_i[1];
                arb_ready_out[0]     = 1'b0;
                arb_ready_out[1]     = 1'b0;
              end
              next_core = ~current_core;
            end
            default: begin
            end
          endcase
        end
      endcase

    end


    // ---------------------------------------------------------
    // Arbiter State Register
    // ---------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (~rst_ni) begin
        current_core         <= 1'b0;
        arb_buff_status      <= EMPTY;
        arb_buff_flush_i     <= '0;
        arb_buff_fpu_valid_i <= '0;
        arb_buff_fu_data_i   <= '0;
        arb_buff_fpu_fmt_i   <= '0;
        arb_buff_fpu_rm_i    <= '0;
        arb_buff_fpu_frm_i   <= '0;
        arb_buff_fpu_prec_i  <= '0;
      end else begin
        current_core <= next_core;

        case (arb_buff_status)
          EMPTY: begin
            if (valid_inputs == 2'b11) begin
              if (current_core) begin
                arb_buff_flush_i     <= flush_i[1];
                arb_buff_fpu_valid_i <= fpu_valid_i[1];
                arb_buff_fu_data_i   <= fpu_ready_data_port_1;
                arb_buff_fpu_fmt_i   <= fpu_fmt_i[1];
                arb_buff_fpu_rm_i    <= fpu_rm_i[1];
                arb_buff_fpu_frm_i   <= fpu_frm_i[1];
                arb_buff_fpu_prec_i  <= fpu_prec_i[1];
              end else begin
                arb_buff_flush_i     <= flush_i[0];
                arb_buff_fpu_valid_i <= fpu_valid_i[0];
                arb_buff_fu_data_i   <= fpu_ready_data_port_0;
                arb_buff_fpu_fmt_i   <= fpu_fmt_i[0];
                arb_buff_fpu_rm_i    <= fpu_rm_i[0];
                arb_buff_fpu_frm_i   <= fpu_frm_i[0];
                arb_buff_fpu_prec_i  <= fpu_prec_i[0];
              end
              arb_buff_status <= internal_fpu_ready_o ? DRAIN_BUFFER : WAIT_DOWNSTREAM;
            end
          end
          WAIT_DOWNSTREAM: begin
            if (internal_fpu_ready_o) begin
              arb_buff_status <= DRAIN_BUFFER;
            end
          end
          DRAIN_BUFFER: begin
            if (internal_fpu_ready_o) begin
              arb_buff_status      <= EMPTY;
              arb_buff_flush_i     <= '0;
              arb_buff_fpu_valid_i <= '0;
              arb_buff_fu_data_i   <= '0;
              arb_buff_fpu_fmt_i   <= '0;
              arb_buff_fpu_rm_i    <= '0;
              arb_buff_fpu_frm_i   <= '0;
              arb_buff_fpu_prec_i  <= '0;
            end
          end
          default: begin
            arb_buff_status      <= EMPTY;
            arb_buff_flush_i     <= '0;
            arb_buff_fpu_valid_i <= '0;
            arb_buff_fu_data_i   <= '0;
            arb_buff_fpu_fmt_i   <= '0;
            arb_buff_fpu_rm_i    <= '0;
            arb_buff_fpu_frm_i   <= '0;
            arb_buff_fpu_prec_i  <= '0;
          end
        endcase
      end
    end
    // ---------------------------------------------------------
    // Shared FPU Instantiation
    // ---------------------------------------------------------
    logic                           fpu_valid_mod;
    logic [CVA6Cfg.TRANS_ID_BITS:0] fpu_trans_id_mod;
    logic [       CVA6Cfg.XLEN-1:0] fpu_result_mod;

    if (CVA6Cfg.FpPresent) begin : fpu_active_block
      fpu_multicore_wrap #(
          .CVA6Cfg     (CVA6Cfg),
          .exception_t (exception_t),
          .fu_data_sf_t(fu_data_sf_t)
      ) fpu_i (
          .clk_i,
          .rst_ni,
          .flush_i(internal_flush_i),
          .fpu_valid_i(|internal_fpu_valid_i),
          .fpu_ready_o(internal_fpu_ready_o),
          .fu_data_i(fpu_data_mod),
          .fpu_fmt_i(internal_fpu_fmt_i),
          .fpu_rm_i(internal_fpu_rm_i),
          .fpu_frm_i(internal_fpu_frm_i),
          .fpu_prec_i(internal_fpu_prec_i),
          .fpu_trans_id_o(fpu_trans_id_mod),
          .result_o(fpu_result_mod),
          .fpu_valid_o(fpu_valid_mod),
          .fpu_exception_o(internal_fpu_exception_o),
          .fpu_early_valid_o (internal_fpu_early_valid_o) // Ignored for routing, used internally if needed
      );
    end else begin : no_fpu_gen
      assign fpu_result_mod             = '0;
      assign fpu_valid_mod              = '0;
      assign fpu_trans_id_mod           = '0;
      assign internal_fpu_ready_o       = '0;
      assign internal_fpu_exception_o   = '0;
      assign internal_fpu_early_valid_o = '0;
    end

    if (CVA6Cfg.FpPresent) begin
      assign internal_fpu_valid_o = fpu_valid_mod;
      assign internal_result_o    = fpu_result_mod;
      // We do not assign trans_id_o here because we route it directly via the buffer
    end else begin
      assign internal_fpu_valid_o = '0;
      assign internal_result_o    = '0;
    end

    // ---------------------------------------------------------
    // 1-Cycle Output Pipeline Buffer
    // ---------------------------------------------------------
    logic                                   buf_valid;
    logic       [CVA6Cfg.TRANS_ID_BITS-1:0] buf_trans_id;
    logic                                   buf_trans_core;
    logic       [         CVA6Cfg.XLEN-1:0] buf_result;
    exception_t                             buf_exception;

    // Extract core ID immediately from the FPU output
    logic                                   current_trans_core;
    assign current_trans_core = fpu_trans_id_mod[CVA6Cfg.TRANS_ID_BITS];

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (~rst_ni) begin
        buf_valid      <= 1'b0;
        buf_trans_id   <= '0;
        buf_trans_core <= 1'b0;
        buf_result     <= '0;
        buf_exception  <= '0;
      end else begin
        // Shift valid state into the buffer
        buf_valid <= internal_fpu_valid_o;

        // Only update the payload registers when valid
        if (internal_fpu_valid_o) begin
          buf_trans_id   <= fpu_trans_id_mod[CVA6Cfg.TRANS_ID_BITS-1:0];
          buf_trans_core <= current_trans_core;
          buf_result     <= internal_result_o;
          buf_exception  <= internal_fpu_exception_o;
        end
      end
    end

    // ---------------------------------------------------------
    // Output Routing Logic
    // ---------------------------------------------------------
    always_comb begin
      // 1. Default assignments to prevent latches
      fpu_early_valid_o = '0;
      fpu_valid_o       = '0;
      fpu_trans_id_o    = '0;
      result_o          = '0;
      fpu_exception_o   = '0;

      // 2. Ready is combinational through to both cores
      fpu_ready_o[0]    = internal_fpu_ready_o && arb_ready_out[0];
      fpu_ready_o[1]    = internal_fpu_ready_o && arb_ready_out[1];

      // 3. Cycle T Routing: Early Valid
      // Triggered by the internal FPU's actual valid signal
      if (internal_fpu_valid_o) begin
        if (~current_trans_core) fpu_early_valid_o[0] = 1'b1;
        else fpu_early_valid_o[1] = 1'b1;
      end

      // 4. Cycle T+1 Routing: Payload and Valid
      // Triggered by the pipeline buffer
      if (buf_valid) begin
        if (~buf_trans_core) begin
          fpu_valid_o[0]     = 1'b1;
          fpu_trans_id_o[0]  = buf_trans_id;
          result_o[0]        = buf_result;
          fpu_exception_o[0] = buf_exception;
        end else begin
          fpu_valid_o[1]     = 1'b1;
          fpu_trans_id_o[1]  = buf_trans_id;
          result_o[1]        = buf_result;
          fpu_exception_o[1] = buf_exception;
        end
      end
    end
  end
endmodule
