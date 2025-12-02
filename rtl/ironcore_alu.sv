// IronCore ALU - Arithmetic Logic Unit
// Implements all RV64IM ALU operations

import ironcore_pkg::*;
module ironcore_alu (
    input  ironcore_pkg::alu_op_e            op_i,
    input  logic                  [XLEN-1:0] a_i,
    input  logic                  [XLEN-1:0] b_i,
    output logic                  [XLEN-1:0] result_o
);

  logic [5:0] shamt;      // 6 bits for RV64 (was 5 for RV32)
  logic [4:0] shamt_w;    // 5 bits for word operations
  assign shamt = b_i[5:0];
  assign shamt_w = b_i[4:0];

  // Intermediate results for word operations
  logic [31:0] word_result;
  logic [63:0] word_extended;

  always_comb begin
    case (op_i)
      // 64-bit operations
      ALU_ADD:    result_o = a_i + b_i;
      ALU_SUB:    result_o = a_i - b_i;
      ALU_SLL:    result_o = a_i << shamt;
      ALU_SLT:    result_o = {63'b0, $signed(a_i) < $signed(b_i)};
      ALU_SLTU:   result_o = {63'b0, a_i < b_i};
      ALU_XOR:    result_o = a_i ^ b_i;
      ALU_SRL:    result_o = a_i >> shamt;
      ALU_SRA:    result_o = $signed(a_i) >>> shamt;
      ALU_OR:     result_o = a_i | b_i;
      ALU_AND:    result_o = a_i & b_i;
      ALU_PASS_B: result_o = b_i;  // For LUI
      
      // RV64I word operations (32-bit with sign-extension)
      ALU_ADDW: begin
        word_result = a_i[31:0] + b_i[31:0];
        result_o = {{32{word_result[31]}}, word_result};
      end
      ALU_SUBW: begin
        word_result = a_i[31:0] - b_i[31:0];
        result_o = {{32{word_result[31]}}, word_result};
      end
      ALU_SLLW: begin
        word_result = a_i[31:0] << shamt_w;
        result_o = {{32{word_result[31]}}, word_result};
      end
      ALU_SRLW: begin
        word_result = a_i[31:0] >> shamt_w;
        result_o = {{32{word_result[31]}}, word_result};
      end
      ALU_SRAW: begin
        word_result = $signed(a_i[31:0]) >>> shamt_w;
        result_o = {{32{word_result[31]}}, word_result};
      end
      
      default:    result_o = '0;
    endcase
  end

endmodule : ironcore_alu
