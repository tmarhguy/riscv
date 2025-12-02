// IronCore Branch Predictor - Bimodal (2-bit saturating counters)
// Indexed by PC bits, predicts branch direction

import ironcore_pkg::*;
module ironcore_bp #(
    parameter int BHT_SIZE   = 256,  // Branch History Table entries
    parameter int BHT_ADDR_W = 8     // log2(BHT_SIZE)
) (
    input logic clk_i,
    input logic rst_ni,

    // Prediction interface (IF stage)
    input logic [XLEN-1:0] pc_i,
    input logic [ILEN-1:0] instr_i,
    input logic            instr_valid_i,

    // Update interface (from EX stage)
    input logic            update_en_i,
    input logic [XLEN-1:0] update_pc_i,
    input logic            update_taken_i,

    // Prediction outputs
    output logic            pred_taken_o,
    output logic [XLEN-1:0] pred_target_o
);

  //--------------------------------------------------------------------------
  // Branch History Table (2-bit saturating counters)
  //--------------------------------------------------------------------------
  // States: 00=Strong Not Taken, 01=Weak Not Taken, 10=Weak Taken, 11=Strong Taken
  logic [1:0] bht[BHT_SIZE];

  // Index extraction
  logic [BHT_ADDR_W-1:0] pred_idx;
  logic [BHT_ADDR_W-1:0] update_idx;

  assign pred_idx   = pc_i[BHT_ADDR_W+1:2];  // Skip 2 LSBs (word aligned)
  assign update_idx = update_pc_i[BHT_ADDR_W+1:2];

  //--------------------------------------------------------------------------
  // Branch Detection (check if current instruction is a branch)
  //--------------------------------------------------------------------------
  logic is_branch;
  logic is_jal;
  logic [6:0] opcode;

  assign opcode    = instr_i[6:0];
  assign is_branch = (opcode == OP_BRANCH);
  assign is_jal    = (opcode == OP_JAL);

  //--------------------------------------------------------------------------
  // Target Calculation
  //--------------------------------------------------------------------------
  // B-type immediate extraction
  logic [XLEN-1:0] imm_b;
  assign imm_b = {{19{instr_i[31]}}, instr_i[31], instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};

  // J-type immediate extraction
  logic [XLEN-1:0] imm_j;
  assign imm_j = {
    {11{instr_i[31]}}, instr_i[31], instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0
  };

  //--------------------------------------------------------------------------
  // Prediction Logic
  //--------------------------------------------------------------------------
  logic [1:0] counter_val;
  assign counter_val = bht[pred_idx];

  always_comb begin
    // Default: no prediction
    pred_taken_o  = 1'b0;
    pred_target_o = pc_i + 32'd4;

    if (instr_valid_i) begin
      if (is_jal) begin
        // JAL is always taken
        pred_taken_o  = 1'b1;
        pred_target_o = pc_i + imm_j;
      end else if (is_branch) begin
        // Use 2-bit counter prediction (bit[1] = taken)
        pred_taken_o  = counter_val[1];
        pred_target_o = pred_taken_o ? (pc_i + imm_b) : (pc_i + 32'd4);
      end
    end
  end

  //--------------------------------------------------------------------------
  // Counter Update Logic
  //--------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      // Initialize to weakly not taken (01)
      for (int i = 0; i < BHT_SIZE; i++) begin
        bht[i] <= 2'b01;
      end
    end else if (update_en_i) begin
      // Update 2-bit saturating counter
      if (update_taken_i) begin
        // Branch was taken - increment (saturate at 11)
        if (bht[update_idx] != 2'b11) begin
          bht[update_idx] <= bht[update_idx] + 1'b1;
        end
      end else begin
        // Branch was not taken - decrement (saturate at 00)
        if (bht[update_idx] != 2'b00) begin
          bht[update_idx] <= bht[update_idx] - 1'b1;
        end
      end
    end
  end

endmodule : ironcore_bp
