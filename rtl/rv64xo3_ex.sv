// riscv64xO3 EX Stage - Dual Execute
// Slot A has a full ALU; slot B has a second ALU plus its own branch
// resolve. Singletons (MUL/DIV engine, LSU, CSR) serve one slot per cycle,
// arbitrated in ID, so at most one slot needs them here.

import rv64xo3_pkg::*;
module rv64xo3_ex (
    input logic clk_i,
    input logic rst_ni,

    // Pipeline register inputs (one pair)
    input rv64xo3_pkg::id_ex_reg_t id_ex_a_i,
    input rv64xo3_pkg::id_ex_reg_t id_ex_b_i,

    // Forwarding inputs (per slot)
    input rv64xo3_pkg::fwd_sel_e            fwd_a_sel_a_i,
    input rv64xo3_pkg::fwd_sel_e            fwd_b_sel_a_i,
    input rv64xo3_pkg::fwd_sel_e            fwd_a_sel_b_i,
    input rv64xo3_pkg::fwd_sel_e            fwd_b_sel_b_i,
    input logic                   [XLEN-1:0] fwd_ex_mem_a_data_i,
    input logic                   [XLEN-1:0] fwd_ex_mem_b_data_i,
    input logic                   [XLEN-1:0] fwd_mem_wb_a_data_i,
    input logic                   [XLEN-1:0] fwd_mem_wb_b_data_i,
    // DIV accept pulse from top (single cycle per DIV; MUL needs none)
    input logic                             div_start_i,

    // Outputs (per slot, plus shared singletons)
    output logic [XLEN-1:0] alu_result_a_o,
    output logic [XLEN-1:0] alu_result_b_o,
    output logic            branch_taken_a_o,
    output logic            branch_taken_b_o,
    output logic [XLEN-1:0] branch_target_a_o,
    output logic [XLEN-1:0] branch_target_b_o,
    output logic [XLEN-1:0] mul_result_o,
    output logic [XLEN-1:0] div_result_o,
    output logic            div_valid_o,
    output logic            div_busy_o
);

  //--------------------------------------------------------------------------
  // Forwarding Muxes (per slot)
  //--------------------------------------------------------------------------
  logic [XLEN-1:0] rs1_fwd_a;
  logic [XLEN-1:0] rs2_fwd_a;
  logic [XLEN-1:0] rs1_fwd_b;
  logic [XLEN-1:0] rs2_fwd_b;

  always_comb begin
    case (fwd_a_sel_a_i)
      FWD_EX_A: rs1_fwd_a = fwd_ex_mem_a_data_i;
      FWD_EX_B: rs1_fwd_a = fwd_ex_mem_b_data_i;
      FWD_WB_A: rs1_fwd_a = fwd_mem_wb_a_data_i;
      FWD_WB_B: rs1_fwd_a = fwd_mem_wb_b_data_i;
      default:  rs1_fwd_a = id_ex_a_i.rs1_data;
    endcase

    case (fwd_b_sel_a_i)
      FWD_EX_A: rs2_fwd_a = fwd_ex_mem_a_data_i;
      FWD_EX_B: rs2_fwd_a = fwd_ex_mem_b_data_i;
      FWD_WB_A: rs2_fwd_a = fwd_mem_wb_a_data_i;
      FWD_WB_B: rs2_fwd_a = fwd_mem_wb_b_data_i;
      default:  rs2_fwd_a = id_ex_a_i.rs2_data;
    endcase

    case (fwd_a_sel_b_i)
      FWD_EX_A: rs1_fwd_b = fwd_ex_mem_a_data_i;
      FWD_EX_B: rs1_fwd_b = fwd_ex_mem_b_data_i;
      FWD_WB_A: rs1_fwd_b = fwd_mem_wb_a_data_i;
      FWD_WB_B: rs1_fwd_b = fwd_mem_wb_b_data_i;
      default:  rs1_fwd_b = id_ex_b_i.rs1_data;
    endcase

    case (fwd_b_sel_b_i)
      FWD_EX_A: rs2_fwd_b = fwd_ex_mem_a_data_i;
      FWD_EX_B: rs2_fwd_b = fwd_ex_mem_b_data_i;
      FWD_WB_A: rs2_fwd_b = fwd_mem_wb_a_data_i;
      FWD_WB_B: rs2_fwd_b = fwd_mem_wb_b_data_i;
      default:  rs2_fwd_b = id_ex_b_i.rs2_data;
    endcase
  end

  //--------------------------------------------------------------------------
  // ALU Operand Selection (per slot)
  //--------------------------------------------------------------------------
  logic [XLEN-1:0] alu_a_a;
  logic [XLEN-1:0] alu_b_a;
  logic [XLEN-1:0] alu_a_b;
  logic [XLEN-1:0] alu_b_b;

  // For AUIPC/JAL/JALR, operand A is PC; for others, it's rs1
  assign alu_a_a = (id_ex_a_i.is_jal || id_ex_a_i.is_jalr || id_ex_a_i.is_auipc) ? id_ex_a_i.pc :
                   rs1_fwd_a;
  assign alu_b_a = id_ex_a_i.alu_src ? id_ex_a_i.imm : rs2_fwd_a;

  assign alu_a_b = (id_ex_b_i.is_jal || id_ex_b_i.is_jalr || id_ex_b_i.is_auipc) ? id_ex_b_i.pc :
                   rs1_fwd_b;
  assign alu_b_b = id_ex_b_i.alu_src ? id_ex_b_i.imm : rs2_fwd_b;

  //--------------------------------------------------------------------------
  // ALUs (slot A primary, slot B second)
  //--------------------------------------------------------------------------
  logic [XLEN-1:0] alu_out_a;
  logic [XLEN-1:0] alu_out_b;

  rv64xo3_alu u_alu_a (
      .op_i    (id_ex_a_i.alu_op),
      .a_i     (alu_a_a),
      .b_i     (alu_b_a),
      .result_o(alu_out_a)
  );

  rv64xo3_alu u_alu_b (
      .op_i    (id_ex_b_i.alu_op),
      .a_i     (alu_a_b),
      .b_i     (alu_b_b),
      .result_o(alu_out_b)
  );

  // For JAL/JALR, result is PC+4 (link address)
  assign alu_result_a_o = (id_ex_a_i.is_jal || id_ex_a_i.is_jalr) ?
                          id_ex_a_i.pc + 64'd4 : alu_out_a;
  assign alu_result_b_o = (id_ex_b_i.is_jal || id_ex_b_i.is_jalr) ?
                          id_ex_b_i.pc + 64'd4 : alu_out_b;

  //--------------------------------------------------------------------------
  // Branch Comparators (per slot)
  //--------------------------------------------------------------------------
  logic branch_cond_a;
  logic branch_cond_b;

  always_comb begin
    case (id_ex_a_i.branch_op)
      BR_EQ:   branch_cond_a = (rs1_fwd_a == rs2_fwd_a);
      BR_NE:   branch_cond_a = (rs1_fwd_a != rs2_fwd_a);
      BR_LT:   branch_cond_a = ($signed(rs1_fwd_a) < $signed(rs2_fwd_a));
      BR_GE:   branch_cond_a = ($signed(rs1_fwd_a) >= $signed(rs2_fwd_a));
      BR_LTU:  branch_cond_a = (rs1_fwd_a < rs2_fwd_a);
      BR_GEU:  branch_cond_a = (rs1_fwd_a >= rs2_fwd_a);
      default: branch_cond_a = 1'b0;
    endcase

    case (id_ex_b_i.branch_op)
      BR_EQ:   branch_cond_b = (rs1_fwd_b == rs2_fwd_b);
      BR_NE:   branch_cond_b = (rs1_fwd_b != rs2_fwd_b);
      BR_LT:   branch_cond_b = ($signed(rs1_fwd_b) < $signed(rs2_fwd_b));
      BR_GE:   branch_cond_b = ($signed(rs1_fwd_b) >= $signed(rs2_fwd_b));
      BR_LTU:  branch_cond_b = (rs1_fwd_b < rs2_fwd_b);
      BR_GEU:  branch_cond_b = (rs1_fwd_b >= rs2_fwd_b);
      default: branch_cond_b = 1'b0;
    endcase
  end

  //--------------------------------------------------------------------------
  // Branch Target Calculation (per slot)
  //--------------------------------------------------------------------------
  logic [XLEN-1:0] branch_target_calc_a;
  logic [XLEN-1:0] branch_target_calc_b;

  always_comb begin
    if (id_ex_a_i.is_jalr) begin
      // JALR: target = (rs1 + imm) & ~1
      branch_target_calc_a = (rs1_fwd_a + id_ex_a_i.imm) & ~64'h1;
    end else begin
      // JAL/Branch: target = PC + imm
      branch_target_calc_a = id_ex_a_i.pc + id_ex_a_i.imm;
    end

    if (id_ex_b_i.is_jalr) begin
      branch_target_calc_b = (rs1_fwd_b + id_ex_b_i.imm) & ~64'h1;
    end else begin
      branch_target_calc_b = id_ex_b_i.pc + id_ex_b_i.imm;
    end
  end

  assign branch_taken_a_o  = id_ex_a_i.valid &&
                             (id_ex_a_i.is_jal || id_ex_a_i.is_jalr ||
                             (id_ex_a_i.is_branch && branch_cond_a));
  assign branch_target_a_o = branch_target_calc_a;
  assign branch_taken_b_o  = id_ex_b_i.valid &&
                             (id_ex_b_i.is_jal || id_ex_b_i.is_jalr ||
                             (id_ex_b_i.is_branch && branch_cond_b));
  assign branch_target_b_o = branch_target_calc_b;

  //--------------------------------------------------------------------------
  // Shared Multiply/Divide Unit (singleton: at most one slot needs it;
  // dispatch serializes anything else)
  //--------------------------------------------------------------------------
  logic md_use_a;
  assign md_use_a = id_ex_a_i.valid && id_ex_a_i.is_muldiv;

  rv64xo3_muldiv u_muldiv (
      .clk_i       (clk_i),
      .rst_ni      (rst_ni),
      .start_i     (div_start_i),
      .op_i        (md_use_a ? id_ex_a_i.muldiv_op : id_ex_b_i.muldiv_op),
      .a_i         (md_use_a ? rs1_fwd_a : rs1_fwd_b),
      .b_i         (md_use_a ? rs2_fwd_a : rs2_fwd_b),
      .mul_result_o(mul_result_o),
      .div_result_o(div_result_o),
      .div_valid_o (div_valid_o),
      .div_busy_o  (div_busy_o)
  );

endmodule : rv64xo3_ex
