// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright 2024 - PlanV Technologies for additional contribution.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Engineer:       Francesco Conti - f.conti@unibo.it
//
// Additional contributions by:
//                 Markus Wegmann - markus.wegmann@technokrat.ch
//                 Noam Gallmann - gnoam@live.com
//                 Felipe Lisboa Malaquias
//                 Henry Suzukawa
//                 Angela Gonzalez - PlanV Technologies
//
// Description:    This register file is optimized for implementation on
//                 FPGAs. The register file features one distributed RAM block per implemented
//                 sync-write port, each with a parametrized number of async-read ports.
//                 Read-accesses are multiplexed from the relevant block depending on which block
//                 was last written to. For that purpose an additional array of registers is
//                 maintained keeping track of write accesses.
//

module ariane_regfile_fpga #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg       = config_pkg::cva6_cfg_empty,
    parameter int unsigned           DATA_WIDTH    = 32,
    parameter int unsigned           NR_READ_PORTS = 2,
    parameter bit                    ZERO_REG_ZERO = 0
) (
    // clock and reset
    input  logic                                             clk_i,
    input  logic                                             rst_ni,
    // disable clock gates for testing
    input  logic                                             test_en_i,
    // read port
    input  logic [        NR_READ_PORTS-1:0][           4:0] raddr_i,
    output logic [        NR_READ_PORTS-1:0][DATA_WIDTH-1:0] rdata_o,
    // write port
    input  logic [CVA6Cfg.NrCommitPorts-1:0][           4:0] waddr_i,
    input  logic [CVA6Cfg.NrCommitPorts-1:0][DATA_WIDTH-1:0] wdata_i,
    input  logic [CVA6Cfg.NrCommitPorts-1:0]                 we_i
);

  localparam ADDR_WIDTH = 5;
  localparam NUM_WORDS = 2 ** ADDR_WIDTH;
  localparam LOG_NR_WRITE_PORTS = CVA6Cfg.NrCommitPorts == 1 ? 1 : $clog2(CVA6Cfg.NrCommitPorts);

  // Distributed RAM usually supports one write port per block - duplicate for each write port.
  logic [NUM_WORDS-1:0][DATA_WIDTH-1:0] mem[CVA6Cfg.NrCommitPorts];

  logic [CVA6Cfg.NrCommitPorts-1:0][NUM_WORDS-1:0] we_dec;
  logic [NUM_WORDS-1:0][LOG_NR_WRITE_PORTS-1:0] mem_block_sel;
  logic [NUM_WORDS-1:0][LOG_NR_WRITE_PORTS-1:0] mem_block_sel_q;
  logic [CVA6Cfg.NrCommitPorts-1:0][DATA_WIDTH-1:0] wdata_reg;
  logic [NR_READ_PORTS-1:0] read_after_write;

  logic [NR_READ_PORTS-1:0][4:0] raddr_q;
  logic [NR_READ_PORTS-1:0][4:0] raddr;

  // write address decoder (for block selector)
  always_comb begin
    for (int unsigned j = 0; j < CVA6Cfg.NrCommitPorts; j++) begin
      for (int unsigned i = 0; i < NUM_WORDS; i++) begin
        if (waddr_i[j] == i) begin
          we_dec[j][i] = we_i[j];
        end else begin
          we_dec[j][i] = 1'b0;
        end
      end
    end
  end

  // update block selector:
  // signal mem_block_sel records where the current valid value is stored.
  // if multiple ports try to write to the same address simultaneously, the port with the highest
  // index has priority.
  always_comb begin
    mem_block_sel = mem_block_sel_q;
    for (int i = 0; i < NUM_WORDS; i++) begin
      for (int j = 0; j < CVA6Cfg.NrCommitPorts; j++) begin
        if (we_dec[j][i] == 1'b1) begin
          mem_block_sel[i] = LOG_NR_WRITE_PORTS'(j);
        end
      end
    end
  end

  // block selector flops
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      mem_block_sel_q <= '0;
      raddr_q <= '0;
    end else begin
      mem_block_sel_q <= mem_block_sel;
      if (CVA6Cfg.FpgaAlteraEn) raddr_q <= raddr_i;
      else raddr_q <= '0;
    end
  end

  // distributed RAM blocks
  logic [NR_READ_PORTS-1:0][DATA_WIDTH-1:0] mem_read[CVA6Cfg.NrCommitPorts];
  logic [NR_READ_PORTS-1:0][DATA_WIDTH-1:0] mem_read_sync[CVA6Cfg.NrCommitPorts];
  for (genvar j = 0; j < CVA6Cfg.NrCommitPorts; j++) begin : regfile_ram_block
    always_ff @(posedge clk_i) begin
      if (we_i[j] && ~waddr_i[j] != 0) begin
        mem[j][waddr_i[j]] <= wdata_i[j];
        if (CVA6Cfg.FpgaAlteraEn)
          wdata_reg[j] <= wdata_i[j];  // register data written in case is needed to read next cycle
        else wdata_reg[j] <= '0;
      end
      if (CVA6Cfg.FpgaAlteraEn) begin
        for (int k = 0; k < NR_READ_PORTS; k++) begin : block_read
          mem_read_sync[j][k] = mem[j][raddr_i[k]];  // synchronous RAM
          read_after_write[k] <= '0;
          if (waddr_i[j] == raddr_i[k])
            read_after_write[k] <= we_i[j] && ~waddr_i[j] != 0; // Identify if we need to read the content that was written
        end
      end
    end
    for (genvar k = 0; k < NR_READ_PORTS; k++) begin : block_read
      assign mem_read[j][k] = CVA6Cfg.FpgaAlteraEn ? ( read_after_write[k] ? wdata_reg[j]: mem_read_sync[j][k]) : mem[j][raddr_i[k]];
    end
  end
  //with synchronous ram there is the need to adjust which address is used at the output MUX
  assign raddr = CVA6Cfg.FpgaAlteraEn ? raddr_q : raddr_i;

  // output MUX
  logic [NR_READ_PORTS-1:0][LOG_NR_WRITE_PORTS-1:0] block_addr;
  for (genvar k = 0; k < NR_READ_PORTS; k++) begin : regfile_read_port
    // A read issued in the same cycle as a write to the same address must see
    // the written value. The distributed RAM only commits on the next clock
    // edge and the block selector (mem_block_sel_q) is registered, so bypass
    // both: select the bank being written this cycle (highest write-port index
    // wins, matching the mem_block_sel priority) and forward its write data.
    logic [LOG_NR_WRITE_PORTS-1:0] fwd_block;
    logic                          fwd_en;
    always_comb begin
      fwd_en    = 1'b0;
      fwd_block = mem_block_sel[raddr[k]];
      for (int j = 0; j < CVA6Cfg.NrCommitPorts; j++) begin
        if (we_i[j] && (waddr_i[j] == raddr[k]) && (waddr_i[j] != '0)) begin
          fwd_en    = 1'b1;
          fwd_block = LOG_NR_WRITE_PORTS'(j);
        end
      end
    end
    assign block_addr[k] = CVA6Cfg.FpgaAlteraEn ? mem_block_sel[raddr[k]] : fwd_block;
    assign rdata_o[k     ] = (ZERO_REG_ZERO && raddr[k] == '0) ? '0 :
        (!CVA6Cfg.FpgaAlteraEn && fwd_en) ? wdata_i[fwd_block] : mem_read[block_addr[k]][k];
  end

  // random initialization of the memory to suppress assert warnings on Questa.
  // The 32-bit $random() only fills the lower half of a RV64 word, which
  // leaves the upper half at its x-init value; draw twice for RV64.
  initial begin
    for (int i = 0; i < CVA6Cfg.NrCommitPorts; i++) begin
      for (int j = 0; j < NUM_WORDS; j++) begin
        if (!CVA6Cfg.FpgaAlteraEn) begin
          mem[i][j] = $random();  //quartus does not support this random statement on synthesis
          if (DATA_WIDTH == 64) mem[i][j][63:32] = $random();
        end else mem[i][j] = '0;
      end
    end
  end

endmodule
