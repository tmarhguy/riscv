// Two-slot gshare predictor with tagged indirect-target cache and resolved RAS.
// History/table updates occur only when EX advances, never on held instructions.
import rv64xo3_pkg::*;
module rv64xo3_bp #(
    parameter int BHT_SIZE = 256,
    parameter int BHT_ADDR_W = 8,
    parameter int RAS_DEPTH = 16
) (
    input logic clk_i,
    input logic rst_ni,
    input logic [XLEN-1:0] pc_i [2],
    input logic [ILEN-1:0] instr_i [2],
    input logic instr_valid_i,
    input logic update_en_i,
    input logic [XLEN-1:0] update_pc_i,
    input logic [BHT_ADDR_W-1:0] update_index_i,
    input logic update_branch_i,
    input logic update_taken_i,
    input logic [XLEN-1:0] update_target_i,
    input logic update_call_i,
    input logic update_return_i,
    input logic [XLEN-1:0] update_link_i,
    output logic pred_taken_o [2],
    output logic [XLEN-1:0] pred_target_o [2],
    output logic [BHT_ADDR_W-1:0] pred_index_o [2]
);
  logic [1:0] bht [BHT_SIZE];
  logic [BHT_ADDR_W-1:0] history;
  logic btb_valid [BHT_SIZE];
  logic [XLEN-1:0] btb_tag [BHT_SIZE];
  logic [XLEN-1:0] btb_target [BHT_SIZE];
  logic [XLEN-1:0] ras [RAS_DEPTH];
  logic [$clog2(RAS_DEPTH+1)-1:0] ras_count;
  logic [BHT_ADDR_W-1:0] target_index;
  assign target_index = update_pc_i[BHT_ADDR_W+1:2];

  always_comb begin
    for (int slot = 0; slot < 2; slot++) begin
      pred_index_o[slot] = pc_i[slot][BHT_ADDR_W+1:2] ^ history;
      pred_taken_o[slot] = 1'b0;
      pred_target_o[slot] = pc_i[slot] + 64'd4;
      if (instr_valid_i) begin
        case (instr_i[slot][6:0])
          OP_BRANCH: begin
            pred_taken_o[slot] = bht[pred_index_o[slot]][1];
            pred_target_o[slot] = pc_i[slot] +
              {{51{instr_i[slot][31]}}, instr_i[slot][31], instr_i[slot][7],
                instr_i[slot][30:25], instr_i[slot][11:8], 1'b0};
          end
          OP_JAL: begin
            pred_taken_o[slot] = 1'b1;
            pred_target_o[slot] = pc_i[slot] +
              {{43{instr_i[slot][31]}}, instr_i[slot][31], instr_i[slot][19:12],
                instr_i[slot][20], instr_i[slot][30:21], 1'b0};
          end
          OP_JALR: begin
            if (instr_i[slot][14:12] == 3'b000) begin
              if ((instr_i[slot][19:15] == 5'd1 || instr_i[slot][19:15] == 5'd5) &&
                  instr_i[slot][11:7] != instr_i[slot][19:15] &&
                  instr_i[slot][31:20] == 12'b0 && ras_count != 0) begin
                pred_taken_o[slot] = 1'b1;
                pred_target_o[slot] = ras[int'(ras_count) - 1];
              end else if (btb_valid[pc_i[slot][BHT_ADDR_W+1:2]] &&
                           btb_tag[pc_i[slot][BHT_ADDR_W+1:2]] == pc_i[slot]) begin
                pred_taken_o[slot] = 1'b1;
                pred_target_o[slot] = btb_target[pc_i[slot][BHT_ADDR_W+1:2]];
              end
            end
          end
          default: begin end
        endcase
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      history <= '0;
      ras_count <= '0;
      for (int i = 0; i < BHT_SIZE; i++) begin
        bht[i] <= 2'b01;
        btb_valid[i] <= 1'b0;
        btb_tag[i] <= '0;
        btb_target[i] <= '0;
      end
      for (int i = 0; i < RAS_DEPTH; i++) ras[i] <= '0;
    end else if (update_en_i) begin
      if (update_branch_i) begin
        history <= {history[BHT_ADDR_W-2:0], update_taken_i};
        if (update_taken_i && bht[update_index_i] != 2'b11)
          bht[update_index_i] <= bht[update_index_i] + 1'b1;
        else if (!update_taken_i && bht[update_index_i] != 2'b00)
          bht[update_index_i] <= bht[update_index_i] - 1'b1;
      end
      if (update_taken_i) begin
        btb_valid[target_index] <= 1'b1;
        btb_tag[target_index] <= update_pc_i;
        btb_target[target_index] <= update_target_i;
      end
      if (update_return_i && update_call_i && ras_count != 0) begin
        ras[int'(ras_count) - 1] <= update_link_i;
      end else if (update_call_i) begin
        if (int'(ras_count) < RAS_DEPTH) begin
          ras[int'(ras_count)] <= update_link_i;
          ras_count <= ras_count + 1'b1;
        end else begin
          for (int i = 0; i < RAS_DEPTH-1; i++) ras[i] <= ras[i+1];
          ras[RAS_DEPTH-1] <= update_link_i;
        end
      end else if (update_return_i && ras_count != 0) begin
        ras_count <= ras_count - 1'b1;
      end
    end
  end
endmodule : rv64xo3_bp
