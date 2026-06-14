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

  // fpu payload state
  typedef enum logic [2:0] {
    COMPLETED,  // 2'b00 - Transaction finished or killed (won't trigger replay)
    VALID,      // 2'b01 - New transaction ready to be issued to FPU
    ISSUED,     // 2'b11 - Transaction active in FPU
    INVALID
  } payload_state_t;

  // fpu payload for gigant buffers
  typedef struct packed {
    logic [CVA6Cfg.NrIssuePorts-1:0] fpu_valid_i;
    logic [1:0]                      fpu_fmt_i;
    logic [2:0]                      fpu_rm_i;
    logic [2:0]                      fpu_frm_i;
    logic [6:0]                      fpu_prec_i;
    fu_data_sf_t                     fpu_data_mod;
    payload_state_t                  state;
  } fpu_payload;

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
        fpu_data = '0;
        if (internal_fpu_valid_i[0]) begin
          fpu_data = internal_fu_data_i[0];
        end else if (CVA6Cfg.SuperscalarEn && internal_fpu_valid_i[1]) begin
          fpu_data = internal_fu_data_i[1];
        end
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

  end else begin : gen_multicore_shared_fpu
    // Buffer needs 2^(TRANS_ID_BITS+1) entries for 4-bit transaction ID
    fpu_payload [(2**(CVA6Cfg.TRANS_ID_BITS+1))-1:0] payload_buffer = '0;


    // ---------------------------------------------------------
    // ID Masks and Input Preparation
    // ---------------------------------------------------------
    localparam int BUFFER_SIZE = 1 << (CVA6Cfg.TRANS_ID_BITS + 1);
    localparam int ENTRIES_PER_CORE = 1 << CVA6Cfg.TRANS_ID_BITS;
    localparam int CORE_1_BASE_INDEX = ENTRIES_PER_CORE;

    localparam logic [CVA6Cfg.TRANS_ID_BITS:0] ID_MASK_CORE_0 = '0;
    localparam logic [CVA6Cfg.TRANS_ID_BITS:0] ID_MASK_CORE_1 = (1'b1 << CVA6Cfg.TRANS_ID_BITS);

    fu_data_sf_t               fpu_data_mod;
    logic        [NrHarts-1:0] valid_inputs;

    always_comb begin
      valid_inputs[0] = fpu_valid_i[0][0];
      valid_inputs[1] = fpu_valid_i[1][0];
    end

    // ---------------------------------------------------------
    // Single-Tier Round-Robin Arbiter
    // ---------------------------------------------------------
    logic [        BUFFER_SIZE-1:0] req_valid;
    logic [CVA6Cfg.TRANS_ID_BITS:0] rr_pointer;
    logic                           replay_valid;
    logic [CVA6Cfg.TRANS_ID_BITS:0] replay_index;

    // 1. Map all VALID states to request vector
    always_comb begin
      for (int i = 0; i < BUFFER_SIZE; i++) begin
        req_valid[i] = (payload_buffer[i].state == VALID);
      end
    end

    // 2. Circular priority search
    always_comb begin
      replay_valid = 1'b0;
      replay_index = '0;

      for (int i = 0; i < BUFFER_SIZE; i++) begin
        int idx = (rr_pointer + i) % BUFFER_SIZE;
        if (req_valid[idx]) begin
          replay_valid = 1'b1;
          replay_index = idx[CVA6Cfg.TRANS_ID_BITS:0];
          break;
        end
      end
    end

    // ---------------------------------------------------------
    // Arbiter Output Logic: Forward Selected Transaction to FPU
    // ---------------------------------------------------------
    always_comb begin
      // Default outputs
      internal_flush_i     = 1'b0;
      internal_fpu_valid_i = '0;
      internal_fpu_fmt_i   = '0;
      internal_fpu_rm_i    = '0;
      internal_fpu_frm_i   = '0;
      internal_fpu_prec_i  = '0;
      fpu_data_mod         = '0;

      // If two-tier arbiter selected a transaction, forward it to FPU
      if (replay_valid) begin
        internal_fpu_valid_i = payload_buffer[replay_index].fpu_valid_i;
        fpu_data_mod         = payload_buffer[replay_index].fpu_data_mod;
        internal_fpu_fmt_i   = payload_buffer[replay_index].fpu_fmt_i;
        internal_fpu_rm_i    = payload_buffer[replay_index].fpu_rm_i;
        internal_fpu_frm_i   = payload_buffer[replay_index].fpu_frm_i;
        internal_fpu_prec_i  = payload_buffer[replay_index].fpu_prec_i;
      end
    end


    // ---------------------------------------------------------
    // Flush Handling State Machine
    // ---------------------------------------------------------
    logic flush_detected;
    logic flushing_core;  // Which core initiated the flush (0 or 1)

    always_comb begin
      flush_detected = flush_i[0] | flush_i[1];
      flushing_core  = flush_i[1];  // 0 if Core 0 flushes, 1 if Core 1 flushes
    end

    // ---------------------------------------------------------
    // FLUSH COLLISION AVOIDANCE MASKS
    // ---------------------------------------------------------
    logic masked_valid_in_0;
    logic masked_valid_in_1;
    logic masked_replay_valid;

    always_comb begin
      // PREVENT INTRA-CORE COLLISION: Do not accept a new instruction if that core is flushing
      masked_valid_in_0   = valid_inputs[0] & ~flush_i[0];
      masked_valid_in_1   = valid_inputs[1] & ~flush_i[1];

      // A global flush kills the shared FPU pipeline. Do not issue to it this cycle.
      masked_replay_valid = replay_valid & ~flush_detected;

    end


    // ---------------------------------------------------------
    // Sequential Logic: Buffer Updates, Issue, Replay, Flush
    // ---------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (~rst_ni) begin
        payload_buffer <= '0;
        rr_pointer     <= '0;
      end else begin

        // ==================================================================
        // FLUSH HANDLING: Independent Core Filtering (No Victimization)
        // ==================================================================
        if (flush_detected) begin
          // If Core 0 flushes, delete ALL of Core 0's pending transactions.
          // Core 1 is completely untouched.
          if (flush_i[0]) begin
            for (int i = 0; i < ENTRIES_PER_CORE; i++) begin
              if (payload_buffer[i].state != COMPLETED) begin
                payload_buffer[i].state <= INVALID;
              end
            end
          end

          // If Core 1 flushes, delete ALL of Core 1's pending transactions.
          // Core 0 is completely untouched.
          if (flush_i[1]) begin
            for (int i = CORE_1_BASE_INDEX; i < BUFFER_SIZE; i++) begin
              if (payload_buffer[i].state != COMPLETED) begin
                payload_buffer[i].state <= INVALID;
              end
            end
          end
        end

        // ==================================================================
        // COMPLETION HANDLING: Mark buffer entry as COMPLETED
        // ==================================================================
        if (fpu_valid_mod && payload_buffer[fpu_trans_id_mod].state == ISSUED) begin
          payload_buffer[fpu_trans_id_mod].state <= COMPLETED;
        end

        // ==================================================================
        // ISSUE HANDLING: Write new transaction to buffer when handshake completes
        // ==================================================================
        // Write to buffer only when valid handshake occurs (cores can always write to their buffer entries)
        if (masked_valid_in_0) begin
          // Core 0 issued a transaction - store with Core ID bit
          payload_buffer[ID_MASK_CORE_0|fu_data_i[0].trans_id].fpu_valid_i <= fpu_valid_i[0];
          payload_buffer[ID_MASK_CORE_0|fu_data_i[0].trans_id].fpu_fmt_i <= fpu_fmt_i[0];
          payload_buffer[ID_MASK_CORE_0|fu_data_i[0].trans_id].fpu_rm_i <= fpu_rm_i[0];
          payload_buffer[ID_MASK_CORE_0|fu_data_i[0].trans_id].fpu_frm_i <= fpu_frm_i[0];
          payload_buffer[ID_MASK_CORE_0|fu_data_i[0].trans_id].fpu_prec_i <= fpu_prec_i[0];
          payload_buffer[ID_MASK_CORE_0|fu_data_i[0].trans_id].fpu_data_mod.fu <= fu_data_i[0].fu;
          payload_buffer[ID_MASK_CORE_0 | fu_data_i[0].trans_id].fpu_data_mod.operation <= fu_data_i[0].operation;
          payload_buffer[ID_MASK_CORE_0 | fu_data_i[0].trans_id].fpu_data_mod.operand_a <= fu_data_i[0].operand_a;
          payload_buffer[ID_MASK_CORE_0 | fu_data_i[0].trans_id].fpu_data_mod.operand_b <= fu_data_i[0].operand_b;
          payload_buffer[ID_MASK_CORE_0|fu_data_i[0].trans_id].fpu_data_mod.imm <= fu_data_i[0].imm;
          payload_buffer[ID_MASK_CORE_0 | fu_data_i[0].trans_id].fpu_data_mod.trans_id  <= ID_MASK_CORE_0 | fu_data_i[0].trans_id;
          payload_buffer[ID_MASK_CORE_0|fu_data_i[0].trans_id].state <= VALID;
        end

        if (masked_valid_in_1) begin
          // Core 1 issued a transaction - store with Core ID bit
          payload_buffer[ID_MASK_CORE_1|fu_data_i[1].trans_id].fpu_valid_i <= fpu_valid_i[1];
          payload_buffer[ID_MASK_CORE_1|fu_data_i[1].trans_id].fpu_fmt_i <= fpu_fmt_i[1];
          payload_buffer[ID_MASK_CORE_1|fu_data_i[1].trans_id].fpu_rm_i <= fpu_rm_i[1];
          payload_buffer[ID_MASK_CORE_1|fu_data_i[1].trans_id].fpu_frm_i <= fpu_frm_i[1];
          payload_buffer[ID_MASK_CORE_1|fu_data_i[1].trans_id].fpu_prec_i <= fpu_prec_i[1];
          payload_buffer[ID_MASK_CORE_1|fu_data_i[1].trans_id].fpu_data_mod.fu <= fu_data_i[1].fu;
          payload_buffer[ID_MASK_CORE_1 | fu_data_i[1].trans_id].fpu_data_mod.operation <= fu_data_i[1].operation;
          payload_buffer[ID_MASK_CORE_1 | fu_data_i[1].trans_id].fpu_data_mod.operand_a <= fu_data_i[1].operand_a;
          payload_buffer[ID_MASK_CORE_1 | fu_data_i[1].trans_id].fpu_data_mod.operand_b <= fu_data_i[1].operand_b;
          payload_buffer[ID_MASK_CORE_1|fu_data_i[1].trans_id].fpu_data_mod.imm <= fu_data_i[1].imm;
          payload_buffer[ID_MASK_CORE_1 | fu_data_i[1].trans_id].fpu_data_mod.trans_id  <= ID_MASK_CORE_1 | fu_data_i[1].trans_id;
          payload_buffer[ID_MASK_CORE_1|fu_data_i[1].trans_id].state <= VALID;
        end

        // ==================================================================
        // ARBITRATION: Grant transaction to FPU (VALID -> ISSUED)
        // ==================================================================
        // When arbiter grants a transaction and FPU accepts it
        if (masked_replay_valid && internal_fpu_ready_o) begin
          payload_buffer[replay_index].state <= ISSUED;
          rr_pointer <= (replay_index + 1'b1) % BUFFER_SIZE;
        end

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
    // 1-Cycle Output Pipeline Buffer (FIXED FOR GHOST WRITES)
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
        if (internal_fpu_valid_o &&
            ~flush_i[current_trans_core] &&
            (payload_buffer[fpu_trans_id_mod].state == ISSUED)) begin
          buf_valid      <= 1'b1;
          buf_trans_id   <= fpu_trans_id_mod[CVA6Cfg.TRANS_ID_BITS-1:0];
          buf_trans_core <= current_trans_core;
          buf_result     <= internal_result_o;
          buf_exception  <= internal_fpu_exception_o;
        end else begin
          buf_valid <= 1'b0;
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

      // 2. Ready is combinational through to both cores (cores can always write to buffer)
      fpu_ready_o[0]    = internal_fpu_ready_o;
      fpu_ready_o[1]    = internal_fpu_ready_o;

      // 3. Cycle T Routing: Early Valid
      // Triggered by the internal FPU's actual valid signal
      if (internal_fpu_valid_o && (payload_buffer[fpu_trans_id_mod].state == ISSUED)) begin
        if (~current_trans_core) fpu_early_valid_o[0] = 1'b1;
        else fpu_early_valid_o[1] = 1'b1;
      end
      // 4. Cycle T+1 Routing: Payload and Valid
      // Triggered by the pipeline buffer
      if (buf_valid) begin
        if (~buf_trans_core) begin
          fpu_valid_o[0]     = 1'b1 & ~flush_i[0];
          fpu_trans_id_o[0]  = buf_trans_id;
          result_o[0]        = buf_result;
          fpu_exception_o[0] = buf_exception;
        end else begin
          fpu_valid_o[1]     = 1'b1 & ~flush_i[1];
          fpu_trans_id_o[1]  = buf_trans_id;
          result_o[1]        = buf_result;
          fpu_exception_o[1] = buf_exception;
        end
      end
    end
  end
endmodule
