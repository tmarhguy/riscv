// riscv64xO3 ID Stage - Instruction Decode and Register File
// Contains the 32xXLEN register file with x0 hardwired to zero.
// 2-wide issue: 4 read ports (2 per slot) + 2 write ports (slot B younger
// wins ties so program order holds when both slots write one register;
// that case is serialized in dispatch anyway).

import rv64xo3_pkg::*;
module rv64xo3_id (
    input logic clk_i,
    input logic rst_ni,

    // Pipeline register inputs (one pair)
    input rv64xo3_pkg::if_id_reg_t if_id_a_i,
    input rv64xo3_pkg::if_id_reg_t if_id_b_i,

    // Writeback interfaces (slot A older, slot B younger)
    input logic [REG_ADDR_W-1:0] wb_a_addr_i,
    input logic [      XLEN-1:0] wb_a_data_i,
    input logic                  wb_a_wen_i,
    input logic [REG_ADDR_W-1:0] wb_b_addr_i,
    input logic [      XLEN-1:0] wb_b_data_i,
    input logic                  wb_b_wen_i,

    // Register read outputs (per slot)
    output logic [XLEN-1:0] rs1_a_data_o,
    output logic [XLEN-1:0] rs2_a_data_o,
    output logic [XLEN-1:0] rs1_b_data_o,
    output logic [XLEN-1:0] rs2_b_data_o
);

  //--------------------------------------------------------------------------
  // Register File (32 x XLEN, x0 hardwired to 0)
  //--------------------------------------------------------------------------
  logic [XLEN-1:0] regfile[NUM_REGS];

  // Extract register addresses from instructions
  logic [REG_ADDR_W-1:0] rs1_a_addr;
  logic [REG_ADDR_W-1:0] rs2_a_addr;
  logic [REG_ADDR_W-1:0] rs1_b_addr;
  logic [REG_ADDR_W-1:0] rs2_b_addr;

  assign rs1_a_addr = if_id_a_i.instr[19:15];
  assign rs2_a_addr = if_id_a_i.instr[24:20];
  assign rs1_b_addr = if_id_b_i.instr[19:15];
  assign rs2_b_addr = if_id_b_i.instr[24:20];

  //--------------------------------------------------------------------------
  // Register File Write (WB Stage writes here; B younger wins ties)
  //--------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      // Reset all registers to 0
      for (int i = 0; i < NUM_REGS; i++) begin
        regfile[i] <= '0;
      end
    end else begin
      if (wb_a_wen_i && wb_a_addr_i != 5'd0 &&
          !(wb_b_wen_i && wb_b_addr_i == wb_a_addr_i)) begin
        regfile[wb_a_addr_i] <= wb_a_data_i;
      end
      if (wb_b_wen_i && wb_b_addr_i != 5'd0) begin
        regfile[wb_b_addr_i] <= wb_b_data_i;
      end
    end
  end

  //--------------------------------------------------------------------------
  // Register File Read (combinational with write-through from both ports,
  // younger first)
  //--------------------------------------------------------------------------
  function automatic logic [XLEN-1:0] read_port(
    input logic [REG_ADDR_W-1:0] raddr
  );
    if (raddr == 5'd0) begin
      return '0;
    end else if (wb_b_wen_i && wb_b_addr_i == raddr) begin
      return wb_b_data_i;
    end else if (wb_a_wen_i && wb_a_addr_i == raddr) begin
      return wb_a_data_i;
    end else begin
      return regfile[raddr];
    end
  endfunction

  assign rs1_a_data_o = read_port(rs1_a_addr);
  assign rs2_a_data_o = read_port(rs2_a_addr);
  assign rs1_b_data_o = read_port(rs1_b_addr);
  assign rs2_b_data_o = read_port(rs2_b_addr);

  //--------------------------------------------------------------------------
  // Assertions
  //--------------------------------------------------------------------------
`ifndef SYNTHESIS
  // x0 should always be 0
  assert property (@(posedge clk_i) disable iff (!rst_ni) regfile[0] == '0)
  else $error("x0 is not zero!");

  // No X values in regfile after reset
  generate
    for (genvar i = 0; i < NUM_REGS; i++) begin : gen_regfile_check
      assert property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(regfile[i]))
      else $error("Register x%0d contains X", i);
    end
  endgenerate
`endif

endmodule : rv64xo3_id
