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
    input logic [1:0][XLEN-1:0] pc_i,
    input logic [1:0][ILEN-1:0] instr_i,
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
    output logic [1:0] pred_taken_o,
    output logic [1:0][XLEN-1:0] pred_target_o,
    output logic [1:0][BHT_ADDR_W-1:0] pred_index_o
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

  // Table contents are initialized once instead of asynchronously reset.
  // This keeps the large predictor arrays inferable by synthesis tools and
  // avoids unsupported nonblocking array assignments in reset loops.
  initial begin
    for (int i = 0; i < BHT_SIZE; i++) begin
      bht[i] = 2'b01;
      btb_valid[i] = 1'b0;
      btb_tag[i] = '0;
      btb_target[i] = '0;
    end
    for (int i = 0; i < RAS_DEPTH; i++) ras[i] = '0;
  end

  localparam int PRED_W = 1 + XLEN + BHT_ADDR_W;
  function automatic logic [PRED_W-1:0] predict(
      input logic [XLEN-1:0] pc,
      input logic [ILEN-1:0] instr
  );
    logic taken;
    logic [XLEN-1:0] target;
    logic [BHT_ADDR_W-1:0] index;
    logic [BHT_ADDR_W-1:0] btb_index;
    logic [XLEN-1:0] imm_b;
    logic [XLEN-1:0] imm_j;
    begin
      index = pc[BHT_ADDR_W+1:2] ^ history;
      taken = 1'b0;
      target = pc + 64'd4;
      imm_b = {{51{instr[31]}}, instr[31], instr[7], instr[30:25],
               instr[11:8], 1'b0};
      imm_j = {{43{instr[31]}}, instr[31], instr[19:12], instr[20],
               instr[30:21], 1'b0};
      btb_index = pc[BHT_ADDR_W+1:2];
      if (instr_valid_i) begin
        case (instr[6:0])
          OP_BRANCH: begin
            taken = bht[index][1];
            target = pc + imm_b;
          end
          OP_JAL: begin
            taken = 1'b1;
            target = pc + imm_j;
          end
          OP_JALR: begin
            if (instr[14:12] == 3'b000) begin
              if ((instr[19:15] == 5'd1 || instr[19:15] == 5'd5) &&
                  instr[11:7] != instr[19:15] && instr[31:20] == 12'b0 &&
                  ras_count != 0) begin
                taken = 1'b1;
                target = ras[int'(ras_count) - 1];
              end else if (btb_valid[btb_index] && btb_tag[btb_index] == pc) begin
                taken = 1'b1;
                target = btb_target[btb_index];
              end
            end
          end
          default: begin end
        endcase
      end
      predict = {taken, target, index};
    end
  endfunction

  logic [PRED_W-1:0] prediction0, prediction1;
  always_comb begin
    prediction0 = predict(pc_i[0], instr_i[0]);
    prediction1 = predict(pc_i[1], instr_i[1]);
    {pred_taken_o[0], pred_target_o[0], pred_index_o[0]} = prediction0;
    {pred_taken_o[1], pred_target_o[1], pred_index_o[1]} = prediction1;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      history <= '0;
      ras_count <= '0;
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
