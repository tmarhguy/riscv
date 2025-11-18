// IronCore EX Stage - Execute
// Contains ALU, branch comparison, and MulDiv unit

import ironcore_pkg::*;
module ironcore_ex (
    input logic clk_i,
    input logic rst_ni,

    // Pipeline register input
    input ironcore_pkg::id_ex_reg_t id_ex_reg_i,

    // Forwarding inputs
    input ironcore_pkg::fwd_sel_e            fwd_a_sel_i,
    input ironcore_pkg::fwd_sel_e            fwd_b_sel_i,
    input logic                   [XLEN-1:0] fwd_ex_mem_data_i,
    input logic                   [XLEN-1:0] fwd_mem_wb_data_i,

    // Outputs
    output logic [XLEN-1:0] alu_result_o,
    output logic            branch_taken_o,
    output logic [XLEN-1:0] branch_target_o,
    output logic            muldiv_busy_o,
    output logic [XLEN-1:0] muldiv_result_o,
    output logic            muldiv_valid_o
);

  //--------------------------------------------------------------------------
  // Forwarding Muxes
  //--------------------------------------------------------------------------
  logic [XLEN-1:0] rs1_fwd;
  logic [XLEN-1:0] rs2_fwd;

  always_comb begin
    case (fwd_a_sel_i)
      FWD_EX_MEM: rs1_fwd = fwd_ex_mem_data_i;
      FWD_MEM_WB: rs1_fwd = fwd_mem_wb_data_i;
      default:    rs1_fwd = id_ex_reg_i.rs1_data;
    endcase

    case (fwd_b_sel_i)
      FWD_EX_MEM: rs2_fwd = fwd_ex_mem_data_i;
      FWD_MEM_WB: rs2_fwd = fwd_mem_wb_data_i;
      default:    rs2_fwd = id_ex_reg_i.rs2_data;
    endcase
  end

  //--------------------------------------------------------------------------
  // ALU Operand Selection
  //--------------------------------------------------------------------------
  logic [XLEN-1:0] alu_a;
  logic [XLEN-1:0] alu_b;

  // For AUIPC/JAL/JALR, operand A is PC; for others, it's rs1
  assign alu_a = (id_ex_reg_i.is_jal || id_ex_reg_i.is_jalr || id_ex_reg_i.is_auipc) ? id_ex_reg_i.pc :
                 rs1_fwd;

  assign alu_b = id_ex_reg_i.alu_src ? id_ex_reg_i.imm : rs2_fwd;

  //--------------------------------------------------------------------------
  // ALU
  //--------------------------------------------------------------------------
  logic [XLEN-1:0] alu_out;

  ironcore_alu u_alu (
      .op_i    (id_ex_reg_i.alu_op),
      .a_i     (alu_a),
      .b_i     (alu_b),
      .result_o(alu_out)
  );

  // For JAL/JALR, result is PC+4 (link address)
  assign alu_result_o = (id_ex_reg_i.is_jal || id_ex_reg_i.is_jalr) ?
                        id_ex_reg_i.pc + 64'd4 : alu_out;

  //--------------------------------------------------------------------------
  // Branch Comparator
  //--------------------------------------------------------------------------
  logic branch_cond;

  always_comb begin
    case (id_ex_reg_i.branch_op)
      BR_EQ:   branch_cond = (rs1_fwd == rs2_fwd);
      BR_NE:   branch_cond = (rs1_fwd != rs2_fwd);
      BR_LT:   branch_cond = ($signed(rs1_fwd) < $signed(rs2_fwd));
      BR_GE:   branch_cond = ($signed(rs1_fwd) >= $signed(rs2_fwd));
      BR_LTU:  branch_cond = (rs1_fwd < rs2_fwd);
      BR_GEU:  branch_cond = (rs1_fwd >= rs2_fwd);
      default: branch_cond = 1'b0;
    endcase
  end

  //--------------------------------------------------------------------------
  // Branch Target Calculation
  //--------------------------------------------------------------------------
  logic [XLEN-1:0] branch_target_calc;

  always_comb begin
    if (id_ex_reg_i.is_jalr) begin
      // JALR: target = (rs1 + imm) & ~1
      branch_target_calc = (rs1_fwd + id_ex_reg_i.imm) & ~64'h1;
    end else begin
      // JAL/Branch: target = PC + imm
      branch_target_calc = id_ex_reg_i.pc + id_ex_reg_i.imm;
    end
  end

  assign branch_taken_o  = id_ex_reg_i.valid &&
                           (id_ex_reg_i.is_jal || id_ex_reg_i.is_jalr ||
                           (id_ex_reg_i.is_branch && branch_cond));
  assign branch_target_o = branch_target_calc;

  //--------------------------------------------------------------------------
  // Multiply/Divide Unit
  //--------------------------------------------------------------------------
  ironcore_muldiv u_muldiv (
      .clk_i   (clk_i),
      .rst_ni  (rst_ni),
      .start_i (id_ex_reg_i.valid && id_ex_reg_i.is_muldiv),
      .op_i    (id_ex_reg_i.muldiv_op),
      .a_i     (rs1_fwd),
      .b_i     (rs2_fwd),
      .result_o(muldiv_result_o),
      .valid_o (muldiv_valid_o),
      .busy_o  (muldiv_busy_o)
  );

endmodule : ironcore_ex
