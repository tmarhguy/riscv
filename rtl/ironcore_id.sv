// IronCore ID Stage - Instruction Decode and Register File
// Contains the 32x32 register file with x0 hardwired to zero

import ironcore_pkg::*;
module ironcore_id (
    input logic clk_i,
    input logic rst_ni,

    // Pipeline register input
    input ironcore_pkg::if_id_reg_t if_id_reg_i,

    // Writeback interface
    input logic [REG_ADDR_W-1:0] wb_rd_addr_i,
    input logic [      XLEN-1:0] wb_rd_data_i,
    input logic                  wb_rd_wen_i,

    // Register read outputs
    output logic [XLEN-1:0] rs1_data_o,
    output logic [XLEN-1:0] rs2_data_o
);

  //--------------------------------------------------------------------------
  // Register File (32 x 32-bit, x0 hardwired to 0)
  //--------------------------------------------------------------------------
  logic [XLEN-1:0] regfile[NUM_REGS];

  // Extract register addresses from instruction
  logic [REG_ADDR_W-1:0] rs1_addr;
  logic [REG_ADDR_W-1:0] rs2_addr;

  assign rs1_addr = if_id_reg_i.instr[19:15];
  assign rs2_addr = if_id_reg_i.instr[24:20];

  //--------------------------------------------------------------------------
  // Register File Write (WB Stage writes here)
  //--------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      // Reset all registers to 0
      for (int i = 0; i < NUM_REGS; i++) begin
        regfile[i] <= '0;
      end
    end else if (wb_rd_wen_i && wb_rd_addr_i != 5'd0) begin
      // Write to regfile (except x0)
      regfile[wb_rd_addr_i] <= wb_rd_data_i;
    end
  end

  //--------------------------------------------------------------------------
  // Register File Read (combinational with write-through)
  //--------------------------------------------------------------------------
  always_comb begin
    // RS1 read with write-through bypass
    if (rs1_addr == 5'd0) begin
      rs1_data_o = '0;
    end else if (wb_rd_wen_i && wb_rd_addr_i == rs1_addr) begin
      rs1_data_o = wb_rd_data_i;  // Write-through bypass
    end else begin
      rs1_data_o = regfile[rs1_addr];
    end

    // RS2 read with write-through bypass
    if (rs2_addr == 5'd0) begin
      rs2_data_o = '0;
    end else if (wb_rd_wen_i && wb_rd_addr_i == rs2_addr) begin
      rs2_data_o = wb_rd_data_i;  // Write-through bypass
    end else begin
      rs2_data_o = regfile[rs2_addr];
    end
  end

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

endmodule : ironcore_id
